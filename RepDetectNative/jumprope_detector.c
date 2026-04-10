#include "jumprope_detector.h"
#include <math.h>
#include <string.h>
#include <float.h>
#include <stdio.h>
#ifdef __ANDROID__
#include <android/log.h>
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "JumpRope", __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, "JumpRope", __VA_ARGS__)
#else
#define LOGI(...) \
    do { \
        fprintf(stderr, "[JumpRope] "); \
        fprintf(stderr, __VA_ARGS__); \
        fprintf(stderr, "\n"); \
    } while (0)
#define LOGW(...) \
    do { \
        fprintf(stderr, "[JumpRope/W] "); \
        fprintf(stderr, __VA_ARGS__); \
        fprintf(stderr, "\n"); \
    } while (0)
#endif

/* ── 髋部和肩部关键点索引（与 Python 一致）── */
#define LM_LEFT_HIP_IDX       23
#define LM_RIGHT_HIP_IDX      24
#define LM_LEFT_SHOULDER_IDX  11
#define LM_RIGHT_SHOULDER_IDX 12

/* 每隔多少帧打印一次常规状态 log（避免刷屏）*/
#define LOG_INTERVAL 15

/* 两次计数之间至少间隔（毫秒），避免晃手机/关键点抖动导致连加 */
#define JR_COUNT_COOLDOWN_MS 320

/* ────────────────────────────────────────────────
 * 内部工具函数
 * ──────────────────────────────────────────────── */

static float smooth_update(float old_val, float new_val, float alpha) {
    return alpha * new_val + (1.0f - alpha) * old_val;
}

static float buffer_max(const JumpRopeDetector *jr) {
    if (jr->buffer_count == 0) return 0.0f;
    float m = -FLT_MAX;
    for (int i = 0; i < jr->buffer_count; i++) {
        if (jr->cy_buffer[i] > m) m = jr->cy_buffer[i];
    }
    return m;
}

static float buffer_min(const JumpRopeDetector *jr) {
    if (jr->buffer_count == 0) return 0.0f;
    float m = FLT_MAX;
    for (int i = 0; i < jr->buffer_count; i++) {
        if (jr->cy_buffer[i] > 0.0f && jr->cy_buffer[i] < m)
            m = jr->cy_buffer[i];
    }
    return (m == FLT_MAX) ? 0.0f : m;
}

static void buffer_push(JumpRopeDetector *jr, float value) {
    jr->cy_buffer[jr->buffer_head] = value;
    jr->buffer_head = (jr->buffer_head + 1) % JR_BUFFER_SIZE;
    if (jr->buffer_count < JR_BUFFER_SIZE)
        jr->buffer_count++;
}

static int update_flip_flag(float cy,
                            float cy_shoulder_hip,
                            float cy_max,
                            float cy_min,
                            int   flip_flag,
                            const JumpRopeDetector *jr) {
    float dy        = cy_max - cy_min;
    float threshold = jr->dy_ratio * cy_shoulder_hip;

    LOGI("[flip] cy=%.1f  dy=%.1f  threshold=%.1f  sh_hip=%.1f  flag=%s",
         cy, dy, threshold, cy_shoulder_hip,
         flip_flag == JR_FLAG_HIGH ? "HIGH(落地)" : "LOW(跳起)");

    if (dy <= threshold) {
        LOGW("[flip] ⚠️ dy(%.1f) <= threshold(%.1f)，波动幅度不足，不更新状态"
             " → 建议：①确认全身入镜 ②加大跳绳幅度 ③dy_ratio可以继续降低",
             dy, threshold);
        return flip_flag;
    }

    float up_bound   = cy_max - jr->up_ratio  * dy;
    float down_bound = cy_min + jr->down_ratio * dy;

    LOGI("[flip] up_bound=%.1f  down_bound=%.1f", up_bound, down_bound);

    if (cy > up_bound && flip_flag == JR_FLAG_LOW) {
        LOGI("[flip] ✅ LOW→HIGH：cy(%.1f) > up_bound(%.1f)，落地检测到", cy, up_bound);
        return JR_FLAG_HIGH;
    }

    if (cy < down_bound && flip_flag == JR_FLAG_HIGH) {
        LOGI("[flip] ✅ HIGH→LOW：cy(%.1f) < down_bound(%.1f)，起跳检测到", cy, down_bound);
        return JR_FLAG_LOW;
    }

    return flip_flag;
}

/* ────────────────────────────────────────────────
 * 公开 API 实现
 * ──────────────────────────────────────────────── */

void jr_init(JumpRopeDetector *jr) {
    memset(jr, 0, sizeof(JumpRopeDetector));


        jr->cy_max       = 0.0f;
        jr->cy_min       = 0.0f;
        jr->flip_flag    = JR_FLAG_HIGH;

        // ✅ smooth_alpha 从 0.5 提高到 0.9，让 max/min 快速跟上真实波动
        jr->smooth_alpha = 0.9f;

        /* dy_ratio 过小会导致手机晃动时误触发；0.12~0.15 更稳 */
        jr->dy_ratio     = 0.13f;

        jr->up_ratio     = 0.55f;
        jr->down_ratio   = 0.35f;
        jr->count        = 0;
        jr->buffer_head  = 0;
        jr->buffer_count = 0;
        jr->last_count_ms = -1000000000LL;
        jr->prev_cy      = 0.0f;
        jr->has_prev_cy  = 0;

        LOGI("[init] 跳绳检测器初始化完成"
             " dy_ratio=%.2f up_ratio=%.2f down_ratio=%.2f alpha=%.2f",
             jr->dy_ratio, jr->up_ratio, jr->down_ratio, jr->smooth_alpha);
}

int jr_process_frame(JumpRopeDetector *jr,
                     const PointF3D   *landmarks,
                     int               has_pose,
                     long long         now_ms) {
    float cy              = 0.0f;
    float cy_shoulder_hip = 0.0f;

    /* ── 未检测到人体 ── */
    if (!has_pose || !landmarks) {
        if (jr->buffer_count % LOG_INTERVAL == 0) {
            LOGW("[frame] 未检测到人体（has_pose=%d landmarks=%s），跳过本帧",
                 has_pose, landmarks ? "非NULL" : "NULL");
        }
        buffer_push(jr, 0.0f);
        return 0;
    }

    /* ── 提取关键点坐标 ── */
    float left_hip_y       = landmarks[LM_LEFT_HIP_IDX].y;
    float right_hip_y      = landmarks[LM_RIGHT_HIP_IDX].y;
    float left_shoulder_y  = landmarks[LM_LEFT_SHOULDER_IDX].y;
    float right_shoulder_y = landmarks[LM_RIGHT_SHOULDER_IDX].y;

    cy                = (left_hip_y  + right_hip_y)        * 0.5f;
    float cy_shoulder = (left_shoulder_y + right_shoulder_y) * 0.5f;
    cy_shoulder_hip   = cy - cy_shoulder;

    /* 单帧髋部 Y 跳变过大（常见：晃手机导致关键点抖动），不更新 flip 状态机 */
    int skip_flip = 0;
    if (jr->has_prev_cy && cy_shoulder_hip > 30.0f) {
        float jump     = fabsf(cy - jr->prev_cy);
        float max_step = fmaxf(50.0f, 0.35f * cy_shoulder_hip);
        if (jump > max_step) {
            skip_flip = 1;
        }
    }
    jr->has_prev_cy = 1;
    jr->prev_cy     = cy;

    /* ── 每 LOG_INTERVAL 帧打印一次关键点原始值 ── */
    if (jr->buffer_count % LOG_INTERVAL == 0) {
        LOGI("[landmarks] 左髋y=%.1f 右髋y=%.1f 左肩y=%.1f 右肩y=%.1f",
             left_hip_y, right_hip_y, left_shoulder_y, right_shoulder_y);
        LOGI("[landmarks] cy=%.1f  cy_shoulder=%.1f  sh_hip距离=%.1f",
             cy, cy_shoulder, cy_shoulder_hip);

        if (cy_shoulder_hip <= 0.0f) {
            LOGW("[landmarks] ⚠️ sh_hip距离=%.1f <= 0，"
                 "可能原因：摄像头方向错误 或 关键点检测失败",
                 cy_shoulder_hip);
        }
    }

    /* ── 第一帧用真实 cy 初始化 max/min ── */
    if (jr->buffer_count == 0 && cy > 0.0f) {
        jr->cy_max = cy;
        jr->cy_min = cy;
        LOGI("[init] 第一帧初始化：cy_max = cy_min = %.1f", cy);
    }

    buffer_push(jr, cy);

    float raw_max = buffer_max(jr);
    float raw_min = buffer_min(jr);
    jr->cy_max = smooth_update(jr->cy_max, raw_max, jr->smooth_alpha);
    jr->cy_min = smooth_update(jr->cy_min, raw_min, jr->smooth_alpha);

    /* ── 每 LOG_INTERVAL 帧打印一次缓冲区状态 ── */
    if (jr->buffer_count % LOG_INTERVAL == 0) {
        LOGI("[buffer] count=%d  raw_max=%.1f  raw_min=%.1f"
             "  smooth_max=%.1f  smooth_min=%.1f  dy=%.1f",
             jr->buffer_count,
             raw_max, raw_min,
             jr->cy_max, jr->cy_min,
             jr->cy_max - jr->cy_min);
        LOGI("[status] 当前跳绳计数=%d  flip_flag=%s",
             jr->count,
             jr->flip_flag == JR_FLAG_HIGH ? "HIGH(落地)" : "LOW(跳起)");
    }

    /* ── 更新翻转状态机 ── */
    int prev_flip_flag = jr->flip_flag;
    if (!skip_flip) {
        jr->flip_flag = update_flip_flag(cy,
                                         cy_shoulder_hip,
                                         jr->cy_max,
                                         jr->cy_min,
                                         jr->flip_flag,
                                         jr);
    }

    /* ── 计数：LOW → HIGH 触发一次 ── */
    if (!skip_flip && prev_flip_flag < jr->flip_flag) {
        if (now_ms - jr->last_count_ms < JR_COUNT_COOLDOWN_MS) {
            LOGW("[count] 冷却中跳过（%lld ms < %d ms）",
                 (long long)(now_ms - jr->last_count_ms), JR_COUNT_COOLDOWN_MS);
            return 0;
        }
        jr->last_count_ms = now_ms;
        jr->count++;
        LOGI("[count] ✅✅✅ 跳绳计数 +1，当前总计 = %d", jr->count);
        return 1;
    }

    return 0;
}

int jr_get_count(const JumpRopeDetector *jr) {
    return jr->count;
}

void jr_reset(JumpRopeDetector *jr) {
    float dy_ratio    = jr->dy_ratio;
    float up_ratio    = jr->up_ratio;
    float down_ratio  = jr->down_ratio;
    float smooth_alpha = jr->smooth_alpha;

    jr_init(jr);

    jr->dy_ratio     = dy_ratio;
    jr->up_ratio     = up_ratio;
    jr->down_ratio   = down_ratio;
    jr->smooth_alpha = smooth_alpha;

    LOGI("[reset] 检测器已重置，保留阈值配置");
}
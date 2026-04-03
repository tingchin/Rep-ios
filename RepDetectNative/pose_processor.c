#include "pose_processor.h"
#include <string.h>
#include <stdio.h>

/* 跳绳模式固定使用的类别名称 */
#define JUMPROPE_CLASS_NAME "jumprope"

/* 在 results 数组中查找或新增某类别条目 */
static PostureResult *find_or_create_result(PoseProcessor *pp,
                                             const char    *class_name) {
    for (int i = 0; i < pp->result_count; i++) {
        if (strncmp(pp->results[i].class_name, class_name, MAX_CLASS_NAME) == 0)
            return &pp->results[i];
    }
    if (pp->result_count >= MAX_CLASSES) return NULL;
    PostureResult *r = &pp->results[pp->result_count++];
    strncpy(r->class_name, class_name, MAX_CLASS_NAME - 1);
    r->class_name[MAX_CLASS_NAME - 1] = '\0';
    r->confidence  = 0.0f;
    r->repetitions = 0;
    return r;
}

/* ════════════════════════════════════════════════════
 * KNN 模式初始化
 * ════════════════════════════════════════════════════ */
int pp_init(PoseProcessor *pp,
            const char    *csv_file_path,
            int            is_stream_mode,
            const char   **pose_classes,
            int            class_count) {
    memset(pp, 0, sizeof(PoseProcessor));
    pp->mode           = MODE_KNN_CSV;
    pp->is_stream_mode = is_stream_mode;

    int loaded = pose_samples_load(csv_file_path, pp->samples, MAX_POSE_SAMPLES);
    if (loaded < 0) {
        fprintf(stderr, "[PoseProcessor] 无法加载 CSV: %s\n", csv_file_path);
        return -1;
    }
    pp->sample_count = loaded;
    printf("[PoseProcessor] KNN 模式，已加载 %d 个样本\n", loaded);

    pc_init(&pp->classifier, pp->samples, pp->sample_count);

    if (is_stream_mode) {
        ema_init(&pp->smoother);
        int n = class_count < MAX_REP_COUNTERS ? class_count : MAX_REP_COUNTERS;
        for (int i = 0; i < n; i++) {
            rc_init(&pp->rep_counters[i], pose_classes[i]);
            find_or_create_result(pp, pose_classes[i]);
        }
        pp->rep_counter_count = n;
    }
    return 0;
}

/* ════════════════════════════════════════════════════
 * ✅ 跳绳模式初始化（不需要 CSV）
 * ════════════════════════════════════════════════════ */
void pp_init_jumprope(PoseProcessor *pp) {
    memset(pp, 0, sizeof(PoseProcessor));
    pp->mode           = MODE_JUMPROPE;
    pp->is_stream_mode = 1;

    jr_init(&pp->jr_detector);

    /* 预创建跳绳结果条目 */
    find_or_create_result(pp, JUMPROPE_CLASS_NAME);
    printf("[PoseProcessor] 跳绳模式初始化完成（无需 CSV）\n");
}

/* ════════════════════════════════════════════════════
 * 统一帧处理入口
 * ════════════════════════════════════════════════════ */
const char *pp_process_frame(PoseProcessor  *pp,
                              const PointF3D *landmarks,
                              long long       now_ms,
                              int             has_pose) {
    /* ── 跳绳模式：直接用 Y 轴波动检测 ── */
    if (pp->mode == MODE_JUMPROPE) {
        int triggered = jr_process_frame(&pp->jr_detector, landmarks, has_pose);
        if (triggered) {
            PostureResult *r = find_or_create_result(pp, JUMPROPE_CLASS_NAME);
            if (r) {
                r->repetitions = jr_get_count(&pp->jr_detector);
                r->confidence  = 1.0f;  /* 跳绳模式置信度固定为 1 */
            }
            return JUMPROPE_CLASS_NAME;
        }
        /* 即使本帧未触发计数，也同步最新次数到结果 */
        PostureResult *r = find_or_create_result(pp, JUMPROPE_CLASS_NAME);
        if (r) r->repetitions = jr_get_count(&pp->jr_detector);
        return NULL;
    }

    /* ── KNN 模式：原有 CSV + 分类器逻辑 ── */
    ClassificationResult raw_result;
    pc_classify(&pp->classifier, landmarks, &raw_result);

    const char *rep_triggered_class = NULL;

    if (pp->is_stream_mode) {
        ClassificationResult smoothed;
        ema_get_smoothed(&pp->smoother, &raw_result, now_ms, &smoothed);

        if (!has_pose) return NULL;

        for (int i = 0; i < pp->rep_counter_count; i++) {
            RepetitionCounter *rc = &pp->rep_counters[i];
            int before = rc_get_count(rc);
            int after  = rc_add_result(rc, &smoothed);
            if (after > before) {
                PostureResult *r = find_or_create_result(pp, rc_get_class_name(rc));
                if (r) r->repetitions = after;
                rep_triggered_class = rc_get_class_name(rc);
                break;
            }
        }

        if (has_pose) {
            const char *max_class = cr_max_confidence_class(&smoothed);
            if (max_class) {
                float conf_range = (float)pc_confidence_range(&pp->classifier);
                float conf       = conf_range > 0.0f
                                 ? cr_get_confidence(&smoothed, max_class) / conf_range
                                 : 0.0f;
                PostureResult *r = find_or_create_result(pp, max_class);
                if (r) r->confidence = conf;
            }
        }
    }

    return rep_triggered_class;
}

int pp_get_results(const PoseProcessor *pp, PostureResult *results_out) {
    memcpy(results_out, pp->results, sizeof(PostureResult) * pp->result_count);
    return pp->result_count;
}

void pp_destroy(PoseProcessor *pp) {
    (void)pp;
}

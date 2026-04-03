#ifndef JUMPROPE_DETECTOR_H
#define JUMPROPE_DETECTOR_H

#include "pose_types.h"

/* ── 缓冲区大小，对应 Python buffer_time=50 ── */
#define JR_BUFFER_SIZE  50

/* ── 翻转标志值，对应 Python flag_low/flag_high ── */
#define JR_FLAG_LOW   150
#define JR_FLAG_HIGH  250

/*
 * 跳绳检测器
 * 核心思路：追踪髋部中心 Y 坐标的周期性波动，
 * 不依赖 CSV 样本文件，不使用 KNN 分类
 */
typedef struct {
    /* ── 滚动缓冲区（存储最近 JR_BUFFER_SIZE 帧的髋部 Y 坐标）── */
    float cy_buffer[JR_BUFFER_SIZE];
    int   buffer_head;   /* 下一个写入位置（循环）*/
    int   buffer_count;  /* 当前有效数据数量 */

    /* ── 平滑后的最大/最小 Y 值 ── */
    float cy_max;
    float cy_min;

    /* ── 翻转状态机 ── */
    int flip_flag;       /* JR_FLAG_LOW 或 JR_FLAG_HIGH */

    /* ── 计数结果 ── */
    int count;

    /* ── 阈值参数（对应 Python thresholds）── */
    float dy_ratio;      /* 有效波动幅度比例，默认 0.30 */
    float up_ratio;      /* 上升判断比例，默认 0.55 */
    float down_ratio;    /* 下降判断比例，默认 0.35 */
    float smooth_alpha;  /* EMA 平滑系数，默认 0.50 */
} JumpRopeDetector;

/* ────────────────────────────────────────────────
 * API
 * ──────────────────────────────────────────────── */

/* 初始化检测器（使用默认阈值）*/
void jr_init(JumpRopeDetector *jr);

/*
 * 处理一帧关键点，返回本帧是否完成一次跳绳计数
 *
 * landmarks : 33 个关键点（NULL 或未检测到人体时传 NULL）
 * has_pose  : 1=检测到人体，0=未检测到
 * 返回值    : 1=本帧触发计数，0=未触发
 */
int jr_process_frame(JumpRopeDetector *jr,
                     const PointF3D   *landmarks,
                     int               has_pose);

/* 获取当前累计跳绳次数 */
int jr_get_count(const JumpRopeDetector *jr);

/* 重置计数和状态 */
void jr_reset(JumpRopeDetector *jr);

#endif /* JUMPROPE_DETECTOR_H */

#ifndef POSE_PROCESSOR_H
#define POSE_PROCESSOR_H

#include "pose_types.h"
#include "pose_sample.h"
#include "pose_classifier.h"
#include "classification_result.h"
#include "ema_smoothing.h"
#include "repetition_counter.h"
#include "jumprope_detector.h"   /* ✅ 新增跳绳检测器 */

#define MAX_REP_COUNTERS  9

/* 动作检测模式 */
typedef enum {
    MODE_KNN_CSV   = 0,  /* 原有模式：基于 CSV 样本的 KNN 分类 */
    MODE_JUMPROPE  = 1   /* 跳绳模式：基于髋部 Y 轴波动检测，不需要 CSV */
} DetectionMode;

/* 单次处理的输出 */
typedef struct {
    char  class_name[MAX_CLASS_NAME];
    float confidence;
    int   repetitions;
} PostureResult;

/*
 * 顶层处理器
 * 根据 mode 决定使用哪种检测算法
 */
typedef struct {
    DetectionMode      mode;

    /* ── KNN 模式专用 ── */
    PoseSample         samples[MAX_POSE_SAMPLES];
    int                sample_count;
    PoseClassifier     classifier;
    EMASmoothing       smoother;
    RepetitionCounter  rep_counters[MAX_REP_COUNTERS];
    int                rep_counter_count;

    /* ── 跳绳模式专用 ── */
    JumpRopeDetector   jr_detector;

    /* ── 公共结果 ── */
    PostureResult      results[MAX_CLASSES];
    int                result_count;

    int                is_stream_mode;
} PoseProcessor;

/*
 * 初始化为 KNN 模式（原有所有动作）
 * csv_file_path : 合并后的 CSV 文件路径
 */
int pp_init(PoseProcessor *pp,
            const char    *csv_file_path,
            int            is_stream_mode,
            const char   **pose_classes,
            int            class_count);

/*
 * ✅ 新增：初始化为跳绳模式
 * 不需要 CSV 文件，直接基于关键点 Y 轴波动计数
 */
void pp_init_jumprope(PoseProcessor *pp);

/*
 * 处理一帧关键点
 * landmarks : 33 个关键点（像素坐标，由 ML Kit 返回）
 * now_ms    : 当前时间戳（毫秒）
 * has_pose  : 1=检测到人体，0=未检测到
 * 返回本帧触发计数的类别名称，无则返回 NULL
 */
const char *pp_process_frame(PoseProcessor  *pp,
                             const PointF3D *landmarks,
                             long long       now_ms,
                             int             has_pose);

/* 获取所有类别当前结果，返回条目数 */
int pp_get_results(const PoseProcessor *pp,
                   PostureResult       *results_out);

void pp_destroy(PoseProcessor *pp);

#endif /* POSE_PROCESSOR_H */

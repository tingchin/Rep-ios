#ifndef POSE_CLASSIFIER_H
#define POSE_CLASSIFIER_H

#include "pose_types.h"
#include "pose_sample.h"
#include "classification_result.h"

#define MAX_DISTANCE_TOP_K  30
#define MEAN_DISTANCE_TOP_K 10

/* 对应 Java PoseClassifier */
typedef struct {
    const PoseSample *samples;      /* 样本数组（外部拥有，分类器不释放）*/
    int               sample_count;
    int               max_dist_top_k;
    int               mean_dist_top_k;
    PointF3D          axes_weights;  /* 默认 (1, 1, 0.2) */
} PoseClassifier;

/*
 * 初始化分类器
 * samples / sample_count：外部加载的样本数组
 */
void pc_init(PoseClassifier *pc,
             const PoseSample *samples, int sample_count);

/*
 * 对应 Java confidenceRange()
 * 返回 min(max_dist_top_k, mean_dist_top_k)
 */
int pc_confidence_range(const PoseClassifier *pc);

/*
 * 对输入的 33 个关键点进行分类
 * 对应 Java classify(Pose pose)
 * 结果写入 result
 */
void pc_classify(const PoseClassifier *pc,
                 const PointF3D *landmarks,
                 ClassificationResult *result);

#endif /* POSE_CLASSIFIER_H */

#ifndef REPETITION_COUNTER_H
#define REPETITION_COUNTER_H

#include "classification_result.h"

#define RC_DEFAULT_ENTER_THRESHOLD 6.0f
#define RC_DEFAULT_EXIT_THRESHOLD  4.0f

/* 对应 Java RepetitionCounter */
typedef struct {
    char  class_name[MAX_CLASS_NAME];
    float enter_threshold;
    float exit_threshold;
    int   num_repeats;
    int   pose_entered;   /* 布尔值：当前是否处于"已进入"状态 */
} RepetitionCounter;

/* 初始化（使用默认阈值）*/
void rc_init(RepetitionCounter *rc, const char *class_name);

/* 使用自定义阈值初始化 */
void rc_init_custom(RepetitionCounter *rc, const char *class_name,
                    float enter_threshold, float exit_threshold);

/*
 * 输入分类结果，更新计数
 * 对应 Java addClassificationResult(ClassificationResult)
 * 返回当前重复次数
 */
int rc_add_result(RepetitionCounter *rc, const ClassificationResult *result);

int         rc_get_count(const RepetitionCounter *rc);
const char *rc_get_class_name(const RepetitionCounter *rc);

#endif /* REPETITION_COUNTER_H */

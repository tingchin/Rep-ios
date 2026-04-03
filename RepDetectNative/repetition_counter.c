#include "repetition_counter.h"
#include <string.h>

void rc_init(RepetitionCounter *rc, const char *class_name) {
    rc_init_custom(rc, class_name,
                   RC_DEFAULT_ENTER_THRESHOLD,
                   RC_DEFAULT_EXIT_THRESHOLD);
}

void rc_init_custom(RepetitionCounter *rc, const char *class_name,
                    float enter_threshold, float exit_threshold) {
    strncpy(rc->class_name, class_name, MAX_CLASS_NAME - 1);
    rc->class_name[MAX_CLASS_NAME - 1] = '\0';
    rc->enter_threshold = enter_threshold;
    rc->exit_threshold  = exit_threshold;
    rc->num_repeats     = 0;
    rc->pose_entered    = 0;
}

int rc_add_result(RepetitionCounter *rc, const ClassificationResult *result) {
    float confidence = cr_get_confidence(result, rc->class_name);

    if (!rc->pose_entered) {
        /* 尚未进入姿势：检查是否超过进入阈值 */
        rc->pose_entered = (confidence > rc->enter_threshold) ? 1 : 0;
        return rc->num_repeats;
    }

    /* 已进入姿势：检查是否低于退出阈值（完成一次重复）*/
    if (confidence < rc->exit_threshold) {
        rc->num_repeats++;
        rc->pose_entered = 0;
    }

    return rc->num_repeats;
}

int rc_get_count(const RepetitionCounter *rc) {
    return rc->num_repeats;
}

const char *rc_get_class_name(const RepetitionCounter *rc) {
    return rc->class_name;
}

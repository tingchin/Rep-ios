#ifndef POSE_BRIDGE_H
#define POSE_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define POSE_BRIDGE_MAX_CLASSES 16
#define POSE_BRIDGE_CLASS_NAME_LEN 64

typedef struct {
    char class_name[POSE_BRIDGE_CLASS_NAME_LEN];
    float confidence;
    int repetitions;
} PoseBridgeResult;

/** Zero-filled result (for Swift callers that cannot default-init C structs). */
PoseBridgeResult pose_bridge_result_zero(void);

const char *pose_bridge_result_class_name(const PoseBridgeResult *r);

typedef void *PoseBridgeHandle;

PoseBridgeHandle pose_bridge_init_knn(const char *csv_path,
                                      int is_stream_mode,
                                      const char **pose_classes,
                                      int class_count);

/** Same KNN init as Android `PoseClassifierNative` (fixed 9 class names). */
PoseBridgeHandle pose_bridge_init_knn_default(const char *csv_path, int is_stream_mode);

PoseBridgeHandle pose_bridge_init_jumprope(void);

void pose_bridge_process_frame(PoseBridgeHandle handle,
                               const float *landmarks_xyz99,
                               int64_t now_ms,
                               int has_pose);

int pose_bridge_get_results(PoseBridgeHandle handle,
                            PoseBridgeResult *out,
                            int max_out);

void pose_bridge_destroy(PoseBridgeHandle handle);

#ifdef __cplusplus
}
#endif

#endif

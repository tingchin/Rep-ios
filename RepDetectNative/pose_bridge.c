#include "pose_bridge.h"
#include "pose_processor.h"
#include <stdlib.h>
#include <string.h>

PoseBridgeResult pose_bridge_result_zero(void) {
    PoseBridgeResult r;
    memset(&r, 0, sizeof(r));
    return r;
}

const char *pose_bridge_result_class_name(const PoseBridgeResult *r) {
    return r ? r->class_name : "";
}

static const char *KNN_DEFAULT_CLASSES[] = {
    "pushups_down",
    "squats",
    "lunges",
    "situp_up",
    "chestpress_down",
    "deadlift_down",
    "shoulderpress_down",
    "warrior",
    "tree_pose",
};

static const int KNN_DEFAULT_CLASS_COUNT =
    (int)(sizeof(KNN_DEFAULT_CLASSES) / sizeof(KNN_DEFAULT_CLASSES[0]));

PoseBridgeHandle pose_bridge_init_knn(const char *csv_path,
                                      int is_stream_mode,
                                      const char **pose_classes,
                                      int class_count) {
    PoseProcessor *pp = (PoseProcessor *)calloc(1, sizeof(PoseProcessor));
    if (!pp) return NULL;
    int ret = pp_init(pp, csv_path, is_stream_mode, pose_classes, class_count);
    if (ret != 0) {
        free(pp);
        return NULL;
    }
    return (PoseBridgeHandle)pp;
}

PoseBridgeHandle pose_bridge_init_knn_default(const char *csv_path, int is_stream_mode) {
    return pose_bridge_init_knn(csv_path, is_stream_mode, KNN_DEFAULT_CLASSES, KNN_DEFAULT_CLASS_COUNT);
}

PoseBridgeHandle pose_bridge_init_jumprope(void) {
    PoseProcessor *pp = (PoseProcessor *)calloc(1, sizeof(PoseProcessor));
    if (!pp) return NULL;
    pp_init_jumprope(pp);
    return (PoseBridgeHandle)pp;
}

void pose_bridge_process_frame(PoseBridgeHandle handle,
                               const float *landmarks_xyz99,
                               int64_t now_ms,
                               int has_pose) {
    if (!handle || !landmarks_xyz99) return;
    PoseProcessor *pp = (PoseProcessor *)handle;
    PointF3D landmarks[NUM_LANDMARKS];
    for (int i = 0; i < NUM_LANDMARKS; i++) {
        landmarks[i].x = landmarks_xyz99[i * 3];
        landmarks[i].y = landmarks_xyz99[i * 3 + 1];
        landmarks[i].z = landmarks_xyz99[i * 3 + 2];
    }
    pp_process_frame(pp, landmarks, (long long)now_ms, has_pose);
}

int pose_bridge_get_results(PoseBridgeHandle handle,
                            PoseBridgeResult *out,
                            int max_out) {
    if (!handle || !out || max_out <= 0) return 0;
    PoseProcessor *pp = (PoseProcessor *)handle;
    PostureResult results[MAX_CLASSES];
    int count = pp_get_results(pp, results);
    int n = count < max_out ? count : max_out;
    for (int i = 0; i < n; i++) {
        strncpy(out[i].class_name, results[i].class_name, POSE_BRIDGE_CLASS_NAME_LEN - 1);
        out[i].class_name[POSE_BRIDGE_CLASS_NAME_LEN - 1] = '\0';
        out[i].confidence = results[i].confidence;
        out[i].repetitions = results[i].repetitions;
    }
    return n;
}

void pose_bridge_destroy(PoseBridgeHandle handle) {
    if (!handle) return;
    PoseProcessor *pp = (PoseProcessor *)handle;
    pp_destroy(pp);
    free(pp);
}

#ifndef POSE_TYPES_H
#define POSE_TYPES_H

/* ── 基本尺寸常量 ── */
#define NUM_LANDMARKS      33   /* ML Kit / MediaPipe 关键点数量 */
#define EMBEDDING_DIM      23   /* getPoseEmbedding 生成的向量数 */
#define MAX_CLASSES        16   /* 支持的最大姿势类别数 */
#define MAX_CLASS_NAME     64   /* 类别名称最大长度 */
#define MAX_SAMPLE_NAME    128  /* 样本名称最大长度 */
#define MAX_POSE_SAMPLES   10000

/* ── ML Kit PoseLandmark 索引（与 Java 端一致）── */
#define LM_LEFT_SHOULDER   11
#define LM_RIGHT_SHOULDER  12
#define LM_LEFT_ELBOW      13
#define LM_RIGHT_ELBOW     14
#define LM_LEFT_WRIST      15
#define LM_RIGHT_WRIST     16
#define LM_LEFT_HIP        23
#define LM_RIGHT_HIP       24
#define LM_LEFT_KNEE       25
#define LM_RIGHT_KNEE      26
#define LM_LEFT_ANKLE      27
#define LM_RIGHT_ANKLE     28

/* ── 三维点 ── */
typedef struct {
    float x, y, z;
} PointF3D;

#endif /* POSE_TYPES_H */

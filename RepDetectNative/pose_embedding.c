#include "pose_embedding.h"
#include "utils.h"
#include <string.h>
#include <math.h>

#define TORSO_MULTIPLIER 2.5f

/* 归一化平移：所有点减去髋部中心 */
static void normalize_translation(PointF3D *lm) {
    PointF3D center = pt_avg(lm[LM_LEFT_HIP], lm[LM_RIGHT_HIP]);
    lm_subtract_all(lm, NUM_LANDMARKS, center);
}

/* 计算姿势尺寸（用于缩放归一化）*/
static float get_pose_size(const PointF3D *lm) {
    PointF3D hips_center      = pt_avg(lm[LM_LEFT_HIP],      lm[LM_RIGHT_HIP]);
    PointF3D shoulders_center = pt_avg(lm[LM_LEFT_SHOULDER],  lm[LM_RIGHT_SHOULDER]);

    float torso_size = pt_l2norm2d(pt_sub(hips_center, shoulders_center));
    float max_dist   = torso_size * TORSO_MULTIPLIER;

    for (int i = 0; i < NUM_LANDMARKS; i++) {
        float d = pt_l2norm2d(pt_sub(hips_center, lm[i]));
        if (d > max_dist) max_dist = d;
    }
    return max_dist;
}

/* 归一化缩放：除以姿势尺寸再乘以 100 */
static void normalize_scale(PointF3D *lm) {
    float size = get_pose_size(lm);
    lm_multiply_all_scalar(lm, NUM_LANDMARKS, 1.0f / size);
    lm_multiply_all_scalar(lm, NUM_LANDMARKS, 100.0f);
}

/*
 * 生成 23 维嵌入向量，对应 Java PoseEmbedding.getEmbedding()
 * pt_sub(a, b) = b - a，与 Java Utils.subtract(a, b) = b - a 一致
 */
static void build_embedding(const PointF3D *lm, PointF3D *emb) {
    int idx = 0;

    /* ── 单关节距离（9 个）── */
    emb[idx++] = pt_sub(
        pt_avg(lm[LM_LEFT_HIP],      lm[LM_RIGHT_HIP]),
        pt_avg(lm[LM_LEFT_SHOULDER], lm[LM_RIGHT_SHOULDER])
    );
    emb[idx++] = pt_sub(lm[LM_LEFT_SHOULDER],  lm[LM_LEFT_ELBOW]);
    emb[idx++] = pt_sub(lm[LM_RIGHT_SHOULDER], lm[LM_RIGHT_ELBOW]);
    emb[idx++] = pt_sub(lm[LM_LEFT_ELBOW],     lm[LM_LEFT_WRIST]);
    emb[idx++] = pt_sub(lm[LM_RIGHT_ELBOW],    lm[LM_RIGHT_WRIST]);
    emb[idx++] = pt_sub(lm[LM_LEFT_HIP],       lm[LM_LEFT_KNEE]);
    emb[idx++] = pt_sub(lm[LM_RIGHT_HIP],      lm[LM_RIGHT_KNEE]);
    emb[idx++] = pt_sub(lm[LM_LEFT_KNEE],      lm[LM_LEFT_ANKLE]);
    emb[idx++] = pt_sub(lm[LM_RIGHT_KNEE],     lm[LM_RIGHT_ANKLE]);

    /* ── 两关节距离（4 个）── */
    emb[idx++] = pt_sub(lm[LM_LEFT_SHOULDER],  lm[LM_LEFT_WRIST]);
    emb[idx++] = pt_sub(lm[LM_RIGHT_SHOULDER], lm[LM_RIGHT_WRIST]);
    emb[idx++] = pt_sub(lm[LM_LEFT_HIP],       lm[LM_LEFT_ANKLE]);
    emb[idx++] = pt_sub(lm[LM_RIGHT_HIP],      lm[LM_RIGHT_ANKLE]);

    /* ── 四关节距离（2 个）── */
    emb[idx++] = pt_sub(lm[LM_LEFT_HIP],  lm[LM_LEFT_WRIST]);
    emb[idx++] = pt_sub(lm[LM_RIGHT_HIP], lm[LM_RIGHT_WRIST]);

    /* ── 五关节距离（4 个，含重复，与 Java 原版一致）── */
    emb[idx++] = pt_sub(lm[LM_LEFT_SHOULDER],  lm[LM_LEFT_ANKLE]);
    emb[idx++] = pt_sub(lm[LM_RIGHT_SHOULDER], lm[LM_RIGHT_ANKLE]);
    emb[idx++] = pt_sub(lm[LM_LEFT_HIP],       lm[LM_LEFT_WRIST]);
    emb[idx++] = pt_sub(lm[LM_RIGHT_HIP],      lm[LM_RIGHT_WRIST]);

    /* ── 跨身体距离（4 个）── */
    emb[idx++] = pt_sub(lm[LM_LEFT_ELBOW],  lm[LM_RIGHT_ELBOW]);
    emb[idx++] = pt_sub(lm[LM_LEFT_KNEE],   lm[LM_RIGHT_KNEE]);
    emb[idx++] = pt_sub(lm[LM_LEFT_WRIST],  lm[LM_RIGHT_WRIST]);
    emb[idx++] = pt_sub(lm[LM_LEFT_ANKLE],  lm[LM_RIGHT_ANKLE]);

    /* idx == EMBEDDING_DIM == 23 */
}

void get_pose_embedding(const PointF3D *landmarks, PointF3D *embedding) {
    /* 复制一份，归一化操作在副本上进行 */
    PointF3D lm[NUM_LANDMARKS];
    memcpy(lm, landmarks, sizeof(PointF3D) * NUM_LANDMARKS);

    normalize_translation(lm);
    normalize_scale(lm);
    build_embedding(lm, embedding);
}

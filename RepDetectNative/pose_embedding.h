#ifndef POSE_EMBEDDING_H
#define POSE_EMBEDDING_H

#include "pose_types.h"

/*
 * 对应 Java PoseEmbedding.getPoseEmbedding(landmarks)
 *
 * 输入：landmarks[NUM_LANDMARKS]  原始 33 个关键点
 * 输出：embedding[EMBEDDING_DIM]  归一化后的 23 维嵌入向量（调用方分配）
 */
void get_pose_embedding(const PointF3D *landmarks, PointF3D *embedding);

#endif /* POSE_EMBEDDING_H */

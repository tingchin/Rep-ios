#ifndef POSE_SAMPLE_H
#define POSE_SAMPLE_H

#include "pose_types.h"

/* 对应 Java PoseSample：存储样本名、类别名和嵌入向量 */
typedef struct {
    char     name[MAX_SAMPLE_NAME];
    char     class_name[MAX_CLASS_NAME];
    PointF3D embedding[EMBEDDING_DIM];  /* 已通过 get_pose_embedding 计算完毕 */
} PoseSample;

/*
 * 从单行 CSV 解析一个 PoseSample
 * 格式：Name,ClassName,X1,Y1,Z1,...,X33,Y33,Z33（共 101 个 token）
 *
 * 返回值：
 *   0  解析成功，结果写入 *out
 *  -1  行为空或格式错误，跳过
 */
int pose_sample_parse(const char *csv_line, PoseSample *out);

/*
 * 从文件路径批量加载所有样本
 *
 * samples   : 调用方提供的缓冲区，大小至少 MAX_POSE_SAMPLES
 * max_count : 缓冲区容量
 * 返回值    : 实际加载的样本数量，失败返回 -1
 */
int pose_samples_load(const char *file_path, PoseSample *samples, int max_count);

#endif /* POSE_SAMPLE_H */

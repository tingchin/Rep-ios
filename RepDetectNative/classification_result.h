#ifndef CLASSIFICATION_RESULT_H
#define CLASSIFICATION_RESULT_H

#include "pose_types.h"

/* 单个类别的置信度条目 */
typedef struct {
    char  class_name[MAX_CLASS_NAME];
    float confidence;
} ClassEntry;

/* 对应 Java ClassificationResult，使用固定数组存储类别→置信度映射 */
typedef struct {
    ClassEntry entries[MAX_CLASSES];
    int        count;
} ClassificationResult;

/* 初始化（清空所有置信度）*/
void cr_init(ClassificationResult *cr);

/* 获取某类别置信度，不存在返回 0 */
float cr_get_confidence(const ClassificationResult *cr, const char *class_name);

/* 将某类别置信度加 1（对应 Java incrementClassConfidence）*/
void cr_increment(ClassificationResult *cr, const char *class_name);

/* 直接设置某类别置信度（对应 Java putClassConfidence）*/
void cr_put(ClassificationResult *cr, const char *class_name, float confidence);

/* 返回置信度最高的类别名称，若为空返回 NULL */
const char *cr_max_confidence_class(const ClassificationResult *cr);

/* 深拷贝 */
void cr_copy(ClassificationResult *dst, const ClassificationResult *src);

#endif /* CLASSIFICATION_RESULT_H */

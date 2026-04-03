#include "classification_result.h"
#include <string.h>

void cr_init(ClassificationResult *cr) {
    cr->count = 0;
    memset(cr->entries, 0, sizeof(cr->entries));
}

/* 查找类别索引，不存在返回 -1 */
static int find_entry(const ClassificationResult *cr, const char *name) {
    for (int i = 0; i < cr->count; i++) {
        if (strncmp(cr->entries[i].class_name, name, MAX_CLASS_NAME) == 0)
            return i;
    }
    return -1;
}

float cr_get_confidence(const ClassificationResult *cr, const char *class_name) {
    int idx = find_entry(cr, class_name);
    return idx >= 0 ? cr->entries[idx].confidence : 0.0f;
}

void cr_increment(ClassificationResult *cr, const char *class_name) {
    int idx = find_entry(cr, class_name);
    if (idx >= 0) {
        cr->entries[idx].confidence += 1.0f;
    } else if (cr->count < MAX_CLASSES) {
        strncpy(cr->entries[cr->count].class_name, class_name, MAX_CLASS_NAME - 1);
        cr->entries[cr->count].confidence = 1.0f;
        cr->count++;
    }
}

void cr_put(ClassificationResult *cr, const char *class_name, float confidence) {
    int idx = find_entry(cr, class_name);
    if (idx >= 0) {
        cr->entries[idx].confidence = confidence;
    } else if (cr->count < MAX_CLASSES) {
        strncpy(cr->entries[cr->count].class_name, class_name, MAX_CLASS_NAME - 1);
        cr->entries[cr->count].confidence = confidence;
        cr->count++;
    }
}

const char *cr_max_confidence_class(const ClassificationResult *cr) {
    if (cr->count == 0) return NULL;
    int   best_idx  = 0;
    float best_conf = cr->entries[0].confidence;
    for (int i = 1; i < cr->count; i++) {
        if (cr->entries[i].confidence > best_conf) {
            best_conf = cr->entries[i].confidence;
            best_idx  = i;
        }
    }
    return cr->entries[best_idx].class_name;
}

void cr_copy(ClassificationResult *dst, const ClassificationResult *src) {
    memcpy(dst, src, sizeof(ClassificationResult));
}

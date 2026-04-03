#include "pose_sample.h"
#include "pose_embedding.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define EXPECTED_TOKENS  (NUM_LANDMARKS * 3 + 2)   /* 101 */
#define LINE_BUF_SIZE    8192

/* 判断字符串是否全为空白 */
static int is_blank(const char *s) {
    while (*s) { if (!isspace((unsigned char)*s)) return 0; s++; }
    return 1;
}

int pose_sample_parse(const char *csv_line, PoseSample *out) {
    if (!csv_line || is_blank(csv_line)) return -1;

    /* 复制一份用于 strtok */
    char buf[LINE_BUF_SIZE];
    strncpy(buf, csv_line, LINE_BUF_SIZE - 1);
    buf[LINE_BUF_SIZE - 1] = '\0';

    /* 分割逗号 */
    char *tokens[EXPECTED_TOKENS + 1];
    int   count = 0;
    char *tok   = strtok(buf, ",");
    while (tok && count <= EXPECTED_TOKENS) {
        tokens[count++] = tok;
        tok = strtok(NULL, ",");
    }

    if (count != EXPECTED_TOKENS) return -1;

    /* 前两个 token：名称和类别 */
    strncpy(out->name,       tokens[0], MAX_SAMPLE_NAME - 1);
    strncpy(out->class_name, tokens[1], MAX_CLASS_NAME  - 1);
    out->name[MAX_SAMPLE_NAME - 1]  = '\0';
    out->class_name[MAX_CLASS_NAME - 1] = '\0';

    /* 解析 33 个关键点（每点 x, y, z）*/
    PointF3D landmarks[NUM_LANDMARKS];
    for (int i = 0; i < NUM_LANDMARKS; i++) {
        int base = 2 + i * 3;
        char *endp;
        landmarks[i].x = strtof(tokens[base],     &endp);
        landmarks[i].y = strtof(tokens[base + 1], &endp);
        landmarks[i].z = strtof(tokens[base + 2], &endp);
    }

    /* 计算嵌入向量并存储（与 Java PoseSample 构造函数一致）*/
    get_pose_embedding(landmarks, out->embedding);
    return 0;
}

int pose_samples_load(const char *file_path, PoseSample *samples, int max_count) {
    FILE *fp = fopen(file_path, "r");
    if (!fp) return -1;

    char line[LINE_BUF_SIZE];
    int  loaded = 0;

    while (fgets(line, sizeof(line), fp) && loaded < max_count) {
        /* 去掉行尾换行 */
        size_t len = strlen(line);
        while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r'))
            line[--len] = '\0';

        if (pose_sample_parse(line, &samples[loaded]) == 0)
            loaded++;
    }

    fclose(fp);
    return loaded;
}

#ifndef EMA_SMOOTHING_H
#define EMA_SMOOTHING_H

#include "classification_result.h"

#define EMA_DEFAULT_WINDOW_SIZE  10
#define EMA_DEFAULT_ALPHA        0.2f
#define EMA_RESET_THRESHOLD_MS   100  /* 超过此时间间隔则重置窗口（毫秒）*/

/* 对应 Java EMASmoothing，使用循环缓冲区实现滑动窗口 */
typedef struct {
    ClassificationResult window[EMA_DEFAULT_WINDOW_SIZE];
    int                  window_size;
    float                alpha;
    int                  head;        /* 最新元素写入位置 */
    int                  count;       /* 当前有效元素数量 */
    long long            last_input_ms;
} EMASmoothing;

/* 初始化（使用默认窗口大小和 alpha）*/
void ema_init(EMASmoothing *ema);

/*
 * 输入新的分类结果，输出平滑后的结果
 * 对应 Java getSmoothedResult(ClassificationResult classificationResult)
 *
 * now_ms：当前时间（毫秒），由调用方传入，避免平台依赖
 */
void ema_get_smoothed(EMASmoothing *ema,
                      const ClassificationResult *input,
                      long long now_ms,
                      ClassificationResult *output);

/* 手动重置窗口 */
void ema_reset(EMASmoothing *ema);

#endif /* EMA_SMOOTHING_H */

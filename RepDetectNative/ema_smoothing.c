#include "ema_smoothing.h"
#include <string.h>
#include <stddef.h>

void ema_init(EMASmoothing *ema) {
    ema->window_size   = EMA_DEFAULT_WINDOW_SIZE;
    ema->alpha         = EMA_DEFAULT_ALPHA;
    ema->head          = 0;
    ema->count         = 0;
    ema->last_input_ms = -1;
    memset(ema->window, 0, sizeof(ema->window));
}

void ema_reset(EMASmoothing *ema) {
    ema->head  = 0;
    ema->count = 0;
    memset(ema->window, 0, sizeof(ema->window));
}

void ema_get_smoothed(EMASmoothing *ema,
                      const ClassificationResult *input,
                      long long now_ms,
                      ClassificationResult *output) {
    /* 若距上次输入超过阈值，重置窗口（对应 Java 的 reset 逻辑）*/
    if (ema->last_input_ms >= 0 &&
        (now_ms - ema->last_input_ms) > EMA_RESET_THRESHOLD_MS) {
        ema_reset(ema);
    }
    ema->last_input_ms = now_ms;

    /* 写入循环缓冲区头部（最新元素）*/
    int slot = ema->head % ema->window_size;
    cr_copy(&ema->window[slot], input);
    ema->head = (ema->head + 1) % ema->window_size;
    if (ema->count < ema->window_size) ema->count++;

    /* ── 收集窗口内所有出现过的类别名 ── */
    char all_classes[MAX_CLASSES][MAX_CLASS_NAME];
    int  class_count = 0;

    for (int w = 0; w < ema->count; w++) {
        const ClassificationResult *cr = &ema->window[w];
        for (int c = 0; c < cr->count; c++) {
            const char *name = cr->entries[c].class_name;
            /* 检查是否已记录 */
            int found = 0;
            for (int k = 0; k < class_count; k++) {
                if (strncmp(all_classes[k], name, MAX_CLASS_NAME) == 0) {
                    found = 1; break;
                }
            }
            if (!found && class_count < MAX_CLASSES) {
                strncpy(all_classes[class_count++], name, MAX_CLASS_NAME - 1);
            }
        }
    }

    /* ── 对每个类别计算 EMA 平滑置信度 ── */
    cr_init(output);

    for (int c = 0; c < class_count; c++) {
        const char *name = all_classes[c];

        float factor     = 1.0f;
        float top_sum    = 0.0f;
        float bottom_sum = 0.0f;

        /*
         * 遍历顺序：最新 → 最旧（对应 Java window.addFirst，
         * 即 window[0] 是最新的）
         * 这里循环缓冲区中 head-1 是最新写入的
         */
        for (int w = 0; w < ema->count; w++) {
            int idx = ((ema->head - 1 - w) % ema->window_size
                       + ema->window_size) % ema->window_size;
            float value = cr_get_confidence(&ema->window[idx], name);
            top_sum    += factor * value;
            bottom_sum += factor;
            factor     *= (1.0f - ema->alpha);
        }

        cr_put(output, name, top_sum / bottom_sum);
    }
}

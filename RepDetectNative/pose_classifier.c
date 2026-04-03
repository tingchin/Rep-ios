#include "pose_classifier.h"
#include "pose_embedding.h"
#include "utils.h"
#include <string.h>
#include <math.h>
#include <float.h>

/* ════════════════════════════════════════════════════
 * 内部：最大堆（用于 Top-K 筛选）
 * 存储 (PoseSample 索引, 距离) 对，堆顶为最大距离
 * ════════════════════════════════════════════════════ */
typedef struct {
    int   sample_idx;
    float dist;
} HeapNode;

typedef struct {
    HeapNode data[MAX_DISTANCE_TOP_K + 1];
    int      size;
    int      capacity;
} MaxHeap;

static void heap_init(MaxHeap *h, int capacity) {
    h->size     = 0;
    h->capacity = capacity;
}

static void heap_swap(MaxHeap *h, int i, int j) {
    HeapNode tmp = h->data[i];
    h->data[i]   = h->data[j];
    h->data[j]   = tmp;
}

static void heap_sift_up(MaxHeap *h, int i) {
    while (i > 0) {
        int parent = (i - 1) / 2;
        if (h->data[parent].dist < h->data[i].dist) {
            heap_swap(h, parent, i);
            i = parent;
        } else break;
    }
}

static void heap_sift_down(MaxHeap *h, int i) {
    while (1) {
        int largest = i;
        int l = 2 * i + 1, r = 2 * i + 2;
        if (l < h->size && h->data[l].dist > h->data[largest].dist) largest = l;
        if (r < h->size && h->data[r].dist > h->data[largest].dist) largest = r;
        if (largest == i) break;
        heap_swap(h, i, largest);
        i = largest;
    }
}

/* 插入元素；若超出容量则弹出堆顶（最大值），保留 K 个最小值 */
static void heap_push(MaxHeap *h, int idx, float dist) {
    if (h->size < h->capacity) {
        h->data[h->size++] = (HeapNode){ idx, dist };
        heap_sift_up(h, h->size - 1);
    } else if (dist < h->data[0].dist) {
        /* 新值比堆顶（最大距离）更小，替换堆顶 */
        h->data[0] = (HeapNode){ idx, dist };
        heap_sift_down(h, 0);
    }
}

/* ════════════════════════════════════════════════════
 * PoseClassifier 实现
 * ════════════════════════════════════════════════════ */

void pc_init(PoseClassifier *pc,
             const PoseSample *samples, int sample_count) {
    pc->samples          = samples;
    pc->sample_count     = sample_count;
    pc->max_dist_top_k   = MAX_DISTANCE_TOP_K;
    pc->mean_dist_top_k  = MEAN_DISTANCE_TOP_K;
    pc->axes_weights     = (PointF3D){ 1.0f, 1.0f, 0.2f };
}

int pc_confidence_range(const PoseClassifier *pc) {
    int a = pc->max_dist_top_k, b = pc->mean_dist_top_k;
    return a < b ? a : b;
}

/* 计算两个嵌入向量之间带权重的最大分量距离（对应 maxAbs 版本）*/
static float max_distance(const PointF3D *emb_a, const PointF3D *emb_b,
                           PointF3D weights) {
    float max_d = 0.0f;
    for (int i = 0; i < EMBEDDING_DIM; i++) {
        PointF3D diff  = pt_sub(emb_a[i], emb_b[i]);
        PointF3D wdiff = pt_mul_point(diff, weights);
        float    d     = pt_max_abs(wdiff);
        if (d > max_d) max_d = d;
    }
    return max_d;
}

/* 计算两个嵌入向量之间带权重的平均绝对距离（对应 sumAbs / (dim*2) 版本）*/
static float mean_distance(const PointF3D *emb_a, const PointF3D *emb_b,
                            PointF3D weights) {
    float sum = 0.0f;
    for (int i = 0; i < EMBEDDING_DIM; i++) {
        PointF3D diff  = pt_sub(emb_a[i], emb_b[i]);
        PointF3D wdiff = pt_mul_point(diff, weights);
        sum += pt_sum_abs(wdiff);
    }
    return sum / (float)(EMBEDDING_DIM * 2);
}

void pc_classify(const PoseClassifier *pc,
                 const PointF3D *landmarks,
                 ClassificationResult *result) {
    cr_init(result);
    if (!landmarks || pc->sample_count == 0) return;

    /* ── 计算输入姿势的嵌入向量（正向 + 水平镜像）── */
    PointF3D embedding[EMBEDDING_DIM];
    get_pose_embedding(landmarks, embedding);

    /* 水平镜像：X 轴取反，对应 Java multiplyAll(landmarks, (-1, 1, 1)) */
    PointF3D flipped[NUM_LANDMARKS];
    for (int i = 0; i < NUM_LANDMARKS; i++) {
        flipped[i] = (PointF3D){ -landmarks[i].x, landmarks[i].y, landmarks[i].z };
    }
    PointF3D flipped_emb[EMBEDDING_DIM];
    get_pose_embedding(flipped, flipped_emb);

    /* ── 第一阶段：按最大距离选 Top maxDistTopK 个样本 ── */
    MaxHeap max_heap;
    heap_init(&max_heap, pc->max_dist_top_k);

    for (int i = 0; i < pc->sample_count; i++) {
        const PointF3D *sample_emb = pc->samples[i].embedding;
        float orig_max    = max_distance(embedding,      sample_emb, pc->axes_weights);
        float flipped_max = max_distance(flipped_emb,    sample_emb, pc->axes_weights);
        float dist        = orig_max < flipped_max ? orig_max : flipped_max;
        heap_push(&max_heap, i, dist);
    }

    /* ── 第二阶段：对第一阶段结果按平均距离选 Top meanDistTopK 个样本 ── */
    MaxHeap mean_heap;
    heap_init(&mean_heap, pc->mean_dist_top_k);

    for (int h = 0; h < max_heap.size; h++) {
        int           idx        = max_heap.data[h].sample_idx;
        const PointF3D *sample_emb = pc->samples[idx].embedding;
        float orig_mean    = mean_distance(embedding,   sample_emb, pc->axes_weights);
        float flipped_mean = mean_distance(flipped_emb, sample_emb, pc->axes_weights);
        float dist         = orig_mean < flipped_mean ? orig_mean : flipped_mean;
        heap_push(&mean_heap, idx, dist);
    }

    /* ── 统计各类别出现次数（incrementClassConfidence）── */
    for (int h = 0; h < mean_heap.size; h++) {
        int sample_idx = mean_heap.data[h].sample_idx;
        cr_increment(result, pc->samples[sample_idx].class_name);
    }
}

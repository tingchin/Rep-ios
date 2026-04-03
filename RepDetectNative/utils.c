#include "utils.h"
#include <math.h>

/* ── 单点运算 ── */

PointF3D pt_add(PointF3D a, PointF3D b) {
    return (PointF3D){ a.x + b.x, a.y + b.y, a.z + b.z };
}

/* second - first，与 Java Utils.subtract(b, a) = a - b 一致 */
PointF3D pt_sub(PointF3D first, PointF3D second) {
    return (PointF3D){ second.x - first.x, second.y - first.y, second.z - first.z };
}

PointF3D pt_mul_scalar(PointF3D a, float s) {
    return (PointF3D){ a.x * s, a.y * s, a.z * s };
}

PointF3D pt_mul_point(PointF3D a, PointF3D m) {
    return (PointF3D){ a.x * m.x, a.y * m.y, a.z * m.z };
}

PointF3D pt_avg(PointF3D a, PointF3D b) {
    return (PointF3D){
        (a.x + b.x) * 0.5f,
        (a.y + b.y) * 0.5f,
        (a.z + b.z) * 0.5f
    };
}

float pt_l2norm2d(PointF3D p) {
    return sqrtf(p.x * p.x + p.y * p.y);
}

float pt_max_abs(PointF3D p) {
    float ax = fabsf(p.x), ay = fabsf(p.y), az = fabsf(p.z);
    float m = ax > ay ? ax : ay;
    return m > az ? m : az;
}

float pt_sum_abs(PointF3D p) {
    return fabsf(p.x) + fabsf(p.y) + fabsf(p.z);
}

/* ── 数组批量运算 ── */

void lm_subtract_all(PointF3D *landmarks, int n, PointF3D center) {
    for (int i = 0; i < n; i++) {
        landmarks[i].x -= center.x;
        landmarks[i].y -= center.y;
        landmarks[i].z -= center.z;
    }
}

void lm_multiply_all_scalar(PointF3D *landmarks, int n, float s) {
    for (int i = 0; i < n; i++) {
        landmarks[i].x *= s;
        landmarks[i].y *= s;
        landmarks[i].z *= s;
    }
}

void lm_multiply_all_point(PointF3D *landmarks, int n, PointF3D m) {
    for (int i = 0; i < n; i++) {
        landmarks[i].x *= m.x;
        landmarks[i].y *= m.y;
        landmarks[i].z *= m.z;
    }
}

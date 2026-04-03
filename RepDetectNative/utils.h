#ifndef UTILS_H
#define UTILS_H

#include "pose_types.h"

/* ── 单点运算 ── */
PointF3D pt_add(PointF3D a, PointF3D b);

/*
 * pt_sub(first, second) = second - first
 * 对应 Java: Utils.subtract(PointF3D b, PointF3D a) { return a - b; }
 * 调用方式与 Java 一致：pt_sub(LEFT_SHOULDER, LEFT_ELBOW) = LEFT_ELBOW - LEFT_SHOULDER
 */
PointF3D pt_sub(PointF3D first, PointF3D second);

PointF3D pt_mul_scalar(PointF3D a, float s);
PointF3D pt_mul_point(PointF3D a, PointF3D m);
PointF3D pt_avg(PointF3D a, PointF3D b);
float    pt_l2norm2d(PointF3D p);   /* sqrt(x^2 + y^2) */
float    pt_max_abs(PointF3D p);    /* max(|x|, |y|, |z|) */
float    pt_sum_abs(PointF3D p);    /* |x| + |y| + |z| */

/* ── 数组批量运算 ── */
/* 每个点减去 center：landmarks[i] = landmarks[i] - center */
void lm_subtract_all(PointF3D *landmarks, int n, PointF3D center);
/* 每个点乘以标量 */
void lm_multiply_all_scalar(PointF3D *landmarks, int n, float s);
/* 每个点与另一个点逐分量相乘 */
void lm_multiply_all_point(PointF3D *landmarks, int n, PointF3D m);

#endif /* UTILS_H */

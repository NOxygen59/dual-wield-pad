#include "DWGeometry.h"

#include <math.h>

bool DWProjectCorners(double width, double height, double eyeDistance, double eyeHeight, double closeRadians, DWPoint out[4]) {
    if (!(width > 0 && height > 0 && eyeDistance > 0) || !isfinite(closeRadians) || !isfinite(eyeHeight)) {
        return false;
    }
    // x along the hinge, y up the reference screen, z toward the viewer; the hinge is the x axis.
    const double c = cos(closeRadians), s = sin(closeRadians);
    // The closed screen's plane: through the hinge, spanned by x and its up direction (0, c, s).
    const double nY = -s, nZ = c;
    const double ex = width / 2, ey = eyeHeight, ez = eyeDistance;
    const double eyeSide = nY * ey + nZ * ez;
    // The eye must stay in front of the screen (and not graze it).
    if (eyeSide <= 1e-6 * height) {
        return false;
    }
    const double corners[4][2] = {{0, 0}, {width, 0}, {width, height}, {0, height}};
    for (int i = 0; i < 4; i++) {
        const double dx = corners[i][0] - ex, dy = corners[i][1] - ey, dz = 0 - ez;
        const double denom = nY * dy + nZ * dz;
        if (fabs(denom) < 1e-9) {
            return false;
        }
        const double t = -eyeSide / denom;
        if (!(t > 0) || !isfinite(t)) {
            return false;
        }
        const double qx = ex + t * dx, qy = ey + t * dy, qz = ez + t * dz;
        const double u = qx, v = qy * c + qz * s;
        // Far outside the screen: the warp would be degenerate.
        if (!isfinite(u) || !isfinite(v) || fabs(u) > 20 * width || fabs(v) > 20 * height) {
            return false;
        }
        out[i] = (DWPoint){u, v};
    }
    return true;
}

bool DWHomography(const DWPoint src[4], const DWPoint dst[4], double h[9]) {
    // Eight equations in h0..h7 (h8 = 1), solved by Gaussian elimination with partial pivoting.
    double a[8][9];
    for (int i = 0; i < 4; i++) {
        const double x = src[i].x, y = src[i].y, X = dst[i].x, Y = dst[i].y;
        const double r0[9] = {x, y, 1, 0, 0, 0, -x * X, -y * X, X};
        const double r1[9] = {0, 0, 0, x, y, 1, -x * Y, -y * Y, Y};
        for (int j = 0; j < 9; j++) {
            a[2 * i][j] = r0[j];
            a[2 * i + 1][j] = r1[j];
        }
    }
    for (int col = 0; col < 8; col++) {
        int pivot = col;
        for (int r = col + 1; r < 8; r++) {
            if (fabs(a[r][col]) > fabs(a[pivot][col])) {
                pivot = r;
            }
        }
        if (fabs(a[pivot][col]) < 1e-12) {
            return false;
        }
        if (pivot != col) {
            for (int j = 0; j < 9; j++) {
                const double tmp = a[col][j];
                a[col][j] = a[pivot][j];
                a[pivot][j] = tmp;
            }
        }
        for (int r = 0; r < 8; r++) {
            if (r == col) {
                continue;
            }
            const double f = a[r][col] / a[col][col];
            for (int j = col; j < 9; j++) {
                a[r][j] -= f * a[col][j];
            }
        }
    }
    for (int i = 0; i < 8; i++) {
        h[i] = a[i][8] / a[i][i];
        if (!isfinite(h[i])) {
            return false;
        }
    }
    h[8] = 1;
    return true;
}

double DWHingeAngle(double gx, double gy, double gz) {
    const double g = sqrt(gx * gx + gy * gy + gz * gz);
    if (!(g > 1e-6)) {
        return NAN;
    }
    // The screen leans back when gravity points behind it (z < 0).
    double sine = -gz / g;
    if (sine > 1) sine = 1;
    if (sine < -1) sine = -1;
    return 90.0 + asin(sine) * 180.0 / M_PI;
}

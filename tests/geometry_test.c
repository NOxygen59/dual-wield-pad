// Host test of DWGeometry: cc -I.. geometry_test.c ../DWGeometry.c -lm && ./a.out
#include <math.h>
#include <stdio.h>
#include "../DWGeometry.h"

static int failures = 0;
#define CHECK(cond, ...) do { if (!(cond)) { failures++; printf("FAIL %s:%d: ", __FILE__, __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)
static bool near(double a, double b, double eps) { return fabs(a - b) <= eps; }

int main(void) {
    DWPoint q[4];
    // Not closed: the picture stays where it is.
    CHECK(DWProjectCorners(1.0, 0.75, 1.8, 0.45, 0, q), "identity projects");
    const double ref[4][2] = {{0, 0}, {1, 0}, {1, 0.75}, {0, 0.75}};
    for (int i = 0; i < 4; i++) CHECK(near(q[i].x, ref[i][0], 1e-9) && near(q[i].y, ref[i][1], 1e-9), "corner %d unchanged: %f %f", i, q[i].x, q[i].y);

    // Closing: the hinge corners stay put; the top comes nearer the eye, so the top corners land
    // higher up the turned screen and closer together, symmetrically.
    CHECK(DWProjectCorners(1.0, 0.75, 1.8, 0.45, 30 * M_PI / 180, q), "30 degrees projects");
    CHECK(near(q[0].x, 0, 1e-9) && near(q[0].y, 0, 1e-9) && near(q[1].x, 1, 1e-9) && near(q[1].y, 0, 1e-9), "hinge corners fixed");
    CHECK(q[2].y > 0.75 && q[3].y > 0.75, "top higher: %f %f", q[2].y, q[3].y);
    CHECK(q[3].x > 0 && q[2].x < 1 && near(q[3].x + q[2].x, 1, 1e-9), "top narrows symmetrically: %f %f", q[3].x, q[2].x);

    // Monotonic: more closed, taller picture.
    DWPoint q2[4];
    CHECK(DWProjectCorners(1.0, 0.75, 1.8, 0.45, 50 * M_PI / 180, q2), "50 degrees projects");
    CHECK(q2[2].y > q[2].y, "taller when more closed");

    // Nearly flat on the keyboard: the eye can't see the front any more.
    CHECK(!DWProjectCorners(1.0, 0.75, 1.8, 0.45, 89.9 * M_PI / 180, q), "closed is invalid");
    CHECK(!DWProjectCorners(0, 0.75, 1.8, 0.45, 0.1, q), "bad size is invalid");

    // Homography: maps the corners exactly, and a midpoint projectively.
    const DWPoint src[4] = {{0, 0}, {100, 0}, {100, 80}, {0, 80}};
    const DWPoint dst[4] = {{0, 0}, {100, 0}, {120, 110}, {-20, 110}};
    double h[9];
    CHECK(DWHomography(src, dst, h), "homography solves");
    for (int i = 0; i < 4; i++) {
        const double w = h[6] * src[i].x + h[7] * src[i].y + h[8];
        const double X = (h[0] * src[i].x + h[1] * src[i].y + h[2]) / w, Y = (h[3] * src[i].x + h[4] * src[i].y + h[5]) / w;
        CHECK(near(X, dst[i].x, 1e-6) && near(Y, dst[i].y, 1e-6), "corner %d maps: %f %f", i, X, Y);
    }
    const DWPoint line[4] = {{0, 0}, {1, 1}, {2, 2}, {0, 5}};
    CHECK(!DWHomography(line, dst, h), "collinear points rejected");

    // Hinge angle from gravity: upright 90, leaning back 120, closing 60.
    CHECK(near(DWHingeAngle(-1, 0, 0), 90, 1e-9), "upright: %f", DWHingeAngle(-1, 0, 0));
    CHECK(near(DWHingeAngle(-cos(M_PI / 6), 0, -sin(M_PI / 6)), 120, 1e-9), "leaning back: %f", DWHingeAngle(-cos(M_PI / 6), 0, -sin(M_PI / 6)));
    CHECK(near(DWHingeAngle(-cos(M_PI / 6), 0, sin(M_PI / 6)), 60, 1e-9), "closing: %f", DWHingeAngle(-cos(M_PI / 6), 0, sin(M_PI / 6)));
    CHECK(isnan(DWHingeAngle(0, 0, 0)), "no gravity");

    printf(failures ? "%d failure(s)\n" : "all geometry tests pass\n", failures);
    return failures != 0;
}

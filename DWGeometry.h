// Dual Wield Pad: the geometry, in plain C (tested on the Mac by tests/geometry_test.c).
//
// The screen turns about its bottom edge (the Magic Keyboard's hinge). A viewer in front of it
// should keep seeing the picture where the screen was at the reference angle, as it closes:
// each corner of that picture is cast from the eye onto the turned screen, and the screen shows
// the picture warped onto those four points.

#ifndef DWGEOMETRY_H
#define DWGEOMETRY_H

#include <stdbool.h>

typedef struct {
    double x, y;
} DWPoint;

// Where the reference picture's corners land on a screen closed by `closeRadians` from the
// reference angle, in hinge coordinates: u along the hinge (0 at the viewer's left, `width` at the
// right), v up the screen from the hinge. Order: bottom left, bottom right, top right, top left.
// The eye is `eyeDistance` in front of the reference screen and `eyeHeight` above the hinge,
// centred. False when the eye no longer sees the screen's front well enough (nearly closed).
bool DWProjectCorners(double width, double height, double eyeDistance, double eyeHeight, double closeRadians, DWPoint out[4]);

// The projective transform taking src[i] to dst[i] (four points, no three in line), as
// x' = (h0 x + h1 y + h2) / (h6 x + h7 y + h8), y' = (h3 x + h4 y + h5) / (h6 x + h7 y + h8),
// with h8 = 1. False when the points don't define one.
bool DWHomography(const DWPoint src[4], const DWPoint dst[4], double h[9]);

// The hinge angle (degrees between keyboard and screen: 90 upright, more when leaning back) from
// the accelerometer's gravity in the device's axes (x right and y up in portrait, z out of the
// screen), assuming the keyboard lies flat.
double DWHingeAngle(double gx, double gy, double gz);

#endif

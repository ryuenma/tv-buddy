package com.gathin.tvhome;

/**
 * Box blur over a packed ARGB pixel buffer. Kept free of Android types so it can be unit tested on
 * the JVM; {@link WallpaperPlayer} shrinks the picture and hands the pixels here once at decode time.
 */
final class Blur {
    /** Neighbours either side, so each pass averages 5 samples (fewer at the edges). */
    private static final int RADIUS = 2;

    private Blur() {
    }

    /** Blurs {@code px} in place: one pass across, then one down. */
    static void apply(int[] px, int w, int h) {
        int[] mid = new int[px.length];
        axis(px, mid, w, h, true);
        axis(px, mid, w, h, false);
    }

    /**
     * One pass along one axis. Both orientations write the same linear index they read, so a single
     * copy back from the scratch buffer finishes either direction.
     */
    private static void axis(int[] px, int[] mid, int w, int h, boolean horizontal) {
        int lines = horizontal ? h : w, limit = horizontal ? w : h;
        for (int a = 0; a < lines; a++) {
            for (int b = 0; b < limit; b++) {
                int r = 0, g = 0, bl = 0, n = 0;
                for (int k = -RADIUS; k <= RADIUS; k++) {
                    int c = b + k;
                    if (c < 0 || c >= limit) continue;
                    int colour = px[horizontal ? a * w + c : c * w + a];
                    r += (colour >> 16) & 0xFF;
                    g += (colour >> 8) & 0xFF;
                    bl += colour & 0xFF;
                    n++;
                }
                mid[horizontal ? a * w + b : b * w + a] =
                        0xFF000000 | (r / n) << 16 | (g / n) << 8 | (bl / n);
            }
        }
        System.arraycopy(mid, 0, px, 0, px.length);
    }
}

package com.gathin.tvhome;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

/**
 * The blur runs once per wallpaper change, so a wrong average would quietly wash the backdrop out
 * rather than fail loudly. These pin the arithmetic on a single row, where the edge clamping and the
 * 5-sample window are both exercised.
 */
public class BlurTest {

    private static final int BLACK = 0xFF000000;
    private static final int WHITE = 0xFFFFFFFF;

    /** Three black pixels then two white, one row: the clamp at each end and the mix in between. */
    @Test
    public void averagesFiveNeighbourWindowAndClampsAtEdges() {
        int[] px = {BLACK, BLACK, BLACK, WHITE, WHITE};
        Blur.apply(px, 5, 1);

        // Left edge sees only 0..2, all black.
        assertEquals(BLACK, px[0]);
        // Centre sees all five: 3 black + 2 white -> 2/5 * 255 = 102 = 0x66.
        assertEquals(0xFF666666, px[2]);
        // Right edge sees only 2..4: 1 black + 2 white -> 2/3 * 255 = 170 = 0xAA.
        assertEquals(0xFFAAAAAA, px[4]);
    }

    /** Alpha is forced opaque, so an RGB_565 source cannot come back translucent. */
    @Test
    public void outputIsAlwaysOpaque() {
        int[] px = {0x00123456, 0x00789ABC, 0x00FFFFFF};
        Blur.apply(px, 3, 1);
        for (int p : px) assertEquals(0xFF000000, p & 0xFF000000);
    }

    /** A uniform field must come back untouched, in both axes. */
    @Test
    public void uniformFieldIsUnchanged() {
        int[] px = new int[9];
        for (int i = 0; i < px.length; i++) px[i] = 0xFF203040;
        Blur.apply(px, 3, 3);
        for (int p : px) assertEquals(0xFF203040, p);
    }
}

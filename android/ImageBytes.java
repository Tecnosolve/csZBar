package org.cloudsky.cordovaPlugins;

import android.util.Base64;

/**
 * Created by davincif on 05/10/17.
 */

public final class ImageBytes {
    public static byte img[];

    private ImageBytes() {
        img = null;
    }

    public static String Base64img() {
        return Base64.encodeToString(img, Base64.DEFAULT);
    }
}

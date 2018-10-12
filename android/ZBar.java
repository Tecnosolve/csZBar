package org.cloudsky.cordovaPlugins;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.app.Activity;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.Context;

import android.content.pm.PackageManager;
import android.Manifest;
import android.support.v4.app.ActivityCompat;
import android.support.v7.app.AlertDialog;
import android.util.Log;

import org.apache.cordova.PermissionHelper;

import org.cloudsky.cordovaPlugins.ZBarScannerActivity;


public class ZBar extends CordovaPlugin {

    // Configuration ---------------------------------------------------

    private static int SCAN_CODE = 1;


    // State -----------------------------------------------------------

    private boolean isInProgress = false;
    private CallbackContext scanCallbackContext;

    //permissions
    private String[] permissions = {Manifest.permission.CAMERA};
    private JSONObject params;


    public static final int MY_PERMISSIONS_REQUEST_CAMERA = 1;

    // Plugin API ------------------------------------------------------

    private String _action;
    private JSONArray _args;
    private CallbackContext _callbackContext;

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext)
            throws JSONException {

        this._action = action;
        this._args = args;
        this._callbackContext = callbackContext;

        if (hasPermission()) {
            if (action.equals("scan")) {
                if (isInProgress) {
                    callbackContext.error("A scan is already in progress!");
                } else {
                    scanCallbackContext = callbackContext;
                    isInProgress = true;
                    JSONObject params = args.optJSONObject(0);

                    Context appCtx = cordova.getActivity().getApplicationContext();
                    Intent scanIntent = new Intent(appCtx, ZBarScannerActivity.class);
                    scanIntent.putExtra(ZBarScannerActivity.EXTRA_PARAMS, params.toString());
                    cordova.startActivityForResult(this, scanIntent, SCAN_CODE);
                }
                return true;
            } else {
                return false;
            }
        } else {

            PermissionHelper.requestPermissions(this, MY_PERMISSIONS_REQUEST_CAMERA, permissions);
            return true;
        }
    }



//        if(action.equals("scan")) {
//            if(isInProgress) {
//                callbackContext.error("A scan is already in progress!");
//            } else {
//                isInProgress = true;
//                scanCallbackContext = callbackContext;
//                JSONObject params = args.optJSONObject(0);
//
//                Context appCtx = cordova.getActivity().getApplicationContext();
//                Intent scanIntent = new Intent(appCtx, ZBarScannerActivity.class);
//                scanIntent.putExtra(ZBarScannerActivity.EXTRA_PARAMS, params.toString());
//                cordova.startActivityForResult(this, scanIntent, SCAN_CODE);
//            }
//            return true;
//        } else {
//            return false;
//        }

    /**
     * check application's permissions
     */
    private boolean hasPermission() {
        for(String p : permissions)
        {
            if(!PermissionHelper.hasPermission(this, p))
            {
                return false;
            }
        }
        return true;
    }

    // External results handler ----------------------------------------

    @Override
    public void onActivityResult (int requestCode, int resultCode, Intent result)
    {
        if(requestCode == SCAN_CODE) {
            switch(resultCode) {
                case Activity.RESULT_OK:
                    String barcodeValue = result.getStringExtra(ZBarScannerActivity.EXTRA_QRVALUE);
                    scanCallbackContext.success(barcodeValue);
                    break;
                case Activity.RESULT_CANCELED:
                    int cancelledValue = result.getIntExtra(ZBarScannerActivity.EXTRA_CANCELLED, 0);

                    if(cancelledValue == 0){
                        scanCallbackContext.error("cancelled");
                    }else if(cancelledValue == 1){
                        scanCallbackContext.error("add_manually");
                    }else if(cancelledValue == 2){
                        scanCallbackContext.error("per_unit");
                    }

                    break;
                case ZBarScannerActivity.RESULT_ERROR:
                    scanCallbackContext.error("Scan failed due to an error");
                    break;
                default:
                    scanCallbackContext.error("Unknown error");
            }
            isInProgress = false;
            scanCallbackContext = null;
        }
    }

    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) throws JSONException {
        switch (requestCode) {
            case MY_PERMISSIONS_REQUEST_CAMERA: {
                Log.i("Camera", "G : " + grantResults[0]);
                // If request is cancelled, the result arrays are empty.
                if (grantResults.length > 0
                        && grantResults[0] == PackageManager.PERMISSION_GRANTED) {

                    this.execute(this._action, this._args, this._callbackContext);

                }
                return;
            }

        }
    }
}

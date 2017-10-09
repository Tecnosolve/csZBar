package org.cloudsky.cordovaPlugins;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.app.Activity;
import android.content.Intent;
import android.content.Context;

import android.content.pm.PackageManager;
import android.Manifest;
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


    // Plugin API ------------------------------------------------------

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext)
            throws JSONException {


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
            PermissionHelper.requestPermissions(this, 0, permissions);
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
                        PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, ImageBytes.Base64img());
                        pluginResult.setKeepCallback(true);
                        scanCallbackContext.sendPluginResult(pluginResult);
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
}

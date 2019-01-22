#import "CsZBar.h"
#import <AVFoundation/AVFoundation.h>
#import "AlmaZBarReaderViewController.h"
#import "ToneGenerator.h"

#define TRANSMIT_LENGTH 200

#define BASE 480 //18000 Hz seems to be detectable (hearable?)
                   //140-160 Hz is not quite hearable

#define UIColorFromRGB(rgbValue) [UIColor \
       colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
       green:((float)((rgbValue & 0xFF00) >> 8))/255.0 \
       blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

#pragma mark - State

@interface CsZBar ()
@property bool scanInProgress;
@property NSString *scanCallbackId;
@property NSString *barCode;
@property AlmaZBarReaderViewController *scanReader;
@property bool scanProducts;
@end

#pragma mark - Synthesize

@implementation CsZBar

@synthesize scanInProgress;
@synthesize scanCallbackId;
@synthesize barCode;
@synthesize scanReader;
@synthesize scanProducts;


#pragma mark - Cordova Plugin

- (void)pluginInitialize {
    self.scanInProgress = NO;
}

// - (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
//     return;
// }

// - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//     return YES;
// }

#pragma mark - Plugin API

- (void)scan: (CDVInvokedUrlCommand*)command;
{
    if (self.scanInProgress) {
        [self.commandDelegate
         sendPluginResult: [CDVPluginResult
                            resultWithStatus: CDVCommandStatus_ERROR
                            messageAsString:@"A scan is already in progress."]
         callbackId: [command callbackId]];
    } else {
        self.scanInProgress = YES;
        self.scanCallbackId = [command callbackId];
        self.scanReader = [AlmaZBarReaderViewController new];

        self.scanReader.readerDelegate = self;
        self.scanReader.supportedOrientationsMask = ZBarOrientationMask(UIInterfaceOrientationPortrait);

        // Get user parameters
        NSDictionary *params = (NSDictionary*) [command argumentAtIndex:0];
        NSString *camera = [params objectForKey:@"camera"];
        if([camera isEqualToString:@"front"]) {
            // We do not set any specific device for the default "back" setting,
            // as not all devices will have a rear-facing camera.
            self.scanReader.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        }
        self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;

        NSString *flash = [params objectForKey:@"flash"];

        if ([flash isEqualToString:@"on"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        } else if ([flash isEqualToString:@"off"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        }else if ([flash isEqualToString:@"auto"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
        }

        // // Hack to hide the bottom bar's Info button... originally based on http://stackoverflow.com/a/16353530
	    // NSInteger infoButtonIndex;
        // if ([[[UIDevice currentDevice] systemVersion] compare:@"10.0" options:NSNumericSearch] != NSOrderedAscending) {
        //     infoButtonIndex = 1;
        // } else {
        //     infoButtonIndex = 3;
        // }

        //UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem]; [button setTitle:@"Press Me" forState:UIControlStateNormal]; [button sizeToFit]; [self.view addSubview:button];
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        CGFloat screenHeight = screenRect.size.height;

        BOOL drawFlashToggleButton = [params objectForKey:@"drawFlashToggleButton"] ? [[params objectForKey:@"drawFlashToggleButton"] boolValue] : false;
        BOOL drawPerUnitButton = [params objectForKey:@"drawPerUnitButton"] ? [[params objectForKey:@"drawPerUnitButton"] boolValue] : false;
        self.scanProducts = [params objectForKey:@"scanProducts"] ? [[params objectForKey:@"scanProducts"] boolValue] : false;

        UIToolbar *toolbarView = [[UIToolbar alloc] init];
        toolbarView.frame = CGRectMake(0.0, 0, screenWidth, 44.0);
        toolbarView.barStyle = UIBarStyleBlackOpaque;

        UIBarButtonItem *flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
        UIBarButtonItem *buttonCancel = [[UIBarButtonItem alloc] initWithTitle:@"Cancelar" style:UIBarButtonItemStyleDone target:self action:@selector(cancelAndDismiss)];

         if(drawFlashToggleButton){

             //The bar length it depends on the orientation
             UIBarButtonItem *buttonFlash = [[UIBarButtonItem alloc] initWithTitle:@"Ativar Flash" style:UIBarButtonItemStyleDone target:self action:@selector(toggleflash)];
             NSMutableArray *buttons = [NSMutableArray arrayWithObjects: buttonFlash, flexible, buttonCancel, nil];
             [toolbarView setItems:buttons animated:NO];
             [self.scanReader.view addSubview:toolbarView];


         }
        if(drawPerUnitButton){

            //The bar length it depends on the orientation
            UIBarButtonItem *buttonFlash = [[UIBarButtonItem alloc] initWithTitle:@"Produtos Unitários" style:UIBarButtonItemStyleDone target:self action:@selector(perUnitButtonPressed)];
            NSMutableArray *buttons = [NSMutableArray arrayWithObjects: buttonFlash, flexible, buttonCancel, nil];
            [toolbarView setItems:buttons animated:NO];
            [self.scanReader.view addSubview:toolbarView];


        }else{

            NSMutableArray *buttons = [NSMutableArray arrayWithObjects: flexible, buttonCancel, nil];
            [toolbarView setItems:buttons animated:NO];
            [self.scanReader.view addSubview:toolbarView];

        }

        BOOL drawAddManuallyButton = [params objectForKey:@"drawAddManuallyButton"] ? [[params objectForKey:@"drawAddManuallyButton"] boolValue] : false;

        if (drawAddManuallyButton) {

            UIButton *addManuallyButton = [[UIButton alloc] initWithFrame:CGRectMake(0, screenHeight - 50, screenWidth, 50)];
            addManuallyButton.backgroundColor = UIColorFromRGB(0x76c043);
            //addManuallyButton.frame = CGRectMake(210, 285, 100, 18);
            [addManuallyButton setTitle:@"Digite o código de barras" forState:UIControlStateNormal];
            [addManuallyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [addManuallyButton addTarget:self action:@selector(addManually) forControlEvents:UIControlEventTouchUpInside];
            //addManuallyButton.frame = CGRectMake(0, self.scanReader.view.frame.size.height - 100, self.scanReader.view.frame.size.width, 100);
            [self.scanReader.view addSubview:addManuallyButton];
            [self.scanReader.view bringSubviewToFront: addManuallyButton];

        }

        BOOL drawSight = [params objectForKey:@"drawSight"] ? [[params objectForKey:@"drawSight"] boolValue] : false;

        if (drawSight) {
            CGFloat dim = screenWidth < screenHeight ? screenWidth / 1.1 : screenHeight / 1.1;
            UIView *polygonView = [[UIView alloc] initWithFrame: CGRectMake  ( (screenWidth/2) - (dim/2), (screenHeight/2) - (dim/2), dim, dim)];

            UIView *lineView = [[UIView alloc] initWithFrame:CGRectMake(0,dim / 2, dim, 1)];
            lineView.backgroundColor = [UIColor redColor];
            [polygonView addSubview:lineView];

            self.scanReader.cameraOverlayView = polygonView;
        }

        self.scanReader.scanCrop = CGRectMake(0.49, 0.10, 0.02, 0.8);

        [self.scanReader.scanner setSymbology: ZBAR_NONE config: ZBAR_CFG_ENABLE to: 0];
        [self.scanReader.scanner setSymbology: ZBAR_EAN2 config: ZBAR_CFG_ENABLE to: 1];
        [self.scanReader.scanner setSymbology: ZBAR_EAN5 config: ZBAR_CFG_ENABLE to: 1];
        [self.scanReader.scanner setSymbology: ZBAR_EAN8 config: ZBAR_CFG_ENABLE to: 1];
        [self.scanReader.scanner setSymbology: ZBAR_EAN13 config: ZBAR_CFG_ENABLE to: 1];
        [self.scanReader.scanner setSymbology: ZBAR_UPCA config: ZBAR_CFG_ENABLE to: 1];
        [self.scanReader.scanner setSymbology: ZBAR_UPCE config: ZBAR_CFG_ENABLE to: 1];

        [self.viewController presentViewController:self.scanReader animated:YES completion:nil];
    }
}

- (void)toggleflash {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    [device lockForConfiguration:nil];
    if (device.torchAvailable == 1) {
        if (device.torchMode == 0) {
            [device setTorchMode:AVCaptureTorchModeOn];
            [device setFlashMode:AVCaptureFlashModeOn];
        } else {
            [device setTorchMode:AVCaptureTorchModeOff];
            [device setFlashMode:AVCaptureFlashModeOff];
        }
    }

    [device unlockForConfiguration];
}

- (void)addManually{
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"add_manually"]];
    }];
}

- (void)perUnitButtonPressed{

    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"per_unit"]];
    }];
}

#pragma mark - Helpers

- (void)sendScanResult: (CDVPluginResult*)result {
    [self.commandDelegate sendPluginResult: result callbackId: self.scanCallbackId];
}

#pragma mark - ZBarReaderDelegate

- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    return;
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info {
    if ([self.scanReader isBeingDismissed]) {
        return;
    }

    id<NSFastEnumeration> results = [info objectForKey: ZBarReaderControllerResults];

    ZBarSymbol *symbol = nil;
    for (symbol in results) break; // get the first result
    self.barCode = symbol.data;

    // if(!self.scanProducts || [self checkEAN:symbol.data]){

    ToneGenerator *toneGenerator = [[ToneGenerator alloc] init];
    [toneGenerator playFrequency:BASE forDuration:TRANSMIT_LENGTH];

    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                               resultWithStatus: CDVCommandStatus_OK
                               messageAsString: symbol.data]];
    }];
    //}
}

- (bool) checkEAN: (NSString *)barCode{

    NSInteger pair = 0;
    NSInteger odd = 0;
    NSInteger verifyingDigit = [[barCode substringFromIndex: [barCode length] - 1] integerValue];
    NSInteger auxiliary = 0;
    NSInteger sum = 0;

    if ([self checkBarCodeSize:barCode]) {

        for (int i = 0; i < ([self.barCode length] - 1); i++) {
            if ((i +1) % 2 == 0) {
                pair += [[self.barCode substringWithRange:NSMakeRange(i, 1)] integerValue];
            } else {
                odd += [[self.barCode substringWithRange:NSMakeRange(i, 1)] integerValue];
            }
        }

        sum = (pair * 3) + odd;
        auxiliary = sum;
        auxiliary += 10 - (auxiliary%10);
        auxiliary -= sum;
    }

    return (auxiliary == verifyingDigit);

}

- (bool) checkBarCodeSize:(NSString *)barCode{
    bool r = false;
    if ([barCode length] == 8) {  //EAN-8
        self.barCode = [NSString stringWithFormat:@"%@%@", @"00000", barCode];
        r = true;
    } else if ([barCode length] == 13) { //EAN-13
        self.barCode = barCode;
        r = true;
    }
    return r;
}

- (void) cancelAndDismiss {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"cancelled"]];
    }];
}

- (void) imagePickerControllerDidCancel:(UIImagePickerController*)picker {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"cancelled"]];
    }];
}

- (void) readerControllerDidFailToRead:(ZBarReaderController*)reader withRetry:(BOOL)retry {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"Failed"]];
    }];
}

@end

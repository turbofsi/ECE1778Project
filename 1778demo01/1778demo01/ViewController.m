//
//  ViewController.m
//  1778demo01
//
//  Created by  吕欣韵 on 2015-01-13.
//  Copyright (c) 2015 UofT. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

int sensor_count = 0;
int left_x_position, right_x_position;
int left_y_position, right_y_position;
int mouth_x_position, mouth_y_position;


-(void)viewDidAppear:(BOOL)animated{
    // Live Image Part
#pragma mark - live image
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPresetMedium;
    
    CALayer *viewLayer = self.liveImage.layer;
    NSLog(@"viewLayer = %@", viewLayer);
    
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    
    captureVideoPreviewLayer.frame = self.liveImage.bounds;
    [self.liveImage.layer addSublayer:captureVideoPreviewLayer];
    
    AVCaptureDevice *device;
    
    AVCaptureDevicePosition desiredPosition = AVCaptureDevicePositionFront;
    
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if ([d position] == desiredPosition) {
            device = d;
            break;
        }
    }
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        // Handle the error appropriately.
        NSLog(@"ERROR: trying to open camera: %@", error);
    }
    [session addInput:input];
    
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
    NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                       [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [self.videoDataOutput setVideoSettings:rgbOutputSettings];
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked
    
    // create a serial dispatch queue used for the sample buffer delegate
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    // see the header doc for setSampleBufferDelegate:queue: for more information
    self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
    
    
    if ( [session canAddOutput:self.videoDataOutput] ){
        [session addOutput:self.videoDataOutput];
    }

    
    [session startRunning];
    //  Live image Part End
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                      options:(__bridge NSDictionary *)attachments];
    
    
    NSDictionary *imageOptions = nil;
    
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    imageOptions = [NSDictionary dictionaryWithObject:[self exifOrientation:curDeviceOrientation]
                                               forKey:CIDetectorImageOrientation];
    
    NSArray *features = [self.faceDetector featuresInImage:ciImage options:imageOptions];
    
    if ([features count] == 0) {
        sensor_count++;
        NSLog(@"%d", sensor_count);
        if (sensor_count > 100) {
//            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        }
    }
    for (CIFaceFeature *f in features) {
        sensor_count = 0;
        if (f.hasLeftEyePosition) {
            left_x_position = f.leftEyePosition.x;
            left_y_position = f.leftEyePosition.y;
            
        }
        if (f.hasRightEyePosition) {
            right_x_position = f.rightEyePosition.x;
            right_y_position = f.rightEyePosition.y;
        }
        
        if (f.hasMouthPosition) {
            mouth_x_position = f.mouthPosition.x;
            mouth_y_position = f.mouthPosition.y;
        }
        
        if (f.hasRightEyePosition && f.hasLeftEyePosition) {
            if (abs(f.rightEyePosition.y - f.leftEyePosition.y) > 90) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"badSittingPosture" object:nil];
                NSLog(@"Bad sitting posture!!!");
            }
        }
    }
}

- (NSNumber *) exifOrientation: (UIDeviceOrientation) orientation
{
    int exifOrientation;
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants.
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
    enum {
        PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
        PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
        PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
    };
    
    switch (orientation) {
        case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            if (/* DISABLES CODE */ (YES))
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
            if (YES)
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            break;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        default:
            exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
            break;
    }
    return [NSNumber numberWithInt:exifOrientation];
}




- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
    self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(badAction) name:@"badSittingPosture" object:nil];
    
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.333 target:self selector:@selector(postionUpdate) userInfo:nil repeats:YES];
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addTimer:timer forMode:NSDefaultRunLoopMode];
    
    UIImage *alertImg = [UIImage imageNamed:@"alertframe"];
    
    UIImageView *imgView = [[UIImageView alloc] initWithImage:alertImg];
    imgView.frame = CGRectMake(160 - 30, _liveImage.frame.origin.y + 50, 60, 100);
    imgView.tag = 107;
    [self.view addSubview:imgView];
    [self.view bringSubviewToFront:imgView];
    
//    _leftLabel.text = @"hahaha";
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)badAction {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(110, 20, 100, 50)];
    label.text = @"bad";
    [self.view addSubview:label];
}

- (void)postionUpdate {
    float dis = sqrt(pow((left_x_position - right_x_position), 2) + pow((left_y_position - right_y_position), 2));
    float k = (float)(left_x_position - right_x_position) / (left_y_position - right_y_position);
    _leftLabel.text = [NSString stringWithFormat:@"%.2f", dis];
    _rightLabel.text = [NSString stringWithFormat:@"%.2f", k];
    
    UIImageView *imgView = (id)[self.view viewWithTag:107];
    if (k < 0) {
        k = -k;
    }
    
    if (mouth_x_position > 270 || k > 0.2 || dis > 80) {
        imgView.alpha = 1;
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);

    } else {
        imgView.alpha = 0;
    }
}
@end

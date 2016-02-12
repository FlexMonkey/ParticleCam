//
//  CameraCaptureHelper.swift
//  ParticleCam
//
//  Created by Simon Gladman on 12/02/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//


import AVFoundation
import CoreMedia
import CoreImage
import UIKit

/// `CameraCaptureHelper` wraps up all the code required to access an iOS device's
/// camera images and convert to a series of `CIImage` images.
///
/// The helper's delegate, `CameraCaptureHelperDelegate` receives notification of
/// a new image in the main thread via `newCameraImage()`.
class CameraCaptureHelper: NSObject
{
    let captureSession = AVCaptureSession()
    let cameraPosition: AVCaptureDevicePosition
    
    weak var delegate: CameraCaptureHelperDelegate?
    
    required init(cameraPosition: AVCaptureDevicePosition)
    {
        self.cameraPosition = cameraPosition
        
        super.init()
        
        initialiseCaptureSession()
    }
    
    private func initialiseCaptureSession()
    {
        captureSession.sessionPreset = AVCaptureSessionPresetiFrame1280x720
        
        guard let camera = (AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice])
            .filter({ $0.position == cameraPosition })
            .first else
        {
            fatalError("Unable to access camera")
        }
        
        do
        {
            let input = try AVCaptureDeviceInput(device: camera)
            
            captureSession.addInput(input)
        }
        catch
        {
            fatalError("Unable to access back camera")
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.setSampleBufferDelegate(self,
            queue: dispatch_queue_create("sample buffer delegate", DISPATCH_QUEUE_SERIAL))
        
        if captureSession.canAddOutput(videoOutput)
        {
            captureSession.addOutput(videoOutput)
        }
        
        captureSession.startRunning()
    }
}

extension CameraCaptureHelper: AVCaptureVideoDataOutputSampleBufferDelegate
{
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!)
    {
        connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIApplication.sharedApplication().statusBarOrientation.rawValue)!
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else
        {
            return
        }
        
        dispatch_async(dispatch_get_main_queue())
            {
                self.delegate?.newCameraImage(self,
                    image: CIImage(CVPixelBuffer: pixelBuffer))
        }
        
    }
}

protocol CameraCaptureHelperDelegate: class
{
    func newCameraImage(cameraCaptureHelper: CameraCaptureHelper, image: CIImage)
}

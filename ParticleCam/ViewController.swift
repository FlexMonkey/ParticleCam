//
//  ViewController.swift
//  ParticleCam
//
//  Created by Simon Gladman on 08/08/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, ParticleLabDelegate, AVCaptureVideoDataOutputSampleBufferDelegate
{

    var particleLab: ParticleLab!
    var videoTextureCache : Unmanaged<CVMetalTextureCacheRef>?
    
    override func viewDidLoad()
    {
        guard let device = MTLCreateSystemDefaultDevice() else
        {
            fatalError("metal unavailable on device")
        }
        
        super.viewDidLoad()
        
        let screenWidth = UInt(UIScreen.mainScreen().bounds.width)
        let screenHeight = UInt(UIScreen.mainScreen().bounds.height)
        
        particleLab = ParticleLab(width: screenWidth, height: screenHeight, numParticles: ParticleCount.OneMillion)
        
        particleLab.particleLabDelegate = self
        
        view.addSubview(particleLab)
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        
        let backCamera = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        do
        {
            let input = try AVCaptureDeviceInput(device: backCamera)
            
            captureSession.addInput(input)
        }
        catch
        {
            print("can't access camera")
            return
        }
        
        // although we don't use this, it's required to get captureOutput invoked
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("sample buffer delegate", DISPATCH_QUEUE_SERIAL))
        if captureSession.canAddOutput(videoOutput)
        {
            captureSession.addOutput(videoOutput)
        }
  
        captureSession.startRunning()
        
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &videoTextureCache)
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!)
    {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        var yTextureRef : Unmanaged<CVMetalTextureRef>?
        
        let yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer!, 0);
        let yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer!, 0);
        
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
            videoTextureCache!.takeUnretainedValue(),
            pixelBuffer!,
            nil,
            MTLPixelFormat.R8Unorm,
            yWidth, yHeight, 0,
            &yTextureRef)
        
        particleLab.cameraTexture = CVMetalTextureGetTexture((yTextureRef?.takeUnretainedValue())!)
        
        yTextureRef?.release()
    }

    
    func particleLabMetalUnavailable()
    {
        // handle metal unavailable here
    }
    
    func particleLabStatisticsDidUpdate(fps fps: Int, description: String)
    {
    }
    
    func particleLabDidUpdate()
    {
    }

    override func viewDidLayoutSubviews()
    {
        particleLab.frame = view.bounds
    }
    
}


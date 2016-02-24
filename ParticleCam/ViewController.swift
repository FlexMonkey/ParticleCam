//
//  ViewController.swift
//  ParticleCam
//
//  Created by Simon Gladman on 08/08/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//

import UIKit

class ViewController: UIViewController, CameraCaptureHelperDelegate
{
    let imageView = MetalImageView()
    
    let cameraCaptureHelper = CameraCaptureHelper(cameraPosition: .Front)
    
    let particleCamFilter = ParticleCamFilter()

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.addSubview(imageView)
        
        cameraCaptureHelper.delegate = self
    }
    
    override func viewDidLayoutSubviews()
    {
        // AVCaptureSessionPresetiFrame1280x720

        imageView.frame = CGRect(x: view.frame.midX - 640,
            y: view.frame.midY - 360,
            width: 1280,
            height: 720)
    }
    
    
    func newCameraImage(cameraCaptureHelper: CameraCaptureHelper, image: CIImage)
    {
        particleCamFilter.inputImage = image
        
        let finalImage = particleCamFilter.outputImage
        
        imageView.image = finalImage
    }
}


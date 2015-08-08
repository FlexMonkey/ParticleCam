//
//  ViewController.swift
//  ParticleCam
//
//  Created by Simon Gladman on 08/08/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//

import UIKit

class ViewController: UIViewController, ParticleLabDelegate
{

    var particleLab: ParticleLab!
    let floatPi = Float(M_PI)
    
    let fpsLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 400, height: 20))
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        particleLab = ParticleLab(width: 1024, height: 768, numParticles: ParticleCount.FourMillion)
        
        particleLab.dragFactor = 1
        particleLab.respawnOutOfBoundsParticles = true
        particleLab.particleLabDelegate = self
        
        view.addSubview(particleLab)
        
        fpsLabel.textColor = UIColor.whiteColor()
        view.addSubview(fpsLabel)
    }
    
    func particleLabMetalUnavailable()
    {
        // handle metal unavailable here
    }
    
    func particleLabStatisticsDidUpdate(fps fps: Int, description: String)
    {
        dispatch_async(dispatch_get_main_queue())
        {
            self.fpsLabel.text = description
        }
    }
    
    func particleLabDidUpdate()
    {
    }

    override func viewDidLayoutSubviews()
    {
        particleLab.frame = view.bounds
    }
    
}


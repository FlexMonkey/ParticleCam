//
//  ImageView.swift
//  ParticleCam
//
//  Created by Simon Gladman on 12/02/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//


import GLKit
import UIKit
import MetalKit

/// `MetalImageView` extends an `MTKView` and exposes an `image` property of type `CIImage` to
/// simplify Metal based rendering of Core Image filters.

class MetalImageView: MTKView
{
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    lazy var commandQueue: MTLCommandQueue =
        {
            [unowned self] in
            
            return self.device!.makeCommandQueue()!
            }()
    
    lazy var ciContext: CIContext =
        {
            [unowned self] in
            
            return CIContext(mtlDevice: self.device!)
            }()
    
    override init(frame frameRect: CGRect, device: MTLDevice?)
    {
        super.init(frame: frameRect,
                   device: device ?? MTLCreateSystemDefaultDevice())
        
        if super.device == nil
        {
            fatalError("Device doesn't support Metal")
        }
        
        framebufferOnly = false
    }
    
    required init(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// The image to display
    var image: CIImage?
    
    override func draw() {
        super.draw()
        
        guard let image = image,
            let targetTexture = currentDrawable?.texture else
        {
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let bounds = CGRect(origin: CGPoint.zero, size: drawableSize)
        
        let originX = image.extent.origin.x
        let originY = image.extent.origin.y
        
        let scaleX = drawableSize.width / image.extent.width
        let scaleY = drawableSize.height / image.extent.height
        let scale = min(scaleX, scaleY)
        
        let scaledImage = image
            .transformed(by: CGAffineTransform(translationX: -originX, y: -originY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        ciContext.render(scaledImage,
                         to: targetTexture,
                         commandBuffer: commandBuffer,
                         bounds: bounds,
                         colorSpace: colorSpace)
        
        commandBuffer.present(currentDrawable!)
        
        commandBuffer.commit()
    }
}

/// `OpenGLImageView` wraps up a `GLKView` and its delegate into a single class to simplify the
/// display of `CIImage`.
///
/// `OpenGLImageView` is hardcoded to simulate ScaleAspectFit: images are sized to retain their
/// aspect ratio and fit within the available bounds.
///
/// `OpenGLImageView` also respects `backgroundColor` for opaque colors

class OpenGLImageView: GLKView
{
    let eaglContext = EAGLContext(api: .openGLES2)
    
    lazy var ciContext: CIContext =
        {
            [unowned self] in
            
            return CIContext(eaglContext: self.eaglContext!,
                             options: [.workingColorSpace: NSNull()])
            }()
    
    override init(frame: CGRect)
    {
        super.init(frame: frame, context: eaglContext!)
        
        context = self.eaglContext!
        delegate = self
    }
    
    override init(frame: CGRect, context: EAGLContext)
    {
        fatalError("init(frame:, context:) has not been implemented")
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// The image to display
    var image: CIImage?
    {
        didSet
        {
            setNeedsDisplay()
        }
    }
}

extension OpenGLImageView: GLKViewDelegate
{
    func glkView(_ view: GLKView, drawIn rect: CGRect)
    {
        guard let image = image else
        {
            return
        }
        
        let targetRect = image.extent.aspectFitInRect(
            target: CGRect(origin: CGPoint.zero,
                           size: CGSize(width: drawableWidth,
                                        height: drawableHeight)))
        
        let ciBackgroundColor = CIColor(
            color: backgroundColor ?? UIColor.white)
        
        ciContext.draw(CIImage(color: ciBackgroundColor),
                       in: CGRect(x: 0,
                                  y: 0,
                                  width: drawableWidth,
                                  height: drawableHeight),
                       from: CGRect(x: 0,
                                    y: 0,
                                    width: drawableWidth,
                                    height: drawableHeight))
        
        ciContext.draw(image,
                       in: targetRect,
                       from: image.extent)
    }
}

extension CGRect
{
    func aspectFitInRect(target: CGRect) -> CGRect
    {
        let scale: CGFloat =
        {
            let scale = target.width / self.width
            
            return self.height * scale <= target.height ?
                scale :
                target.height / self.height
        }()
        
        let width = self.width * scale
        let height = self.height * scale
        let x = target.midX - width / 2
        let y = target.midY - height / 2
        
        return CGRect(x: x,
                      y: y,
                      width: width,
                      height: height)
    }
}

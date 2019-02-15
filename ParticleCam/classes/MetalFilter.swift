//
//  MetalFilter.swift
//  ParticleCam
//
//  Created by Simon Gladman on 12/02/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

// MARK: Base class

/// `MetalFilter` is a Core Image filter that uses a Metal compute function as its engine.
/// This version supports a single input image and an arbritrary number of `NSNumber`
/// parameters. Numeric parameters require a properly set `kCIAttributeIdentity` which
/// defines their buffer index into the Metal kernel.

import MetalKit
import CoreImage

class MetalFilter: CIFilter
{
    let device: MTLDevice = MTLCreateSystemDefaultDevice()!
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    lazy var ciContext: CIContext =
    {
        [unowned self] in
        
        return CIContext(mtlDevice: self.device)
        }()
    
    lazy var commandQueue: MTLCommandQueue =
    {
        [unowned self] in
        
        return self.device.makeCommandQueue()!
        }()
    
    lazy var defaultLibrary: MTLLibrary =
    {
        [unowned self] in
        
        return self.device.makeDefaultLibrary()!
        }()
    
    lazy var pipelineState: MTLComputePipelineState =
    {
        [unowned self] in
        
        let kernelFunction = self.defaultLibrary.makeFunction(name: self.functionName)!
        
        do
        {
            let pipelineState = try self.device.makeComputePipelineState(function: kernelFunction)
            return pipelineState
        }
        catch
        {
            fatalError("Unable to create pipeline state for kernel function \(self.functionName)")
        }
        }()
    
    let functionName: String
    
    let threadsPerThreadgroup = MTLSize(width:16,
        height:16,
        depth:1)
    
    var clearOnStep = true
    
    var threadgroupsPerGrid: MTLSize?
    
    var textureDescriptor: MTLTextureDescriptor?
    var kernelInputTexture: MTLTexture?
    var kernelOutputTexture: MTLTexture?
    
    func customThreadgroupsPerGrid() -> MTLSize? {return nil}
    func customThreadsPerThreadgroup() -> MTLSize? {return nil}
    func customBuffers() -> [(index: Int, buffer: MTLBuffer)]? {return nil}
    
    override var outputImage: CIImage!
    {
        if textureInvalid()
        {
            self.textureDescriptor = nil
        }
        
        if let imageFilter = self as? MetalImageFilter,
            let inputImage = imageFilter.inputImage
        {
            return imageFromComputeShader(width: inputImage.extent.width,
                height: inputImage.extent.height,
                inputImage: inputImage)
        }
        
        if let generatorFilter = self as? MetalGeneratorFilter
        {
            return imageFromComputeShader(width: generatorFilter.inputWidth,
                height: generatorFilter.inputHeight,
                inputImage: nil)
        }
        
        return nil
    }
    
    init(functionName: String)
    {
        self.functionName = functionName
        
        super.init()
        
        if !(self is MetalImageFilter) && !(self is MetalGeneratorFilter)
        {
            fatalError("MetalFilters must subclass either MetalImageFilter or MetalGeneratorFilter")
        }
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    func textureInvalid() -> Bool
    {
        fatalError("textureInvalid() not implemented in MetalFilter")
    }
    
    func imageFromComputeShader(width: CGFloat, height: CGFloat, inputImage: CIImage?) -> CIImage
    {
        if textureDescriptor == nil
        {
            textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                width: Int(width),
                height: Int(height),
                mipmapped: false)
            
            kernelInputTexture = device.makeTexture(descriptor: textureDescriptor!)
            kernelOutputTexture = device.makeTexture(descriptor: textureDescriptor!)
            
            threadgroupsPerGrid = MTLSizeMake(
                textureDescriptor!.width / threadsPerThreadgroup.width,
                textureDescriptor!.height / threadsPerThreadgroup.height, 1)
        }
        
        if clearOnStep
        {
            kernelOutputTexture = device.makeTexture(descriptor: textureDescriptor!)
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        if let imageFilter = self as? MetalImageFilter,
            let inputImage = imageFilter.inputImage
        {
            ciContext.render(inputImage,
                to: kernelInputTexture!,
                commandBuffer: commandBuffer,
                bounds: inputImage.extent,
                colorSpace: colorSpace)
        }
        
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipelineState)
        
        // populate float buffers using kCIAttributeIdentity as buffer index
        for inputKey in inputKeys where (attributes[inputKey] as? NSDictionary)?[kCIAttributeClass] as? String == "NSNumber"
        {
            if let bufferIndex = (attributes[inputKey] as! [String:AnyObject])[kCIAttributeIdentity] as? Int,
                var bufferValue = value(forKey: inputKey) as? Float
            {
                let buffer = device.makeBuffer(bytes: &bufferValue,
                    length: MemoryLayout<Float>.size,
                    options: MTLResourceOptions())
                
                commandEncoder.setBuffer(buffer, offset: 0, index: bufferIndex)
            }
        }
        
        // populate color buffers using kCIAttributeIdentity as buffer index
        for inputKey in inputKeys where (attributes[inputKey] as? NSDictionary)?[kCIAttributeClass] as? String == "CIColor"
        {
            if let bufferIndex = (attributes[inputKey] as! [String:AnyObject])[kCIAttributeIdentity] as? Int,
                let bufferValue = value(forKey: inputKey) as? CIColor
            {
                var color = float4(Float(bufferValue.red),
                    Float(bufferValue.green),
                    Float(bufferValue.blue),
                    Float(bufferValue.alpha))
                
                let buffer = device.makeBuffer(bytes: &color,
                    length: MemoryLayout<float4>.size,
                    options: MTLResourceOptions())
                
                commandEncoder.setBuffer(buffer, offset: 0, index: bufferIndex)
            }
        }
        
        // add custom buffers
        
        if let indexedBuffers = customBuffers()
        {
            for indexedBuffer in indexedBuffers
            {
                commandEncoder.setBuffer(indexedBuffer.buffer, offset: 0, index: indexedBuffer.index)
            }
        }
        
        if self is MetalImageFilter
        {
            commandEncoder.setTexture(kernelInputTexture, index: 0)
            commandEncoder.setTexture(kernelOutputTexture, index: 1)
        }
        else if self is MetalGeneratorFilter
        {
            commandEncoder.setTexture(kernelOutputTexture, index: 0)
        }
        
        commandEncoder.dispatchThreadgroups(customThreadgroupsPerGrid() ?? threadgroupsPerGrid!,
            threadsPerThreadgroup: customThreadsPerThreadgroup() ?? threadsPerThreadgroup)
        
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        
        return CIImage(mtlTexture: kernelOutputTexture!,
                       options: [.colorSpace: colorSpace])!
    }
}

// MARK: MetalFilter types

class MetalGeneratorFilter: MetalFilter
{
    var inputWidth: CGFloat = 640
    var inputHeight: CGFloat = 640
    
    override func textureInvalid() -> Bool
    {
        if let textureDescriptor = textureDescriptor,
            textureDescriptor.width != Int(inputWidth)  ||
                textureDescriptor.height != Int(inputHeight)
        {
            return true
        }
        
        return false
    }
}

class MetalImageFilter: MetalFilter
{
    var inputImage: CIImage?
    
    override func textureInvalid() -> Bool
    {
        if let textureDescriptor = textureDescriptor,
            let inputImage = inputImage,
            textureDescriptor.width != Int(inputImage.extent.width)  ||
                textureDescriptor.height != Int(inputImage.extent.height)
        {
            return true
        }
        
        return false
    }
}

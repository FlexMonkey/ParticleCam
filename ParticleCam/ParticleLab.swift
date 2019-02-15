//
//  ParticleLab.swift
//  MetalParticles
//
//  Created by Simon Gladman on 04/04/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.

//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>

import Metal
import MetalKit
import GameplayKit
import MetalPerformanceShaders

class ParticleCamFilter: MetalImageFilter
{
    let particleCount = ParticleCount.oneMillion.rawValue
    let alignment:Int = 0x4000
    let particlesMemoryByteSize:Int
    
    var particlesMemory:UnsafeMutableRawPointer? = nil
    let particlesVoidPtr: OpaquePointer
    let particlesParticlePtr: UnsafeMutablePointer<Particle>
    let particlesParticleBufferPtr: UnsafeMutableBufferPointer<Particle>
    
    lazy var particlesBufferNoCopy: MTLBuffer =
    {
        [unowned self] in
        
        return self.device.makeBuffer(bytesNoCopy: self.particlesMemory!,
            length: Int(self.particlesMemoryByteSize),
            options: MTLResourceOptions(),
            deallocator: nil)!
    }()
    
    let particleSize = MemoryLayout<Particle>.size

    // MARK: Initialisation
    
    init()
    {
        particlesMemoryByteSize = particleCount * MemoryLayout<Particle>.size
        
        posix_memalign(&particlesMemory, alignment, particlesMemoryByteSize)
        
        particlesVoidPtr = OpaquePointer(particlesMemory!)
        particlesParticlePtr = UnsafeMutablePointer<Particle>(particlesVoidPtr)
        particlesParticleBufferPtr = UnsafeMutableBufferPointer(start: particlesParticlePtr, count: particleCount)
        
        func random() -> Float {return Float(drand48() * -1000)}
        
        for index in particlesParticleBufferPtr.startIndex ..< particlesParticleBufferPtr.endIndex
        {
            let particle = Particle(x: random(), y: random(), z: random(), w: random())
            particlesParticleBufferPtr[index] = particle
        }

        super.init(functionName: "particleRendererShader")
    }

    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit
    {
        free(particlesMemory)
    }
    
    // MARK: Custom threadgroup values
    
    override func customThreadgroupsPerGrid() -> MTLSize?
    {
        let threadExecutionWidth = pipelineState.threadExecutionWidth
        
        return MTLSize(width:particleCount / threadExecutionWidth, height:1, depth:1)
    }
    
    override func customThreadsPerThreadgroup() -> MTLSize?
    {
        let threadExecutionWidth = pipelineState.threadExecutionWidth
        
        return MTLSize(width:threadExecutionWidth,height:1,depth:1)
    }
    
    // MARK: Custom buffers
    
    override func customBuffers() -> [(index: Int, buffer: MTLBuffer)]?
    {
        return [
            (index: 0, buffer: particlesBufferNoCopy),
            (index: 1, buffer: particlesBufferNoCopy)
        ]
    }
}


enum ParticleCount: Int
{
    case quarterMillion = 262144
    case halfMillion = 524288
    case oneMillion =  1048576
    case twoMillion =  2097152
    case fourMillion = 4194304
}

// Particles use x and y for position and z and w for velocity
typealias Particle = float4



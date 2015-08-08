//
//  Particles.metal
//  MetalParticles
//
//  Created by Simon Gladman on 17/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  Thanks to: http://memkite.com/blog/2014/12/15/data-parallel-programming-with-metal-and-swift-for-iphoneipad-gpu/
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

#include <metal_stdlib>
using namespace metal;

kernel void particleRendererShader(texture2d<float, access::write> outTexture [[texture(0)]],
                                   // texture2d<float, access::read> inTexture [[texture(1)]],
                                   
                                   const device float4 *inParticles [[ buffer(0) ]],
                                   device float4 *outParticles [[ buffer(1) ]],
               
                                   constant float3 &particleColor [[ buffer(3) ]],
                                   
                                   constant float &imageWidth [[ buffer(4) ]],
                                   constant float &imageHeight [[ buffer(5) ]],
                                   
                                   constant float &dragFactor [[ buffer(6) ]],
                                   
                                   constant bool &respawnOutOfBoundsParticles [[ buffer(7) ]],
                                   
                                   uint id [[thread_position_in_grid]])
{
    const float4 inParticle = inParticles[id];
    
    const float spawnSpeedMultipler = 2.0;
    
    const uint type = id % 3;
    
    const float4 colors[] = {
        float4(particleColor.r, particleColor.g , particleColor.b , 1.0),
        float4(particleColor.b, particleColor.r, particleColor.g, 1.0),
        float4(particleColor.g, particleColor.b, particleColor.r, 1.0)};
    
    const float4 outColor = colors[type];
    
    // ---
    
    const uint2 particlePositionA(inParticle.x, inParticle.y);
    
    if (particlePositionA.x > 0 && particlePositionA.y > 0 && particlePositionA.x < imageWidth && particlePositionA.y < imageHeight)
    {
        outTexture.write(outColor, particlePositionA);
    }
    else if (respawnOutOfBoundsParticles)
    {
        inParticle.z = spawnSpeedMultipler * fast::sin(inParticle.x + inParticle.y);
        inParticle.w = spawnSpeedMultipler * fast::cos(inParticle.x + inParticle.y);
        
        inParticle.x = imageWidth / 2;
        inParticle.y = imageHeight / 2;
    }
    


    outParticles[id] = {
        inParticle.x + inParticle.z,
        inParticle.y + inParticle.w,
        inParticle.z * dragFactor,
        inParticle.w * dragFactor
    };

    
}
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

float rand(int x, int y, int z);

// Generate a random float in the range [0.0f, 1.0f] using x, y, and z (based on the xor128 algorithm)
float rand(int x, int y, int z)
{
    int seed = x + y * 57 + z * 241;
    seed= (seed<< 13) ^ seed;
    return (( 1.0 - ( (seed * (seed * seed * 15731 + 789221) + 1376312589) & 2147483647) / 1073741824.0f) + 1.0f) / 2.0f;
}

kernel void particleRendererShader(
           texture2d<float, access::read> inTexture [[texture(0)]],
           texture2d<float, access::write> outTexture [[texture(1)]],
           
           const device float4 *inParticles [[ buffer(0) ]],
           device float4 *outParticles [[ buffer(1) ]],

           uint id [[thread_position_in_grid]])
{
    const float4 inParticle = inParticles[id];
    const uint2 particleCoord(inParticle.x, inParticle.y);

    // render particles and keep in bounds
    
    float imageWidth = outTexture.get_width();
    float imageHeight = outTexture.get_height();
    
    if (particleCoord.x > 1 && particleCoord.y > 1 &&
        particleCoord.x < imageWidth - 1 &&
        particleCoord.y < imageHeight - 1)
    {
        outTexture.write(float4(1.0), particleCoord);
    }
    else
    {
        inParticle.z = rand(inParticle.w, inParticle.x,
            inParticle.y) * 2.0 - 1.0;
        inParticle.w = rand(inParticle.z, inParticle.y,
            inParticle.x) * 2.0 - 1.0;
        
        inParticle.x = rand(inParticle.x, inParticle.y,
            inParticle.z) * imageWidth;
        inParticle.y = rand(inParticle.y,
            inParticle.x, inParticle.w) * imageHeight;
    }
    
    // ----
    
    const uint2 northCoord(particleCoord.x, particleCoord.y - 1);
    const uint2 southCoord(particleCoord.x, particleCoord.y + 1);
    const uint2 westCoord(particleCoord.x - 1, particleCoord.y);
    const uint2 eastCoord(particleCoord.x + 1, particleCoord.y);
    
    const float3 thisPixel = 1 - inTexture.read(particleCoord).rgb;
    const float3 northPixel = 1 - inTexture.read(northCoord).rgb;
    const float3 southPixel = 1 - inTexture.read(southCoord).rgb;
    const float3 westPixel = 1 - inTexture.read(westCoord).rgb;
    const float3 eastPixel = 1 - inTexture.read(eastCoord).rgb;

    const float3 lumaCoefficients = float3(0.2126, 0.7152, 0.0722);
    
    const float thisLuma = dot(thisPixel, lumaCoefficients);
    const float northLuma = dot(northPixel, lumaCoefficients);
    const float southLuma = dot(southPixel, lumaCoefficients);
    const float eastLuma = dot(eastPixel, lumaCoefficients);
    const float westLuma = dot(westPixel, lumaCoefficients);
    
    const float horizontalModifier = (westLuma + eastLuma);
    const float verticalModifier = (northLuma + southLuma) ;

    float newZ = inParticle.z * (1 + horizontalModifier);
    float newW = inParticle.w * (1 + verticalModifier);

    const float speedLimit = 2.5;
    
    float speedSquared = newZ * newZ + newW * newW;
    
    if (speedSquared > speedLimit)
    {
        float scale = speedLimit / sqrt(speedSquared);
        
        newZ = newZ * scale;
        newW = newW * scale;
    }
    
    outParticles[id] = {
        inParticle.x + inParticle.z * thisLuma,
        inParticle.y + inParticle.w * thisLuma,
        newZ,
        newW
    };
}
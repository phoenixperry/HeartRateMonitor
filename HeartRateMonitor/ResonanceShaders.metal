//#include <metal_stdlib>
//using namespace metal;
//
//// Vertex shader input
//struct VertexIn {
//    float3 position [[attribute(0)]];
//    float2 texCoord [[attribute(1)]];
//};
//
//// Vertex shader output / Fragment shader input
//struct VertexOut {
//    float4 position [[position]];
//    float2 texCoord;
//};
//
//// Uniforms
//struct Uniforms {
//    float time;
//    float heartRates[3];
//    float pulseTimers[3];
//    float syncLevel;
//};
//
//// MARK: - Vertex Shader
//vertex VertexOut resonanceVertex(uint vertexID [[vertex_id]],
//                                constant float *vertices [[buffer(0)]],
//                                constant Uniforms &uniforms [[buffer(1)]]) {
//    VertexOut out;
//    
//    // Extract position and texture coordinates from interleaved array
//    float3 position;
//    float2 texCoord;
//    
//    position.x = vertices[vertexID * 5 + 0];
//    position.y = vertices[vertexID * 5 + 1];
//    position.z = vertices[vertexID * 5 + 2];
//    texCoord.x = vertices[vertexID * 5 + 3];
//    texCoord.y = vertices[vertexID * 5 + 4];
//    
//    out.position = float4(position, 1.0);
//    out.texCoord = texCoord;
//    
//    return out;
//}
//
//// Particle system
//float4 renderParticles(float2 uv, float time, float syncLevel, float3 targetColor) {
//    float4 particleColor = float4(0.0);
//    
//    // Number of particles based on synchronization
//    int particleCount = int(20.0 + syncLevel * 100.0);
//    
//    for (int i = 0; i < particleCount; i++) {
//        // Use hash function for pseudo-random values
//        float i_f = float(i);
//        float random1 = fract(sin(i_f * 78.233) * 43758.5453);
//        float random2 = fract(sin(i_f * 12.9898) * 43758.5453);
//        float random3 = fract(sin(i_f * 39.346) * 43758.5453);
//        
//        // Particle position (flowing in a circular pattern)
//        float angle = time * (0.1 + random1 * 0.2) + i_f * 0.2;
//        float radius = 0.5 + random2 * 0.5;
//        float2 particlePos = float2(cos(angle), sin(angle)) * radius;
//        
//        // Particle size and intensity
//        float size = 0.003 + random3 * 0.007;
//        float dist = length(uv - particlePos);
//        
//        if (dist < size) {
//            // Particle intensity decreases with distance from center
//            float intensity = (1.0 - dist/size) * 0.5;
//            
//            // Particle color based on sync level
//            float3 color = mix(float3(0.5, 0.7, 1.0), targetColor, syncLevel);
//            
//            // Add to existing particles
//            particleColor = mix(particleColor, float4(color, 1.0), intensity);
//        }
//    }
//    
//    return particleColor;
//}
//
//// MARK: - Fragment Shader
//fragment float4 resonanceFragment(VertexOut in [[stage_in]],
//                                 constant Uniforms &uniforms [[buffer(0)]]) {
//    float2 uv = in.texCoord;
//    uv = uv * 2.0 - 1.0;  // Center at (0,0) and range from -1 to 1
//    
//    // Define positions for our three spheres in a triangle
//    float2 positions[3];
//    positions[0] = float2(0.0, 0.6);       // Top center
//    positions[1] = float2(-0.6, -0.3);     // Bottom left
//    positions[2] = float2(0.6, -0.3);      // Bottom right
//    
//    // Colors for each sphere - will shift toward common color with sync
//    float3 baseColors[3];
//    baseColors[0] = float3(0.9, 0.2, 0.3);  // Red-ish
//    baseColors[1] = float3(0.3, 0.7, 0.9);  // Blue-ish
//    baseColors[2] = float3(0.9, 0.8, 0.2);  // Yellow-ish
//    
//    // Shared target color for high synchronization
//    float3 targetColor = float3(0.9, 0.4, 0.7);  // Purple-ish
//    
//    // Final fragment color
//    float4 finalColor = float4(0.05, 0.05, 0.1, 1.0);  // Background color
//    
//    // For each sphere
//    for (int i = 0; i < 3; i++) {
//        // Calculate distance from this pixel to the sphere center
//        float2 spherePos = positions[i];
//        float dist = length(uv - spherePos);
//        
//        // Calculate pulse based on heart rate
//        float pulseTime = uniforms.time - uniforms.pulseTimers[i];
//        float pulsePeriod = 60.0 / uniforms.heartRates[i];
//        float pulsePhase = fmod(pulseTime, pulsePeriod) / pulsePeriod;
//        
//        // Pulse size modulation
//        float baseSize = 0.2;
//        float pulseSize = baseSize * (1.0 + 0.2 * sin(pulsePhase * 2.0 * M_PI_F));
//        
//        // Main sphere
//        if (dist < pulseSize) {
//            // Blend color based on sync level
//            float3 sphereColor = mix(baseColors[i], targetColor, uniforms.syncLevel);
//            
//            // 3D lighting effect
//            float3 normal = normalize(float3(uv - spherePos, sqrt(max(0.0, pulseSize*pulseSize - dist*dist))));
//            float3 lightDir = normalize(float3(0.5, 0.5, 1.0));
//            float diffuse = max(0.0, dot(normal, lightDir));
//            float ambient = 0.2;
//            
//            float3 colorWithLighting = sphereColor * (diffuse + ambient);
//            
//            // Apply depth shading
//            float depthFactor = normal.z * 0.5 + 0.5;
//            colorWithLighting *= depthFactor;
//            
//            finalColor = float4(colorWithLighting, 1.0);
//        }
//        
//        // Ripple effects - triggered on heartbeats
//        float timeSinceLastPulse = uniforms.time - uniforms.pulseTimers[i];
//        if (timeSinceLastPulse < 2.0) {  // Ripple lasts 2 seconds
//            float rippleSize = baseSize + timeSinceLastPulse * 0.3;  // Grows outward
//            float rippleWidth = 0.02;
//            
//            if (abs(dist - rippleSize) < rippleWidth) {
//                float rippleIntensity = (1.0 - timeSinceLastPulse / 2.0) * 0.5;  // Fades over time
//                
//                // Blend color based on sync level
//                float3 rippleColor = mix(baseColors[i], targetColor, uniforms.syncLevel);
//                
//                // Add ripple color to the final color
//                finalColor = float4(mix(finalColor.rgb, rippleColor, rippleIntensity), 1.0);
//            }
//        }
//        
//        // Synchronization connections between spheres
//        if (uniforms.syncLevel > 0.3) {
//            for (int j = i + 1; j < 3; j++) {
//                float2 otherPos = positions[j];
//                float2 midpoint = (spherePos + otherPos) * 0.5;
//                float2 direction = normalize(otherPos - spherePos);
//                float2 perpendicular = float2(-direction.y, direction.x);
//                
//                float distToLine = abs(dot(uv - spherePos, perpendicular));
//                float projOnLine = dot(uv - spherePos, direction);
//                float lineLength = length(otherPos - spherePos);
//                
//                if (distToLine < 0.02 && projOnLine > 0 && projOnLine < lineLength) {
//                    float syncIntensity = uniforms.syncLevel * 0.5;
//                    float pulseEffect = sin((uniforms.time + projOnLine) * 3.0) * 0.5 + 0.5;
//                    
//                    // Connection color is a blend based on the two spheres
//                    float3 connectionColor = mix(baseColors[i], baseColors[j], 0.5);
//                    connectionColor = mix(connectionColor, targetColor, uniforms.syncLevel);
//                    
//                    // Strengthen connection when both hearts beat close to each other
//                    float timeBetweenBeats = abs(uniforms.pulseTimers[i] - uniforms.pulseTimers[j]);
//                    float beatSyncFactor = clamp(1.0 - timeBetweenBeats, 0.0, 1.0);
//                    
//                    finalColor = float4(mix(finalColor.rgb, connectionColor, syncIntensity * pulseEffect * beatSyncFactor), 1.0);
//                }
//            }
//        }
//    }
//    
//    // Add particles if sync level is high enough
//    if (uniforms.syncLevel > 0.4) {
//        float4 particles = renderParticles(uv, uniforms.time, uniforms.syncLevel, targetColor);
//        finalColor = mix(finalColor, particles, particles.a * 0.7);
//    }
//    
//    return finalColor;
//}
// Simplified ResonanceShaders.metal
#include <metal_stdlib>
using namespace metal;

// Vertex shader input
struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

// Vertex shader output / Fragment shader input
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Uniforms
// In ResonanceShaders.metal, update the Uniforms struct
struct Uniforms {
    float time;
    float heartRate0;
    float heartRate1;
    float heartRate2;
    float pulseTimer0;
    float pulseTimer1;
    float pulseTimer2;
    float syncLevel;
};

// MARK: - Vertex Shader
vertex VertexOut resonanceVertex(uint vertexID [[vertex_id]],
                                constant float *vertices [[buffer(0)]],
                                constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    
    // Extract position and texture coordinates from interleaved array
    float3 position;
    float2 texCoord;
    
    position.x = vertices[vertexID * 5 + 0];
    position.y = vertices[vertexID * 5 + 1];
    position.z = vertices[vertexID * 5 + 2];
    texCoord.x = vertices[vertexID * 5 + 3];
    texCoord.y = vertices[vertexID * 5 + 4];
    
    out.position = float4(position, 1.0);
    out.texCoord = texCoord;
    
    return out;
}

// MARK: - Fragment Shader
fragment float4 resonanceFragment(VertexOut in [[stage_in]],
                                 constant Uniforms &uniforms [[buffer(0)]]) {
    // Just return a solid color for initial testing
    return float4(0.5, 0.1, 0.3, 1.0);
}

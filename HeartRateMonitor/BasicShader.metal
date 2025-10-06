//
//  BasicShader.metal
//  HeartRateMonitor
//
//  Created by Phoenix Perry on 04/05/2025.
//

//watch this tomorrow: https://www.youtube.com/watch?v=EgzWwgRpUuw&t=558s
//https://thebookofshaders.com/
//gl-transitions.com
//developer.apple.com/metal 
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};
vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
   // The positions array uses what's called "normalized device coordinates(NDC)" where: this is the same across all GPUs and APIs
//    X ranges from -1 (left) to +1 (right)
//    Y ranges from -1 (bottom) to +1 (top)
//typical 3d space w/0,0 in centre
    const float2 positions[] = {
        float2(-1, -1),  // bottom left corner
        float2( 1, -1),  // bottom right corner
        float2(-1,  1),  // top left corner
        float2( 1,  1)   // top right corner
    };
    //texCords match expected pixel image layout of topleft being 0,0
    const float2 texCoords[] = {
        float2(0, 1),  // bottom left
        float2(1, 1),  // bottom right
        float2(0, 0),  // top left
        float2(1, 0)   // top right
    };
    //basically here we say "take theese points in 3D space and show this corresponding points from the texture."
    
    VertexOut out;
    //Creates a new instance of the VertexOut struct that was defined earlier in the shader. This struct has two members: position and texCoord.
    out.position = float4(positions[vertexID], 0, 1);
//    - This is taking the 2D position from our positions array and converting it to a 4D vector (float4):
//
//   The first two components (x,y) come from the positions array
//   The third component (z = 0) indicates no depth (since we're drawing a flat quad)
//   The fourth component (w = 1) is a special value used for perspective calculations (w=1 means no perspective distortion)
    out.texCoord = texCoords[vertexID];
//    - This simply copies the corresponding texture coordinate into the output structure. These coordinates will be interpolated across the triangle and passed to the fragment shader.
//    The vertexID parameter is automatically provided by Metal and represents the index of the current vertex being processed (0, 1, 2, or 3 in this case). This allows us to look up the corresponding position and texture coordinate from our arrays.
    return out;
    //Returns the filled structure to the GPU pipeline.
//    - it transforms input vertex data (in this case, just the vertexID) into output data that's passed to later stages in the graphics pipeline. The GPU handles the interpolation of these values across the triangles formed by these vertices.
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    // Simple purple color

    //float f=
    return float4(0.5, 0.3, 0.8, 1.0);
}

#include <metal_stdlib>
using namespace metal;

/// GPU adaptive threshold kernel.
/// Each thread compares a pixel's luminance against the mean of its local
/// neighbourhood (2*blockRadius+1 square). If below mean+offset → black, else white.
///
/// Performance note: this is the straightforward implementation.
/// For very large blockRadius values, replace the inner loops with a
/// two-pass separable box filter using threadgroup shared memory.
kernel void adaptiveThreshold(
    texture2d<float, access::read>  inTexture  [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant float& blockRadius              [[buffer(0)]],
    constant float& offset                   [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
)
{
    uint width  = inTexture.get_width();
    uint height = inTexture.get_height();

    if (gid.x >= width || gid.y >= height) { return; }

    float4 center = inTexture.read(gid);
    float luminance = dot(center.rgb, float3(0.299f, 0.587f, 0.114f));

    // Compute local mean luminance in the neighbourhood
    float sum = 0.0f;
    int count = 0;
    int r = int(blockRadius);

    for (int dy = -r; dy <= r; dy++) {
        for (int dx = -r; dx <= r; dx++) {
            int2 neighbor = int2(gid) + int2(dx, dy);
            if (neighbor.x >= 0 && neighbor.x < int(width) &&
                neighbor.y >= 0 && neighbor.y < int(height))
            {
                float4 s = inTexture.read(uint2(neighbor));
                sum += dot(s.rgb, float3(0.299f, 0.587f, 0.114f));
                count++;
            }
        }
    }

    float mean = (count > 0) ? (sum / float(count)) : luminance;
    float result = (luminance < mean + offset) ? 0.0f : 1.0f;

    outTexture.write(float4(result, result, result, 1.0f), gid);
}

// OrbShader.metal
// Krasip
// Swirling black-mint-white cloud fill for the recording orb, animated by time and microphone level.

#include <metal_stdlib>
using namespace metal;

static float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float noise(float2 p) {
    float2 cell = floor(p);
    float2 frac = fract(p);
    float2 smoothed = frac * frac * (3.0 - 2.0 * frac);
    float a = hash(cell);
    float b = hash(cell + float2(1.0, 0.0));
    float c = hash(cell + float2(0.0, 1.0));
    float d = hash(cell + float2(1.0, 1.0));
    return mix(mix(a, b, smoothed.x), mix(c, d, smoothed.x), smoothed.y);
}

static float clouds(float2 p) {
    float sum = 0.0;
    float weight = 0.5;
    for (int i = 0; i < 5; i++) {
        sum += weight * noise(p);
        p *= 2.02;
        weight *= 0.5;
    }
    return sum;
}

[[ stitchable ]] half4 orb(float2 position, half4 current, float2 size, float time, float level) {
    float2 uv = position / size;
    float2 centred = uv * 2.0 - 1.0;
    float radius = length(centred);

    // Breathing: the orb swells a little with the voice.
    float swell = 1.0 - 0.06 * level;
    radius *= swell;
    if (radius > 1.0) {
        return half4(0.0h);
    }

    // Two noise fields drifting against each other make the clouds churn.
    float drift = time * 0.08 + level * 0.35;
    float2 warp = float2(clouds(centred * 1.6 + drift),
                         clouds(centred * 1.6 - drift + 4.3));
    float density = clouds(centred * 2.1 + (warp - 0.5) * 1.9 + drift * 0.6);

    // The clouds drive the shading; gravity only tilts it, so no flat split appears.
    float ramp = clamp(density * 1.75 - 0.42 - centred.y * 0.22, 0.0, 1.0);
    ramp = ramp * ramp * (3.0 - 2.0 * ramp);

    const half3 ink = half3(0.039h, 0.047h, 0.051h);
    const half3 mint = half3(0.812h, 1.0h, 0.886h);

    half3 colour = mix(ink, mint, half(ramp));

    // A small bright core where the cloud is thickest, so it reads as lit.
    colour = mix(colour, half3(1.0h), half(pow(ramp, 4.0) * 0.6));

    // Darken towards the edge so the sphere keeps its volume.
    colour *= half(1.0 - 0.45 * smoothstep(0.55, 1.0, radius));

    // Feather the outer edge instead of a hard cut, so it reads as a sphere.
    float alpha = 1.0 - smoothstep(0.94, 1.0, radius);
    return half4(colour * half(alpha), half(alpha));
}

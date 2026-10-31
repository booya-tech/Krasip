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

    // Slow drifting cloud field. The warp keeps the horizon from looking straight.
    float drift = time * 0.05 + level * 0.25;
    float2 warp = float2(clouds(centred * 0.8 + drift),
                         clouds(centred * 0.8 - drift + 4.3));
    float density = clouds(centred * 0.9 + (warp - 0.5) * 0.8 + drift * 0.5);

    // Height through the sky: 0 is the blue floor, 1 is the pale top.
    float height = clamp(0.42 - centred.y * 0.80 + (density - 0.5) * 0.34, 0.0, 1.0);

    const half3 deep = half3(0.161h, 0.447h, 0.957h);
    const half3 cream = half3(0.976h, 0.980h, 0.953h);
    const half3 ice = half3(0.839h, 0.925h, 0.984h);

    // Blue burns off into a warm white band, which cools again towards the top.
    half3 colour = mix(deep, cream, half(smoothstep(0.22, 0.62, height)));
    colour = mix(colour, ice, half(0.85 * smoothstep(0.70, 1.0, height)));

    // Hard round edge, antialiased only. The reference orb has no soft halo.
    float alpha = 1.0 - smoothstep(0.985, 1.0, radius);
    return half4(colour * half(alpha), half(alpha));
}

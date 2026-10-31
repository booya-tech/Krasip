// OrbShader.metal
// Krasip
// Watercolour sky fill for the recording orb: pale cloud on one side, deep blue on the other.

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

static float fbm(float2 p) {
    float sum = 0.0;
    float weight = 0.55;
    for (int i = 0; i < 4; i++) {
        sum += weight * noise(p);
        p *= 2.03;
        weight *= 0.5;
    }
    return sum;
}

[[ stitchable ]] half4 orb(float2 position, half4 current, float2 size, float time, float level) {
    float2 uv = position / size;
    float2 centred = uv * 2.0 - 1.0;
    float radius = length(centred);

    // The orb swells a little with the voice.
    radius *= 1.0 - 0.06 * level;
    if (radius > 1.0) {
        return half4(0.0h);
    }

    // Noise fed through itself twice. The feedback is what turns grain into
    // watercolour wisps; squashing y on the last pass makes them run downwards.
    float drift = time * 0.045 + level * 0.15;
    float2 p = centred * 0.9;
    float2 q = float2(fbm(p + drift),
                      fbm(p + float2(5.2, 1.3) + drift));
    float2 r = float2(fbm(p + 0.8 * q + float2(1.7, 9.2)),
                      fbm(p + 0.8 * q + float2(8.3, 2.8)));
    float f = fbm((p + 0.7 * r) * float2(1.0, 0.35));

    // A diagonal that slowly swings: pale upper left, blue lower right.
    float tilt = 0.50 + 0.18 * sin(time * 0.045);
    float slope = centred.y * 0.865 + centred.x * tilt;
    float height = clamp(0.55 - slope * 1.25 + (f - 0.5) * 0.75, 0.0, 1.0);

    const half3 deep = half3(0.180h, 0.475h, 0.949h);
    const half3 ice = half3(0.804h, 0.902h, 0.980h);
    const half3 paper = half3(0.973h, 0.973h, 0.945h);

    half3 colour = mix(deep, ice, half(smoothstep(0.20, 0.80, height)));
    colour = mix(colour, paper, half(smoothstep(0.86, 1.06, height)));

    // Crisp round edge, antialiased only.
    float alpha = 1.0 - smoothstep(0.985, 1.0, radius);
    return half4(colour * half(alpha), half(alpha));
}

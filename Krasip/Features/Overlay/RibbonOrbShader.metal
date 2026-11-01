// RibbonOrbShader.metal
// Krasip
// Alternative orb fill: glowing blue ribbons curling inside a dark glass ball.

#include <metal_stdlib>
using namespace metal;

static float3 spin(float3 p, float yaw, float pitch) {
    float sy = sin(yaw);
    float cy = cos(yaw);
    float x = cy * p.x + sy * p.z;
    float z = cy * p.z - sy * p.x;
    float sp = sin(pitch);
    float cp = cos(pitch);
    return float3(x, cp * p.y - sp * z, sp * p.y + cp * z);
}

/// Signed distance to one folded sheet. The three waves bend a flat plane into a
/// veil that curls, which is what reads as a ribbon once it is lit.
static float sheet(float3 p, float3 axis, float phase) {
    float d = dot(p, axis);
    d += 0.45 * sin(p.z * 2.0 + phase);
    d += 0.32 * cos(p.y * 1.7 - phase * 0.8);
    d += 0.18 * sin(p.x * 2.6 + phase * 1.3);
    return d;
}

/// A thin bright crease sitting inside a wide soft wash.
static float veil(float d) {
    float core = 0.0020 / (0.0020 + d * d);
    float wash = 0.1100 / (0.1100 + d * d);
    return core + 0.26 * wash;
}

/// Fades a ribbon in and out along its length so it never circles the whole ball.
static float presence(float3 p, float phase) {
    float v = 0.5 + 0.5 * sin(p.x * 1.4 + p.y * 1.1 - p.z * 0.8 + phase);
    return 0.10 + 0.90 * v * v;
}

[[ stitchable ]] half4 ribbonOrb(float2 position, half4 current, float2 size, float time, float level) {
    // The view is wider than the ball so the halo has somewhere to fade out.
    float2 centred = (position / size * 2.0 - 1.0) * 1.25 / (1.0 + 0.07 * level);
    float radius = length(centred);
    if (radius > 1.22) {
        return half4(0.0h);
    }

    float yaw = time * 0.22 + level * 0.3;
    float pitch = 0.28 * sin(time * 0.11);
    float phaseA = time * 0.50;
    float phaseB = time * 0.37 + 2.1;

    float glow = 0.0;
    if (radius < 1.0) {
        float z = sqrt(max(0.0, 1.0 - radius * radius));
        // The near and far side of the ball both show through, which is what makes it glass.
        for (int face = 0; face < 2; face++) {
            float3 p = spin(float3(centred, face == 0 ? z : -z), yaw, pitch);
            glow += veil(sheet(p, float3(0.0, 1.0, 0.0), phaseA)) * presence(p, phaseA * 0.7);
            glow += veil(sheet(p, float3(0.82, 0.35, 0.45), phaseB)) * presence(p, phaseB * 0.7);
        }
    }

    float edge = radius - 1.0;
    float angle = atan2(centred.y, centred.x);
    float rimVariation = 0.40 + 0.60 * (0.5 + 0.5 * sin(angle * 2.0 - time * 0.55)
                                                  * cos(angle * 3.0 + time * 0.31));
    glow += 0.0026 / (0.0026 + edge * edge) * rimVariation * 1.8;

    float fade = 1.0 - smoothstep(1.02, 1.22, radius);
    float tone = (1.0 - exp(-glow * 0.70)) * fade;
    float glass = 0.90 * (1.0 - smoothstep(0.90, 1.005, radius)) * fade;

    const half3 inner = half3(0.043h, 0.047h, 0.145h);
    const half3 ribbon = half3(0.278h, 0.310h, 0.878h);
    const half3 hot = half3(0.776h, 0.820h, 1.000h);

    half3 lit = mix(ribbon, hot, half(tone));
    half3 premultiplied = inner * half(glass) + lit * half(tone * 1.70);
    return half4(premultiplied, half(min(1.0, glass + tone)));
}

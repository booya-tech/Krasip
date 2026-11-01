// ParticleOrbShader.metal
// Krasip
// Third orb fill: a wobbling sphere of glowing dots, brightest where the surface turns edge on.

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

[[ stitchable ]] half4 particleOrb(float2 position, half4 current, float2 size, float time, float level, float rows) {
    float2 centred = (position / size * 2.0 - 1.0) * 1.22 / (1.0 + 0.06 * level);
    float radius = length(centred);
    float angle = atan2(centred.y, centred.x);

    // Waves at four speeds keep the outline lumpy without it settling into a polygon.
    float wobble = 0.026 * sin(angle * 4.0 + time * 0.47)
                 + 0.020 * sin(angle * 7.0 - time * 0.31 + 1.7)
                 + 0.014 * sin(angle * 2.0 + time * 0.23 + 3.1)
                 + 0.010 * sin(angle * 11.0 - time * 0.17 + 5.5);
    float surface = 1.0 + wobble;
    if (radius > surface + 0.16) {
        return half4(0.0h);
    }

    float yaw = time * 0.18 + level * 0.25;
    float pitch = 0.22 * sin(time * 0.09);
    float normalised = radius / surface;

    float glow = 0.0;
    float tint = 0.0;
    if (normalised < 1.0) {
        float z = sqrt(max(0.0, 1.0 - normalised * normalised));
        // The near and far side of the shell both show, so the dots overlap into moire.
        for (int face = 0; face < 2; face++) {
            float3 d = spin(float3(centred / surface, face == 0 ? z : -z), yaw, pitch);
            float latitude = asin(clamp(d.y, -1.0, 1.0));
            float longitude = atan2(d.z, d.x);

            // Rows are evenly spaced and each row holds fewer dots near the poles,
            // which keeps every dot the same size across the whole ball.
            float rowf = (latitude / M_PI_F + 0.5) * rows;
            float rowPhi = ((floor(rowf) + 0.5) / rows - 0.5) * M_PI_F;
            float columns = max(5.0, round(rows * 2.0 * cos(rowPhi)));
            float colf = (longitude / (2.0 * M_PI_F) + 0.5) * columns;

            float2 cell = float2(fract(colf), fract(rowf)) - 0.5;
            float spot = exp(-dot(cell, cell) * 14.0);
            // Near the edge a dot falls below one pixel, so it melts into a solid fringe.
            float sharp = smoothstep(0.0, 0.38, z);
            float lit = 0.20 + 0.80 * spot;
            glow += (lit * sharp + (1.0 - sharp) * 0.70) * min(3.2, 1.0 / max(z, 0.10));
            tint += 0.5 + 0.5 * sin(d.x * 2.3 + d.z * 1.9 + time * 0.33)
                              * cos(d.y * 2.7 - d.x * 1.4 - time * 0.21);
        }
        tint *= 0.5;
    } else {
        glow = 0.55 * exp(-(radius - surface) * 14.0);
    }

    float fade = 1.0 - smoothstep(surface + 0.072, surface + 0.16, radius);
    float tone = (1.0 - exp(-glow * 0.58)) * fade;

    const half3 deep = half3(0.055h, 0.075h, 0.300h);
    const half3 blue = half3(0.145h, 0.330h, 0.930h);
    const half3 violet = half3(0.580h, 0.310h, 0.950h);
    const half3 ice = half3(0.640h, 0.850h, 1.000h);

    float rim = smoothstep(0.55, 1.0, normalised);
    float warm = smoothstep(0.40, 0.95, tint) * 0.95 * (0.40 + 0.60 * rim);

    half3 colour = mix(deep, blue, half(saturate(tone * 1.5)));
    colour = mix(colour, violet, half(warm));
    colour = mix(colour, ice, half(saturate((tone - 0.70) * 2.2)));

    float glass = 0.55 * (1.0 - smoothstep(0.93, 1.01, normalised)) * fade;
    half3 premultiplied = colour * half(tone * 1.20) + deep * half(glass * 0.6);
    return half4(premultiplied, half(min(1.0, glass + tone)));
}

#version 460 core

#include <flutter/runtime_effect.glsl>

// Uniforms: progress (0..1), resolution (width, height)
uniform float uProgress;
uniform vec2 uResolution;

out vec4 fragColor;

// Hash function for procedural noise
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Value noise with smooth interpolation
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;

    // Multi-octave noise for organic dissolve pattern
    float n = 0.0;
    n += noise(uv * 6.0) * 0.6;
    n += noise(uv * 13.0) * 0.25;
    n += noise(uv * 26.0) * 0.15;

    // progress goes 0 -> 1 meaning "fully opaque" -> "fully dissolved"
    // Pixels with noise < progress get dissolved (alpha -> 0)
    float dissolveEdge = smoothstep(uProgress - 0.08, uProgress, n);

    // Glow band: a narrow strip just ahead of the dissolve front
    float glowBand = smoothstep(uProgress - 0.18, uProgress - 0.06, n)
                   * (1.0 - dissolveEdge);

    // Amber/gold glow colour matching the app primary
    vec3 glowColor = vec3(0.831, 0.659, 0.325); // #D4A853

    // Output: the glow colour where the edge is burning, transparent elsewhere
    // The widget behind this painter will show the outgoing scene image;
    // this shader is composited on top and also controls the layer alpha.
    float alpha = dissolveEdge + glowBand * 0.6;
    vec3 color = glowColor * glowBand * 0.9;

    fragColor = vec4(color, alpha);
}

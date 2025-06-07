#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 iResolution;
uniform float iTime;
uniform float iAlpha;;

out vec4 fragColor;

// 'Warp Speed' by David Hoskins 2013.
// I tried to find gaps and variation in the star cloud for a feeling of structure.
// Inspired by Kali: https://www.shadertoy.com/view/ltl3WS
//
// https://www.shadertoy.com/view/Msl3WH

const int iterations = 50;

void main() {

    vec2 fragCoord = FlutterFragCoord().xy;
    float time = (iTime+29.) * 60.0 * 8.0;

    float s = 0.0, v = 0.0;
    vec2 uv = (-iResolution.xy + 2.0 * fragCoord) / iResolution.y;
    float t = time*0.005;
    //	uv.x += sin(t) * .3;
    float si = sin(t*0.1);// ...Squiffy rotation matrix!
    float co = cos(t);
    uv *= mat2(co, si, -si, co);
    vec3 col = vec3(0.0);
    vec3 init = vec3(0.25, 0.25 + sin(time * 0.001) * .1, time * 0.0008);
    for (int r = 0; r < iterations; r++)
    {
        vec3 p = init + s * vec3(uv, 0.143);
        p.z = mod(p.z, 2.0);
        for (int i=0; i < 10; i++)    p = abs(p * 2.04) / dot(p, p) - 0.75;
        v += length(p * p) * smoothstep(0.0, 0.5, 0.9 - s) * .002;
        // Get a purple and cyan effect by biasing the RGB in different ways...
        col +=  vec3(v * 0.8, 1.1 - s * 0.5, .7 + v * 0.5) * v * 0.013;
        s += .01;
    }
    fragColor = vec4(col, iAlpha);
    fragColor.x *= iAlpha * iAlpha;
    fragColor.y *= iAlpha;
    fragColor.z *= iAlpha;
}

// liquid_shell: liquid glass lens. Clean-room (spec 2026-10-10 §4).
//
// A slab of glass whose top surface curves down across a bezel band at the
// edge. A straight-down view ray refracts (Snell, index n) and lands on the
// backdrop displaced inward, so content near the edge is magnified. All
// lengths are physical pixels of the render pass; y points down.
#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;    // 0-1: pass size, set by the engine
uniform vec4 uRect;    // 2-5: left, top, width, height
uniform vec4 uRadii;   // 6-9: tl, tr, br, bl
uniform vec4 uOptics;  // 10-13: bezel, thickness, index, dispersion
uniform vec4 uTint;    // 14-17: rgba, straight alpha
uniform vec4 uRim;     // 18-21: rgba
uniform vec4 uLight;   // 22-25: light x, light y, rim width, saturation

uniform sampler2D uBackdrop;

out vec4 fragColor;

// Signed distance to the rounded rect (negative inside) and the outward
// unit normal of the nearest edge.
float roundedBox(vec2 p, out vec2 normal) {
  vec2 half_size = uRect.zw * 0.5;
  vec2 rel = p - (uRect.xy + half_size);
  float r = rel.x < 0.0 ? (rel.y < 0.0 ? uRadii.x : uRadii.w)
                        : (rel.y < 0.0 ? uRadii.y : uRadii.z);
  vec2 q = abs(rel) - half_size + vec2(r);
  vec2 side = vec2(rel.x < 0.0 ? -1.0 : 1.0, rel.y < 0.0 ? -1.0 : 1.0);
  if (q.x > 0.0 && q.y > 0.0) {
    normal = normalize(q) * side;
  } else if (q.x > q.y) {
    normal = vec2(side.x, 0.0);
  } else {
    normal = vec2(0.0, side.y);
  }
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

// Height of the bezel at x in [0, 1] (0 at the edge) and its slope.
float bezelHeight(float x) {
  float u = 1.0 - x;
  return pow(max(1.0 - u * u * u * u, 0.0), 0.25);
}

float bezelSlope(float x) {
  float xc = max(x, 0.02);
  float u = 1.0 - xc;
  float inner = max(1.0 - u * u * u * u, 1e-4);
  return u * u * u * pow(inner, -0.75);
}

// Inward displacement of the backdrop sample for refractive index n.
vec2 displacement(vec2 n2, float x, float n) {
  float bezel = uOptics.x;
  float thickness = uOptics.y;
  float slope = min(thickness / bezel * bezelSlope(x), 8.0);
  vec3 normal = normalize(vec3(n2 * slope, 1.0));
  vec3 ray = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / n);
  float depth = thickness * bezelHeight(x);
  return ray.xy * depth / max(-ray.z, 0.2);
}

vec3 sampleBackdrop(vec2 p) {
  vec2 uv = clamp(p / uSize, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uBackdrop, uv).rgb;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 n2;
  float d = roundedBox(p, n2);
  float t = max(-d, 0.0);
  float x = clamp(t / uOptics.x, 0.0, 1.0);

  vec3 color;
  if (x < 1.0 && uOptics.y > 0.0) {
    float n = uOptics.z;
    float spread = 0.1 * uOptics.w;
    if (spread > 0.0) {
      color = vec3(
          sampleBackdrop(p + displacement(n2, x, n - spread)).r,
          sampleBackdrop(p + displacement(n2, x, n)).g,
          sampleBackdrop(p + displacement(n2, x, n + spread)).b);
    } else {
      color = sampleBackdrop(p + displacement(n2, x, n));
    }
  } else {
    color = sampleBackdrop(p);
  }

  color = mix(color, uTint.rgb, uTint.a);
  float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color = mix(vec3(luma), color, uLight.w);

  vec2 light = normalize(uLight.xy);
  float facing = dot(n2, light);
  float rim = 1.0 - smoothstep(0.0, uLight.z, t);
  float spec = rim * (max(facing, 0.0) + 0.4 * max(-facing, 0.0));
  float glow = 0.25 * (1.0 - bezelHeight(x));
  color += uRim.rgb * uRim.a * (spec + glow);

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}

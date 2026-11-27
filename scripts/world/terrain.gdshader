shader_type spatial;
// Terrain splat: low ground / dirt patches / rock on slopes / optional snow above a height.

uniform sampler2D alb_low : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm_low : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rgh_low : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform sampler2D alb_mid : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm_mid : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rgh_mid : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform sampler2D alb_rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm_rock : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rgh_rock : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform sampler2D alb_high : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm_high : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float snow_line = 999.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float scale_low = 0.22;
uniform float scale_rock = 0.09;
uniform vec4 patch_a : source_color = vec4(0.55, 0.62, 0.35, 1.0);
uniform vec4 patch_b : source_color = vec4(0.28, 0.33, 0.20, 1.0);

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = wpos.xz * scale_low;
	// break up tiling with a second, rotated sample
	vec2 uv2 = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * wpos.xz * scale_low * 0.43;
	float big = vnoise(wpos.xz * 0.035) * 0.65 + vnoise(wpos.xz * 0.11) * 0.35;
	vec3 low = mix(texture(alb_low, uv).rgb, texture(alb_low, uv2).rgb, 0.4);
	vec3 mid = mix(texture(alb_mid, uv).rgb, texture(alb_mid, uv2).rgb, 0.4);
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float m_mid = smoothstep(0.45, 0.62, big);
	float m_rock = smoothstep(0.22, 0.38, slope);
	float m_high = smoothstep(snow_line - 4.0, snow_line + 4.0, wpos.y + (big - 0.5) * 6.0) * (1.0 - smoothstep(0.35, 0.55, slope));
	// triplanar-ish rock (xz + side projection) so cliffs don't stretch
	vec3 an = abs(wnrm);
	vec3 rock = texture(alb_rock, wpos.xz * scale_rock).rgb * an.y + texture(alb_rock, wpos.zy * scale_rock).rgb * an.x + texture(alb_rock, wpos.xy * scale_rock).rgb * an.z;
	rock /= max(an.x + an.y + an.z, 0.001);
	vec3 col = mix(low, mid, m_mid);
	col = mix(col, rock, m_rock);
	col = mix(col, texture(alb_high, uv).rgb, m_high);
	col *= mix(0.85, 1.1, big);
	// landscape-scale colour patches: fields, forest floor, dry ground (what you see from the air)
	float pn = vnoise(wpos.xz * 0.006) * 0.6 + vnoise(wpos.xz * 0.019) * 0.4;
	vec3 patch_col = mix(patch_b.rgb, patch_a.rgb, smoothstep(0.3, 0.7, pn));
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float far_k = smoothstep(60.0, 420.0, dist) * (1.0 - m_rock * 0.6) * (1.0 - m_high);
	vec3 macro = col * mix(vec3(1.0), patch_col / max(dot(patch_col, vec3(0.333)), 0.05) * 0.45, 0.55);
	col = mix(col, mix(macro, patch_col, 0.45), far_k);
	ALBEDO = col * tint.rgb;
	vec3 n_low = mix(texture(nrm_low, uv).rgb, texture(nrm_mid, uv).rgb, m_mid);
	vec3 n = mix(n_low, texture(nrm_rock, wpos.xz * scale_rock).rgb, m_rock);
	n = mix(n, texture(nrm_high, uv).rgb, m_high);
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.2;
	float r_low = mix(texture(rgh_low, uv).g, texture(rgh_mid, uv).g, m_mid);
	ROUGHNESS = mix(mix(r_low, texture(rgh_rock, wpos.xz * scale_rock).g, m_rock), 0.6, m_high);
	SPECULAR = 0.3;
}

#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
};

void main()
{
    vec2 uv = qt_TexCoord0;
    float aspect = resolution.x / max(resolution.y, 1.0);
    vec2 p = (uv - 0.5) * vec2(aspect, 1.0);

    vec2 cyanPoint = vec2(-0.30 + 0.10 * sin(time * 0.16), -0.26 + 0.08 * cos(time * 0.19));
    vec2 amberPoint = vec2(0.38 + 0.08 * cos(time * 0.13), 0.28 + 0.07 * sin(time * 0.17));
    float cyan = exp(-dot(p - cyanPoint, p - cyanPoint) * 8.5);
    float amber = exp(-dot(p - amberPoint, p - amberPoint) * 11.0);
    float wash = 0.5 + 0.5 * sin(time * 0.08 + p.x * 2.0 + p.y);

    vec3 color = vec3(0.012, 0.025, 0.039);
    color += vec3(0.018, 0.14, 0.16) * cyan;
    color += vec3(0.12, 0.065, 0.027) * amber;
    color += vec3(0.006, 0.013, 0.02) * wash;
    fragColor = vec4(color, 0.90) * qt_Opacity;
}

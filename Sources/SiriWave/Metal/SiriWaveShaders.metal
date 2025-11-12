#include <metal_stdlib>
using namespace metal;

struct SampleVertex {
    float2 values;
};

struct CurveParameters {
    float amplitude;
    float phase;
    float offset;
    float width;
    float verse;
    float padding;
    float index;
    float total;
};

struct WaveUniforms {
    float height;
    float direction;
    float currentAmplitude;
    float graphX;
    float attenuationFactor;
    float amplitudeFactor;
    uint sampleCount;
    uint curveCount;
    float4 color;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

static inline float globalAttenuation(float x, float attenuationFactor) {
    float denominator = attenuationFactor + (x * x);
    return pow(attenuationFactor / max(denominator, 0.0001f), attenuationFactor);
}

vertex VertexOut siriWaveVertex(
    const device SampleVertex *vertices [[buffer(0)]],
    constant WaveUniforms &uniforms [[buffer(1)]],
    constant CurveParameters *curveParams [[buffer(2)]],
    uint vid [[vertex_id]]
) {
    VertexOut out;
    SampleVertex sampleVertex = vertices[vid];

    float sampleIndex = sampleVertex.values.x;
    float vertexKind = sampleVertex.values.y; // 0 baseline, 1 wave point

    float sampleCount = max(float(uniforms.sampleCount), 1.0f);
    float lerpFactor = (sampleCount <= 1.0f) ? 0.0f : (sampleIndex / (sampleCount - 1.0f));

    float xValue = mix(-uniforms.graphX, uniforms.graphX, lerpFactor);
    float xNormalized = (xValue / uniforms.graphX) * 2.0f;

    float combinedY = 0.0;
    if (uniforms.curveCount > 0 && curveParams != nullptr) {
        for (uint i = 0; i < uniforms.curveCount; ++i) {
            CurveParameters params = curveParams[i];
            float totalCurves = max(params.total, 1.0f);
            float curveIndex = params.index;

            float distribution = 0.0f;
            if (totalCurves > 1.0f) {
                distribution = 4.0f * (-1.0f + (curveIndex / (totalCurves - 1.0f)) * 2.0f);
            }

            distribution += params.offset;
            float k = 1.0f / max(params.width, 0.0001f);
            float localX = xValue * k - distribution;
            float attenuation = globalAttenuation(localX, uniforms.attenuationFactor);
            float value = fabs(params.amplitude * sin(params.verse * localX - params.phase) * attenuation);
            combinedY += value;
        }
        combinedY /= max(float(uniforms.curveCount), 1.0f);
    }

    float globalAtt = globalAttenuation(xNormalized, uniforms.attenuationFactor);
    float yValue = uniforms.amplitudeFactor * uniforms.height *
                   uniforms.currentAmplitude * combinedY * globalAtt;

    float finalY = (vertexKind > 0.5f) ? uniforms.direction * yValue : 0.0f;
    float ndcY = (uniforms.height > 0.0f) ? finalY / uniforms.height : 0.0f;
    float ndcX = mix(-1.0f, 1.0f, lerpFactor);

    out.position = float4(ndcX, ndcY, 0.0, 1.0);
    out.color = uniforms.color;
    return out;
}

fragment float4 siriWaveFragment(VertexOut in [[stage_in]]) {
    return in.color;
}

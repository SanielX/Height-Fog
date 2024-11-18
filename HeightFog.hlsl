#pragma once

#ifndef INV_FOUR_PI
    #define INV_FOUR_PI 0.07957747154594766788
#endif

CBUFFER_START(FogVolume_ConstantBuffer)

float4x4 FogVolume_InverseVPMatrix;

float4 FogVolume_SunDirection;
float4 FogVolume_SunColor;
float4 FogVolume_Emissive;
float4 FogVolume_SkyParams;
float4 FogVolume_SmoothDepthParams; // x - 1 / (smoothInterval), y - pow(1./s, 2), z-0.5*pow(1./s,3), w - h0

float2 FogVolume_Distances;
   
float2 FogVolume_GlobalFogPhaseW;
float2 FogVolume_HeightExponents;
float  FogVolume_Extinction;
float  FogVolume_BaseHeight;
   
float  FogVolume_GlobalFogPhase;
float  FogVolume_AmbientStrength;

CBUFFER_END
#define FogVolume_H0 (FogVolume_SmoothDepthParams.w)
#define FogVolume_SmoothIntervalRcp (FogVolume_SmoothDepthParams.x)

float HG_Phase(float g, float theta)
{
    float hg = (1-g*g) / pow(abs(1+g*g - 2*g*theta), 2./3.);
    return INV_FOUR_PI * hg;
}

float RDR_Phase_M2(float g, float theta, float sigma_ext, float w0, float w1)
{
    float hg = HG_Phase(g, theta) * w0;

    const float M = 2;
    float c = (w1 * sigma_ext) / (M - 1);

    float c0 = HG_Phase(pow(2/3, 1)*g, theta);
    float c1 = HG_Phase(pow(2/3, 2)*g, theta);

    float hg2 = c * (c0+c1);

    return hg + hg2;
}

float3 FogVolume_SampleGlobalLightingScattering(float3 viewDirection, float extinction)
{   
    float  theta = dot(FogVolume_SunDirection.xyz, viewDirection.xyz);
    float  g     = FogVolume_GlobalFogPhase;
    float  phase = RDR_Phase_M2(g, theta, extinction, FogVolume_GlobalFogPhaseW.x, FogVolume_GlobalFogPhaseW.y);
    float3 light = FogVolume_SunColor.rgb;
    
    float3 scatteredLight = lerp(FogVolume_Emissive.rgb, light, saturate(phase * FogVolume_SunDirection.w));

    return scatteredLight;
}

// From com.unity.srp-core Volumetrics
float OpticalDepthHeightFog(float baseExtinction, float baseHeight, float2 heightExponents,
                           float cosZenith, float startHeight, float intervalLength)
{
    // Height fog is composed of two slices of optical depth:
    // - homogeneous fog below 'baseHeight': d = k * t
    // - exponential fog above 'baseHeight': d = Integrate[k * e^(-(h + z * x) / H) dx, {x, 0, t}]

    float H          = heightExponents.y;
    float rcpH       = heightExponents.x;
    float Z          = cosZenith;
    float absZ       = max(abs(cosZenith), 0.001f);
    float rcpAbsZ    = rcp(absZ);

    float endHeight  = startHeight + intervalLength * Z;
    float minHeight  = min(startHeight, endHeight);
    float h          = max(minHeight - baseHeight, 0);

    float homFogDist = clamp((baseHeight - minHeight) * rcpAbsZ, 0, intervalLength);
    float expFogDist = intervalLength - homFogDist;
    float expFogMult = exp(-h * rcpH) * (1 - exp(-expFogDist * absZ * rcpH)) * (rcpAbsZ * H);

    return baseExtinction * (homFogDist + expFogMult);
}

void FogVolume_ComputeAnalyticalUniformFog(float3 origin, float3 viewDirection, float segmentLength, 
                                           out float3 outScattering, out float outTransmittance)
{
    float3 albedo     = FogVolume_Extinction.xxx; // FogVolume_FogAlbedoExtinction.rgb;
    float  extinction = FogVolume_Extinction.x;   // FogVolume_FogAlbedoExtinction.a;

    // FogVolume_Distances.x - min distance, FogVolume_Distances.y - transition interval length
    float s = FogVolume_Distances.y;
    float smoothOpticalDepth;
    if(segmentLength < FogVolume_Distances.x)
    {
        smoothOpticalDepth = 0;
    }
    else if(segmentLength < (FogVolume_Distances.x+s))
    {
        float x = max(0.0, segmentLength - FogVolume_Distances.x);
        // Integral over scaled smoothstep function
        smoothOpticalDepth = FogVolume_SmoothDepthParams.y * pow(x, 3) - FogVolume_SmoothDepthParams.z*pow(x, 4);
    }
    else
    {
        float x = max(0.0, segmentLength - FogVolume_Distances.x);
        float h0 = FogVolume_H0; // pow(1/s, 2) * pow(s, 3) - 0.5*pow(1/s,3)*pow(s, 4); 
        
        smoothOpticalDepth = (x-s)+h0;
    }
    smoothOpticalDepth *= extinction;
                        
    float3 fogColor   = FogVolume_SampleGlobalLightingScattering(viewDirection, extinction);
    float3 scattering = fogColor * albedo;

    // Takes care of base extinction too
    float heightOpticalDepth = OpticalDepthHeightFog(extinction, FogVolume_BaseHeight, FogVolume_HeightExponents, viewDirection.y, origin.y, segmentLength);

    // This part is technically nonsense because height fog part already takes depth into account, so distance is basically squared here
    float  transmittance        = exp(-smoothOpticalDepth * heightOpticalDepth);
    float3 scatteringIntegrated = (scattering - scattering * transmittance) / max(0.0001, extinction); // From frostbite volumetric fog talk, energy preserving scattering

    outScattering    = scatteringIntegrated; // scattering * (1-transmittance);
    outTransmittance = transmittance;
}

float4 FogVolume_Apply(float3 worldPosition, float4 color)
{
    if(FogVolume_Extinction.x <= 0) // Unity will 0-init by default, so if cbuffer isn't bound, fog is not enabled
        return color;
    
    // view -> vector from camera to pixel world-space position
    float3 view = worldPosition - _WorldSpaceCameraPos;
    float  viewLength = length(view); // distance from camera to pixel
    view /= viewLength; // normalize view vector
            
    float3 scattering; float transmittance; // scattering -> fog color, transmittance -> fog opacity
    FogVolume_ComputeAnalyticalUniformFog(_WorldSpaceCameraPos, view, viewLength, scattering, transmittance);
            
    color.rgb = lerp(scattering.rgb * color.a, color.rgb, transmittance);

    return color;
}
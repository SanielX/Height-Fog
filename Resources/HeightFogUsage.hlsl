#ifndef PI
    #define PI 3.14159
#endif

#ifndef FLT_MAX
    #define FLT_MAX 3.402823466e+38
#endif

#include "KejiroNoise.hlsl"

half4 HF_FogColor;

half HF_FogDensity;
half HF_MaxHeight;
half HF_MinHeight;

half HF_DistanceDensity;
half HF_FogDistanceMax;
half HF_FogDistanceMin;

half HF_SkyFill;
half HF_SkyFogDensity;

half HF_WindInfluence;
half3 HF_WindDirection;

half3 HF_DirectionalLightColor;
float3 HF_DirectionalLightVector;
half4 HF_DirectionalLightColorBlend;
half HF_LightFarness;
half HF_LightInfluence;

float LiniarInterpolation(float minValue, float maxValue, float value)
{
    return clamp((value - minValue) / (maxValue-minValue), 0, 1);
}

float exponent(float a)
{
    return 1 / (pow(2, a));
}

float smooth(float x)
{
    return 1.0 - pow(abs(x-1), 1.5);
}

float3 GetDefaultFogColor()
{
    return HF_FogColor.rgb * HF_FogColor.a;
}

float3 ApplyLight(float3 fogColor, float3 wpos){
    
    float3 camToPoint = normalize(wpos - (_WorldSpaceCameraPos - HF_DirectionalLightVector * 100 * HF_LightFarness));

    float d = dot(HF_DirectionalLightVector, camToPoint);
    float lightAmount = 1.0 - smooth(saturate(d));
    lightAmount *= HF_LightInfluence;
    
    float3 lightColor = (HF_DirectionalLightColor * HF_DirectionalLightColorBlend) * HF_DirectionalLightColorBlend.a;

    return lerp(fogColor, lightColor, lightAmount);
}

// Paints color into fog color, if fog disabled - returns original color
float3 ApplyFog(float3 color, float3 wpos)
{
    #if !HF_LIGHT_ATTEN & !HF_FOG_ENABLED
        return color;
    #else 
        float distanceAmount = LiniarInterpolation(HF_MinHeight, HF_MaxHeight, wpos.y);
        distanceAmount = exponent(distanceAmount * HF_FogDensity);

        if(HF_WindInfluence > 0)
        {
            float3 noisePos = (wpos * 0.1) + (HF_WindDirection * _Time.yyy);
            float n = (noise(noisePos) + 1) * HF_WindInfluence;
            distanceAmount += n;
        }

        // Distance fog uses just default Exponential Squared like in unity
        float distanceToPixel = distance(_WorldSpaceCameraPos, wpos);
        distanceToPixel = LiniarInterpolation(HF_FogDistanceMin, HF_FogDistanceMax, distanceToPixel);

        float fadeAmount = 1.0 - exponent(distanceToPixel * HF_DistanceDensity);

        float finalFog = saturate(fadeAmount * distanceAmount);
        float3 finalFogColor = GetDefaultFogColor();

        #if HF_LIGHT_ATTEN
            finalFogColor.rgb = ApplyLight(finalFogColor, wpos);
        #endif

        return lerp(color, finalFogColor, finalFog);
    #endif
}

float3 ApplyFogSkybox(float3 color, float3 wpos)
{
    if(HF_SkyFill <= 0)
    return color;

    float k = HF_SkyFill;
    k = 1.0 - pow(abs(sin(PI * (k-1) / 2.0)), .2);

    float maxHeight = lerp(0, FLT_MAX * 1e-32, k);
    float distanceAmount = LiniarInterpolation(HF_MinHeight, maxHeight, wpos.y);
    distanceAmount = exponent(distanceAmount * HF_SkyFogDensity * 2);

    float finalFog = distanceAmount;
    float3 finalFogColor = GetDefaultFogColor();

    // float3 w = _WorldSpaceLightPos0;

    #if HF_LIGHT_ATTEN
        finalFogColor.rgb = ApplyLight(finalFogColor, wpos);
    #endif

    return lerp(color, finalFogColor, finalFog);
}
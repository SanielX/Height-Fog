float HF_DistanceDensity;
float HF_FogDensity;
float HF_LightFarness;
float HF_MaxHeight;
float HF_MinHeight;
float HF_SkyFill;
float HF_SkyFogDensity;
float HF_WindInfluence;
float3 HF_DirectionalLightColor;
float3 HF_DirectionalLightVector;
float3 HF_WindDirection;
float4 HF_DirectionalLightColorBlend;
float4 HF_FogColor;

float4x4 HF_InverseView;
float4x4 unity_CameraInvProjection;

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
    float lightAmount = 1.0 - smooth(saturate(dot(HF_DirectionalLightVector, camToPoint)));
    
    float3 lightColor = (HF_DirectionalLightColor.rgb * HF_DirectionalLightColorBlend.rgb) * HF_DirectionalLightColorBlend.a;
    return lerp(fogColor, lightColor, lightAmount);
}

float3 ApplyFog(float3 color, float3 vpos)
{
    float3 wpos = mul(HF_InverseView, float4(vpos, 1)).xyz;

    float distanceAmount = LiniarInterpolation(HF_MinHeight, HF_MaxHeight, wpos.y);
    distanceAmount = exponent(distanceAmount * HF_FogDensity);

    // Distance fog uses just default Exponential Squared like in unity
    float distanceToPixel = distance(_WorldSpaceCameraPos, wpos);
    float fadeAmount = 1.0 - exponent(distanceToPixel * HF_DistanceDensity);

    float finalFog = fadeAmount * distanceAmount;
    float3 finalFogColor = GetDefaultFogColor();

    if(HF_WindInfluence > 0)
    {
        float3 noisePos = (wpos * 0.1) + (HF_WindDirection * _Time.yyy);
        float n = (noise(noisePos) + 1) * HF_WindInfluence;
        finalFog += n;
        finalFog = saturate(finalFog);
    }

    #if HF_LIGHT_ATTEN
        finalFogColor.rgb = ApplyLight(finalFogColor, wpos);
    #endif

    return lerp(color, finalFogColor, finalFog);
}

float3 ApplyFogSkybox(float3 color, float3 vpos)
{
    if(HF_SkyFill <= 0)
    return color;

    float3 wpos = mul(HF_InverseView, float4(vpos, 1)).xyz;

    float k = HF_SkyFill;
    k = 1.0 - pow(abs(sin(PI * (k-1) / 2.0)), .2);

    float maxHeight = lerp(0, FLT_MAX * 1e-32, k);
    float distanceAmount = LiniarInterpolation(HF_MinHeight, maxHeight, wpos.y);
    distanceAmount = exponent(distanceAmount * HF_SkyFogDensity * 2);

    float finalFog = distanceAmount;
    float3 finalFogColor = GetDefaultFogColor();

    #if HF_LIGHT_ATTEN
        finalFogColor.rgb = ApplyLight(finalFogColor, wpos);
    #endif

    return lerp(color, finalFogColor, finalFog);
}
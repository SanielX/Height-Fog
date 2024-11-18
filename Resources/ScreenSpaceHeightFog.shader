Shader "Hidden/Custom/Height Fog"
{
    HLSLINCLUDE
    #pragma target 5.0

    #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
    #include "../HeightFog.hlsl"

    TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
    TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);

    struct Varyings
    {
        float4 position : SV_Position;
        float2 texcoord : TEXCOORD0;
    };

    Varyings Vertex(uint vertexID : SV_VertexID)
    {
        // Vertex ID -> clip space vertex position
        float  x    = (vertexID != 1) ? -1 : 3;
        float  y    = (vertexID == 2) ? -3 : 1;
        float3 vpos = float3(x, y, 1.0);

        Varyings o;
        o.position  = float4(vpos.x, -vpos.y, 1, 1);
        o.texcoord  = (vpos.xy + 1) / 2;
        return o;
    }

    float unlerp(float a, float b, float x) { return (x - a) / (b - a); }

    float4 Frag(Varyings i) : SV_Target
    {
        float2 clip        = float2(i.texcoord.x, 1 - i.texcoord.y) * 2 - 1;
        float  deviceDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord);

        float4 wsPos = mul(FogVolume_InverseVPMatrix, float4(clip, deviceDepth, 1));
        wsPos.xyz /= wsPos.w;

        float3 view       = wsPos.xyz - _WorldSpaceCameraPos;
        float  viewLength = length(view);
        view /= viewLength;

        float3 scattering;
        float  transmittance;
        FogVolume_ComputeAnalyticalUniformFog(_WorldSpaceCameraPos, view, viewLength, scattering, transmittance);

        bool isSkybox = deviceDepth < FLT_EPSILON * 10;
        if (isSkybox && FogVolume_SkyParams.y > 0)
        {
            float s = max(0, dot(view, float3(0, 1, 0)));
                  s = saturate(unlerp(FogVolume_SkyParams.z, FogVolume_SkyParams.w, s));
                  s = smoothstep(1, 0, pow(s, FogVolume_SkyParams.x)); //  1 - pow(s, FogVolume_SkyParams.x); 	

            float3 fogColor = FogVolume_SampleGlobalLightingScattering(view, FogVolume_Extinction);
            scattering      = fogColor * FogVolume_Extinction.xxx;

            float  skyTransmittance = 1 - s;
            float3 skyScattering    = (scattering - scattering * skyTransmittance) / max(0.0001, FogVolume_Extinction.x);

            float4 fog  = float4(skyScattering, skyTransmittance);
            return fog;
        }
        else
        {
            float4 fog  = float4(scattering, transmittance);
            return fog;
        }
    }
    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            BlendOp Add
            Blend One SrcAlpha, Zero One
            HLSLPROGRAM
            #pragma shader_feature HF_LIGHT_ATTEN
            #pragma vertex Vertex
            #pragma fragment Frag
            ENDHLSL
        }
    }
}
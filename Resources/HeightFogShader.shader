Shader "Hidden/Custom/Height Fog"
{
	HLSLINCLUDE

	#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
	TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
	TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);

	float4x4 unity_CameraInvProjection;
	float4x4 _InverseView;
	float _Blend;
	float _MinHeight, _MaxHeight;
	float _FogDensity, _DistanceDensity;
	float3 _FogColor;

	struct Varyings
	{
		float4 position : SV_Position;
		float2 texcoord : TEXCOORD0;
		float3 ray : TEXCOORD1;
	};

	float LiniarInterpolation(float minValue, float maxValue, float value){
		return clamp((value - minValue) / (maxValue-minValue), 0, 1);
	}

	float3 ComputeViewSpacePosition(Varyings input)
    {
        // Render settings
        float near = _ProjectionParams.y;
        float far = _ProjectionParams.z;
        float isOrtho = unity_OrthoParams.w; // 0: perspective, 1: orthographic

        // Z buffer sample
        float z = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.texcoord);

        #if defined(UNITY_REVERSED_Z)
        float mask = z > 0;
        #else
        float mask = z < 1;
        #endif

        // Perspective: view space position = ray * depth
        float3 vposPers = input.ray * Linear01Depth(z);

        // Orthographic: linear depth (with reverse-Z support)
        #if defined(UNITY_REVERSED_Z)
        float depthOrtho = -lerp(far, near, z);
        #else
        float depthOrtho = -lerp(near, far, z);
        #endif

        // Orthographic: view space position
        float3 vposOrtho = float3(input.ray.xy, depthOrtho);

        // Result: view space position
        return lerp(vposPers, vposOrtho, isOrtho) * mask;
    }

	Varyings Vertex(uint vertexID : SV_VertexID){
		// Render settings
        float far = _ProjectionParams.z;
        float2 orthoSize = unity_OrthoParams.xy;
        float isOrtho = unity_OrthoParams.w; // 0: perspective, 1: orthographic

        // Vertex ID -> clip space vertex position
        float x = (vertexID != 1) ? -1 : 3;
        float y = (vertexID == 2) ? -3 : 1;
        float3 vpos = float3(x, y, 1.0);

        // Perspective: view space vertex position of the far plane
        float3 rayPers = mul(unity_CameraInvProjection, vpos.xyzz * far).xyz;

        // Orthographic: view space vertex position
        float3 rayOrtho = float3(orthoSize * vpos.xy, 0);

        Varyings o;
        o.position = float4(vpos.x, -vpos.y, 1, 1);
        o.texcoord = (vpos.xy + 1) / 2;
        o.ray = lerp(rayPers, rayOrtho, isOrtho);
        return o;
	}

	float exponent(float a){
		return 1 / (pow(2, a));
	}

	float CalculateFogAmount(float3 wpos){
		float distanceAmount = LiniarInterpolation(_MinHeight, _MaxHeight, wpos.y);
		distanceAmount = exponent(distanceAmount * _FogDensity);

		float distanceToPixel = distance(_WorldSpaceCameraPos, wpos);
		float fadeAmount = 1.0 - exponent(distanceToPixel * _DistanceDensity);

		return fadeAmount * distanceAmount;
	}

	float4 Frag(Varyings i) : SV_Target
	{
		float3 wpos = ComputeViewSpacePosition(i);
		wpos = mul(_InverseView, float4(wpos, 1)).xyz;

		float4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);

		float fogAmount = CalculateFogAmount(wpos);

		mainTex = lerp(mainTex, float4(_FogColor, 1), fogAmount);

		return mainTex;
	}

	ENDHLSL

	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			HLSLPROGRAM

			#pragma vertex Vertex
			#pragma fragment Frag

			ENDHLSL
		}
	}
}
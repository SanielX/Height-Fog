Shader "Hidden/Custom/Height Fog"
{
	HLSLINCLUDE

	#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
	#pragma multi_compile HF_LIGHT_ATTEN
	#include "KejiroNoise.hlsl"
	#include "HeightFogUsage.hlsl"

	TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
	TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);

	struct Varyings
	{
		float4 position : SV_Position;
		float2 texcoord : TEXCOORD0;
		float3 ray : TEXCOORD1;
	};

	float3 ComputeViewSpacePosition(Varyings input, out float mask)
	{
		// Render settings
		float isOrtho = unity_OrthoParams.w; // 0: perspective, 1: orthographic

		// Z buffer sample
		float z = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.texcoord);

		// Perspective: view space position = ray * depth
		float3 vposPers = input.ray * Linear01Depth(z);

		// Orthographic: linear depth (with reverse-Z support)
		#if defined(UNITY_REVERSED_Z)  // z - far, y - near
			float depthOrtho = -lerp(_ProjectionParams.z, _ProjectionParams.y, z);
			mask = z > 0;
		#else
			float depthOrtho = -lerp(_ProjectionParams.y, _ProjectionParams.z, z);
			mask = z < 1;
		#endif

		// Orthographic: view space position
		float3 vposOrtho = float3(input.ray.xy, depthOrtho);

		// Result: view space position
		return lerp(vposPers, vposOrtho, isOrtho);
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

	float4 Frag(Varyings i) : SV_Target
	{
		float4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
		float mask;
		float3 vpos = ComputeViewSpacePosition(i, mask);
		
		mainTex.rgb = lerp(ApplyFogSkybox(mainTex.rgb, vpos), ApplyFog(mainTex.rgb, vpos), mask);
		
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
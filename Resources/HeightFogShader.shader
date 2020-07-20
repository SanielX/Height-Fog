Shader "Hidden/Custom/Height Fog"
{
	HLSLINCLUDE

	#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
	#pragma shader_feature_local LIGHT_ATTEN

	TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
	TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);

	float4x4 unity_CameraInvProjection;
	float4x4 _InverseView;
	float _MinHeight, _MaxHeight;
	float _FogDensity, _DistanceDensity;
	float3 _FogColor;
	float _WindInfluence;
	float3 _WindDirection;

	float3 _DirectionalLightColor;
	float3 _DirectionalLightVector;

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

	float exponent(float a){
		return 1 / (pow(2, a));
	}

	float hash( float n )
	{
		return frac(sin(n)*43758.5453);
	}

	float noise( float3 x )
	{
		// The noise function returns a value in the range -1.0f -> 1.0f

		float3 p = floor(x);
		float3 f = frac(x);

		f = f*f*(3.0-2.0*f);
		float n = p.x + p.y*57.0 + 113.0*p.z;

		// FIXME:
		// Well this kinda sucks. Too many sin calls lmao
		return lerp(lerp(lerp( hash(n+0.0), hash(n+1.0),f.x),
		lerp( hash(n+57.0), hash(n+58.0),f.x),f.y),
		lerp(lerp( hash(n+113.0), hash(n+114.0),f.x),
		lerp( hash(n+170.0), hash(n+171.0),f.x),f.y),f.z);
	}

	float4 ApplyFog(float4 color, float3 vpos){

		float3 wpos = mul(_InverseView, float4(vpos, 1)).xyz;

		float distanceAmount = LiniarInterpolation(_MinHeight, _MaxHeight, wpos.y);
		distanceAmount = exponent(distanceAmount * _FogDensity);

		// Distance fog uses just default Exponential Squared like in unity
		float distanceToPixel = distance(_WorldSpaceCameraPos, wpos);
		float fadeAmount = 1.0 - exponent(distanceToPixel * _DistanceDensity);

		float finalFog = fadeAmount * distanceAmount;

		if(_WindInfluence > 0)
		{
			float3 noisePos = (wpos * 0.1) + (_WindDirection * 2 + _Time.y);
			finalFog *= clamp((noise(noisePos) + 1) * 0.5, 1.0 - _WindInfluence, 1);
		}

		float4 finalFogColor = float4(_FogColor, 1);

		// Not sure if this is the best way to do lighting
		// It makes damn big sphere in the direction of Directional Light relative to camera pos
		// Light color is kinda brighter than one set in light settings
		#if LIGHT_ATTEN
			float3 lightPos = _WorldSpaceCameraPos - _DirectionalLightVector * 1000;
			float distanceToSun = distance(lightPos, wpos) / 1000;
			distanceToSun = 1.0 - saturate(distanceToSun);

			float3 lightCol = saturate(_DirectionalLightColor * 4);
			finalFogColor.rgb = lerp(finalFogColor, lightCol, distanceToSun);
		#endif

		return lerp(color, finalFogColor, finalFog);
	}

	float4 Frag(Varyings i) : SV_Target
	{
		float4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
		mainTex = ApplyFog(mainTex, ComputeViewSpacePosition(i));

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
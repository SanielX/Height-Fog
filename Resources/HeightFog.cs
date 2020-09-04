using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;

namespace HostGame.HeightFog
{
    [System.Serializable]
    public class FogEnum : ParameterOverride<FogMode> { }

    [System.Serializable]
    [PostProcess(typeof(HeightFogRenderer), PostProcessEvent.BeforeStack, "Custom/Height Fog")]
    public class HeightFog : PostProcessEffectSettings
    {
        [ColorUsage(false, true)]
        [Header("Hight fog")]
        public ColorParameter FogColor = new ColorParameter { value = Color.white };
        [UnityEngine.Rendering.PostProcessing.Min(0)]
        public FloatParameter FogDensity = new FloatParameter { value = 6f };

        [UnityEngine.Rendering.PostProcessing.Min(0)]
        public FloatParameter MinFogHeight = new FloatParameter { value = 10f };

        [UnityEngine.Rendering.PostProcessing.Min(0)]
        public FloatParameter MaxFogHeight = new FloatParameter { value = 200f };

        [Header("Distance fog")]
        [UnityEngine.Rendering.PostProcessing.Min(0)]
        public FloatParameter DistanceDensity = new FloatParameter { value = 0.01f };

        public FogEnum FogMode = new FogEnum { value = UnityEngine.FogMode.ExponentialSquared };

        [UnityEngine.Rendering.PostProcessing.Min(0)]
        public FloatParameter MinFogDistance = new FloatParameter { value = 10f };

        [UnityEngine.Rendering.PostProcessing.Min(0)]
        public FloatParameter MaxFogDistance = new FloatParameter { value = 200f };

        [Header("Skybox parameters")]
        [Range(0, 1)]
        public FloatParameter SkyFill = new FloatParameter { value = .5f };
        [UnityEngine.Rendering.PostProcessing.Min(0)]
        public FloatParameter SkyFogDensity = new FloatParameter { value = 6f };

        [Header("Noise")]
        public Vector3Parameter WindDirection = new Vector3Parameter { value = Vector3.zero };
        [Range(0, 1)]
        public FloatParameter WindInfluence = new FloatParameter { value = .15f };

        [Header("Lighting")]
        public BoolParameter LightColoring = new BoolParameter();
        [ColorUsage(false, true)]
        public ColorParameter DirectionalLightColorBlender = new ColorParameter { value = Color.white };

        [UnityEngine.Rendering.PostProcessing.Min(0)]
        public FloatParameter LightFarness = new FloatParameter { value = 1 };

        [Range(0, 1)]
        public FloatParameter LightInfluence = new FloatParameter { value = 1 };
    }

    public class HeightFogRenderer : PostProcessEffectRenderer<HeightFog>
    {
        static readonly int inverseView = Shader.PropertyToID("HF_InverseView");
        static readonly int minHeight = Shader.PropertyToID("HF_MinHeight");
        static readonly int maxHeight = Shader.PropertyToID("HF_MaxHeight");
        static readonly int skyFill = Shader.PropertyToID("HF_SkyFill");
        static readonly int distanceDensity = Shader.PropertyToID("HF_DistanceDensity");
        static readonly int fogColor = Shader.PropertyToID("HF_FogColor");
        static readonly int fogDensity = Shader.PropertyToID("HF_FogDensity");
        static readonly int skyFogDensity = Shader.PropertyToID("HF_SkyFogDensity");
        static readonly int windDirection = Shader.PropertyToID("HF_WindDirection");
        static readonly int windInfluence = Shader.PropertyToID("HF_WindInfluence");
        static readonly int directionalLightColor = Shader.PropertyToID("HF_DirectionalLightColor");
        static readonly int directionalLightColorBlend = Shader.PropertyToID("HF_DirectionalLightColorBlend");
        static readonly int directionalLightVector = Shader.PropertyToID("HF_DirectionalLightVector");
        static readonly int lightFarness = Shader.PropertyToID("HF_LightFarness");
        static readonly int lightInfluence = Shader.PropertyToID("HF_LightInfluence");
        static readonly int fogDistanceMax = Shader.PropertyToID("HF_FogDistanceMax");
        static readonly int fogDistanceMin = Shader.PropertyToID("HF_FogDistanceMin");

        public override void Render(PostProcessRenderContext context)
        {
            var sheet = context.propertySheets.Get(Shader.Find("Hidden/Custom/Height Fog"));

            Shader.SetGlobalMatrix(inverseView, context.camera.cameraToWorldMatrix);
            Shader.SetGlobalFloat(minHeight, settings.MinFogHeight);
            Shader.SetGlobalFloat(maxHeight, settings.MaxFogHeight);
            Shader.SetGlobalFloat(skyFill, settings.SkyFill);
            Shader.SetGlobalFloat(distanceDensity, settings.DistanceDensity);
            Shader.SetGlobalColor(fogColor, settings.FogColor);
            Shader.SetGlobalFloat(fogDensity, settings.FogDensity);
            Shader.SetGlobalFloat(fogDistanceMax, settings.MaxFogDistance);
            Shader.SetGlobalFloat(fogDistanceMin, settings.MinFogDistance);
            Shader.SetGlobalFloat(skyFogDensity, settings.SkyFogDensity);
            Shader.SetGlobalVector(windDirection, settings.WindDirection);
            Shader.SetGlobalFloat(windInfluence, settings.WindInfluence);

            var sun = RenderSettings.sun;
            if (!sun || !settings.LightColoring)
            {
                Shader.DisableKeyword("HF_LIGHT_ATTEN");
                context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);

                return;
            }

            Shader.EnableKeyword("HF_LIGHT_ATTEN");
            Shader.SetGlobalColor(directionalLightColor, sun.color);
            Shader.SetGlobalColor(directionalLightColorBlend, settings.DirectionalLightColorBlender);
            var sunTransform = sun.transform;
            Shader.SetGlobalVector(directionalLightVector, sunTransform.forward);
            Shader.SetGlobalFloat(lightFarness, settings.LightFarness);
            Shader.SetGlobalFloat(lightInfluence, settings.LightInfluence);

            context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
        }
    }
}
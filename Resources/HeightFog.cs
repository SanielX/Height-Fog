using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;

[System.Serializable]
[PostProcess(typeof(HeightFogRenderer), PostProcessEvent.AfterStack, "Custom/Height Fog")]
public class HeightFogSettings : PostProcessEffectSettings
{
    [ColorUsage(false, true)]
    public ColorParameter FogColor = new ColorParameter { value = Color.white };
    [UnityEngine.Rendering.PostProcessing.Min(0)]
    public FloatParameter FogDensity = new FloatParameter { value = 6f };

    [UnityEngine.Rendering.PostProcessing.Min(0)]
    public FloatParameter MinFogHeight = new FloatParameter { value = 10f };

    [UnityEngine.Rendering.PostProcessing.Min(0)]
    public FloatParameter MaxFogHeight = new FloatParameter { value = 10000f };

    [Range(0,1)]
    public FloatParameter SkyFill = new FloatParameter { value = .5f };
    [UnityEngine.Rendering.PostProcessing.Min(0)]
    public FloatParameter SkyFogDensity = new FloatParameter { value = 6f };

    [UnityEngine.Rendering.PostProcessing.Min(0)]
    public FloatParameter DistanceDensity = new FloatParameter { value = 0.01f };

    public Vector3Parameter WindDirection = new Vector3Parameter { value = Vector3.zero };

    [Range(0, 1)]
    public FloatParameter WindInfluence = new FloatParameter { value = .15f };

    public BoolParameter LightColoring = new BoolParameter();
    [ColorUsage(false, true)]
    public ColorParameter DirectionalLightColorBlender = new ColorParameter { value = Color.white };

    [UnityEngine.Rendering.PostProcessing.Min(0)]
    public FloatParameter LightFarness = new FloatParameter { value = 1 };
}

public class HeightFogRenderer : PostProcessEffectRenderer<HeightFogSettings>
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

        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
    }
}

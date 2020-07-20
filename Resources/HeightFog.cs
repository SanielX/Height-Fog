using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;

[System.Serializable]
[PostProcess(typeof(HeightFogRenderer), PostProcessEvent.AfterStack, "Custom/Height Fog")]
public class HeightFogSettings : PostProcessEffectSettings
{
    public ColorParameter FogColor = new ColorParameter { value = Color.white };
    [UnityEngine.Rendering.PostProcessing.Min(0)]
    public FloatParameter FogDensity = new FloatParameter { value = 0.1f };

    [UnityEngine.Rendering.PostProcessing.Min(0)]
    public FloatParameter MinFogHeight = new FloatParameter { value = 0f };

    [UnityEngine.Rendering.PostProcessing.Min(0)]
    public FloatParameter MaxFogHeight = new FloatParameter { value = 5f };

    public FloatParameter DistanceDensity = new FloatParameter { value = 0.1f };
    public Vector3Parameter WindDirection = new Vector3Parameter { value = Vector3.zero };

    [Range(0, 1)]
    public FloatParameter WindInfluence = new FloatParameter { value = 1 };

    public BoolParameter LightColoring = new BoolParameter();
}

public class HeightFogRenderer : PostProcessEffectRenderer<HeightFogSettings>
{
    public override void Render(PostProcessRenderContext context)
    {
        var sheet = context.propertySheets.Get(Shader.Find("Hidden/Custom/Height Fog"));

        sheet.properties.SetMatrix("_InverseView", context.camera.cameraToWorldMatrix);
        sheet.properties.SetFloat("_MinHeight", settings.MinFogHeight);
        sheet.properties.SetFloat("_MaxHeight", settings.MaxFogHeight);
        sheet.properties.SetFloat("_DistanceDensity", settings.DistanceDensity);
        sheet.properties.SetColor("_FogColor", settings.FogColor);
        sheet.properties.SetFloat("_FogDensity", settings.FogDensity);
        sheet.properties.SetVector("_WindDirection", settings.WindDirection);
        sheet.properties.SetFloat("_WindInfluence", settings.WindInfluence);

        var sun = RenderSettings.sun;
        if (!sun || !settings.LightColoring)
        {
            sheet.DisableKeyword("LIGHT_ATTEN");
            context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
            return;
        }

        sheet.EnableKeyword("LIGHT_ATTEN");
        sheet.properties.SetColor("_DirectionalLightColor", sun.color);
        var sunTransform = sun.transform;
        sheet.properties.SetVector("_DirectionalLightVector", sunTransform.forward);

        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
    }
}

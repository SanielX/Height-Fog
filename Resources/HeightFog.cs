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
    public FloatParameter FogDensity = new FloatParameter { value = 0.1f };
    public FloatParameter MinFogHeight = new FloatParameter { value = 0f };
    public FloatParameter MaxFogHeight = new FloatParameter { value = 5f };
    public FloatParameter DistanceDensity = new FloatParameter { value = 0.1f };
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

        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
    }
}

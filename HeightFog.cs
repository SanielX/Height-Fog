using System.Runtime.InteropServices;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;

namespace Hollow.HeightFog
{
public enum SunColorMode
{
    Multiply,
    Override
}

[System.Serializable]
public class SunColorTypeEnumParameter : ParameterOverride<SunColorMode> { }

// Keep in sync with cbuffer in HeightFog.hlsl
[StructLayout(LayoutKind.Sequential)]
unsafe struct FogVolume_ConstantBuffer
{
    public Matrix4x4 FogVolume_InverseVPMatrix;
    
    public Vector4 FogVolume_SunDirection;
    public Vector4 FogVolume_SunColor;
    public Vector4 FogVolume_Emissive;
    public Vector4 FogVolume_SkyParams;
    public Vector4 FogVolume_SmoothDepthParams;
    
    public Vector2 FogVolume_Distances;
    public Vector2 FogVolume_GlobalFogPhaseW;

    public Vector2 FogVolume_HeightExponents;
    public float   FogVolume_Extinction;
    public float   FogVolume_BaseHeight;
    
    public float  FogVolume_GlobalFogPhase;
    public float  FogVolume_AmbientStrength;
}

[System.Serializable]
[PostProcess(typeof(HeightFogRenderer), PostProcessEvent.BeforeTransparent, "Custom/Height Fog")]
public class HeightFog : PostProcessEffectSettings
{
    [Tooltip("[Default = 0]\nDensity of the fog particles. To work correctly you need to keep 'Smooth Length' equal to 1")]
    [Range(0, 1f)] public FloatParameter density  = new() { value = 0.0f };
    [Tooltip("[Default = -1]\nOffsets fog density from camera"), UnityEngine.Rendering.PostProcessing.Min(0f)]
    public FloatParameter minDistnace  = new() { value = -1.0f };
    [Tooltip("[Default = 1]"), UnityEngine.Rendering.PostProcessing.Min(0f)]
    public FloatParameter smoothLength = new() { value =  1.0f };
    
    [Space]
    [ColorUsage(false, true)] public ColorParameter emissive = new() { value = Color.white };
    
    [Space]
    [UnityEngine.Rendering.PostProcessing.Min(0)] public FloatParameter            sunLightStength = new();
    [Tooltip("Multiply - 'Sun Color' will multiply color of the current directional light\n" +
             "Override - 'Sun Color' will replace color of the current directional light")]
                                                  public SunColorTypeEnumParameter sunMode = new();
    [ColorUsage(false, true)]                     public ColorParameter            sunColor = new() { value = Color.white };
    
    [Header("Phase")]
    [Tooltip("[Default = -0.5]\nNegative values will collect light from the sun into a point, around zero will evenly spread light color and positive values will make sun appear on the opposite side")]
    [Range(-1f, 1f)] public FloatParameter phase   = new() { value = -.5f };
    [Range(0f,  1f)] public FloatParameter phaseW0 = new() { value = 1f };
    [Range(0f,  1f)] public FloatParameter phaseW1 = new() { value = 0f };
    
    [Header("Height")]
    [UnityEngine.Rendering.PostProcessing.Min(0)] public FloatParameter minHeight = new();
    [UnityEngine.Rendering.PostProcessing.Min(0)] public FloatParameter transitionLength = new() { value = 100f };
    
    [Header("Sky")]
    public   BoolParameter  skyHandling = new() { value = true };
    public   FloatParameter skyPower = new() { value = 1f };
    [Tooltip("Represents percentage of sky that will be populated with fog. Everything below left handle is fully covered in fog, everything above is fully visible")]
    [MinMax(0, 1)]
    public Vector2Parameter skyFillRange = new() { value = new(0, 1f) };
}

public unsafe class HeightFogRenderer : PostProcessEffectRenderer<HeightFog>
{
    private GlobalKeyword fogEnabledKeyword;
    private Shader heightFogShader;
    private GraphicsBuffer fogVolumeDataBuffer;
    private NativeArray<FogVolume_ConstantBuffer> fogVolumeData;
    static readonly int FogVolumeConstantBuffer = Shader.PropertyToID("FogVolume_ConstantBuffer");

    public override void Init()
    {
        heightFogShader = Resources.Load<Shader>("ScreenSpaceHeightFog");
        
        fogVolumeDataBuffer = new(GraphicsBuffer.Target.Constant, 1, sizeof(FogVolume_ConstantBuffer));
        fogVolumeData       = new(1, Allocator.Persistent);
        
        fogEnabledKeyword = GlobalKeyword.Create("_HEIGHT_FOG_ENABLED");
        Shader.SetKeyword(fogEnabledKeyword, true);
    }

    public override void Release()
    {
        Shader.SetKeyword(fogEnabledKeyword, false);
        fogVolumeData.Dispose();
        fogVolumeDataBuffer.Dispose();
    }
    
    internal Vector2 HeightExponents()
    {
        var minHeight    = settings.minHeight.value;
        float maxHeight  = minHeight + settings.transitionLength.value;
        float layerDepth = Mathf.Max(0.01f, maxHeight - minHeight);
            
        // Exp[-d / H] = 0.001
        // -d / H = Log[0.001]
        // H = d / -Log[0.001]
        // return d * 0.144765f;
        float H = layerDepth * 0.144765f;
        return new Vector2(1.0f / H, H);
    }

    public override void Render(PostProcessRenderContext context)
    {
        var sheet = context.propertySheets.Get(heightFogShader);
        
        FogVolume_ConstantBuffer fogData = default;
        
        var view = context.camera.worldToCameraMatrix;
        var proj = GL.GetGPUProjectionMatrix(context.camera.projectionMatrix, true);
        
        Matrix4x4 invView = default;
        Matrix4x4.Inverse3DAffine(view, ref invView);
            
        var invVP = invView * proj.inverse;
        
        fogData.FogVolume_InverseVPMatrix = invVP;
        fogData.FogVolume_Distances.x     = settings.minDistnace.value;
        fogData.FogVolume_Distances.y     = Mathf.Max(0.0001f, settings.smoothLength.value);
        fogData.FogVolume_Extinction      = Mathf.Pow(settings.density.value, 2 * (float)System.Math.E);
        fogData.FogVolume_GlobalFogPhase  = settings.phase.value;
        fogData.FogVolume_GlobalFogPhaseW = new(settings.phaseW0.value, settings.phaseW1.value);
        fogData.FogVolume_BaseHeight      = settings.minHeight.value;  
        fogData.FogVolume_HeightExponents = HeightExponents();
        fogData.FogVolume_AmbientStrength = 0.0f;
        fogData.FogVolume_Emissive        = settings.emissive.value;
        
        fogData.FogVolume_SkyParams.x = settings.skyPower.value;
        fogData.FogVolume_SkyParams.y = settings.skyHandling.value? 1 : 0;
        fogData.FogVolume_SkyParams.z = settings.skyFillRange.value.x;
        fogData.FogVolume_SkyParams.w = settings.skyFillRange.value.y;
        
        // x - 1 / (smoothInterval), y - pow(1./s, 2), z-0.5*pow(1./s,3), w - h0
        float s = Mathf.Max(0.0001f, settings.smoothLength.value);
        fogData.FogVolume_SmoothDepthParams.x = s == 0? 0.0f : 1.0f / s;
        fogData.FogVolume_SmoothDepthParams.y = Mathf.Pow(1/s, 2);
        fogData.FogVolume_SmoothDepthParams.z = Mathf.Pow(1/s, 3) * 0.5f;
        // pow(1/s, 2) * pow(s, 3) - 0.5*pow(1/s,3)*pow(s, 4)
        fogData.FogVolume_SmoothDepthParams.w = Mathf.Pow(1/s, 2)*Mathf.Pow(s, 3) - 0.5f*Mathf.Pow(1/s, 3)*Mathf.Pow(s, 4);
        
        if (RenderSettings.sun)
        {
            var sun = RenderSettings.sun;
            if (settings.sunMode.value == SunColorMode.Override)
            {
                fogData.FogVolume_SunColor = settings.sunColor.value;
            }
            else
            {
                fogData.FogVolume_SunColor = settings.sunColor.value * RenderSettings.sun.color;
            }

            fogData.FogVolume_SunColor *= sun.intensity;
            
            fogData.FogVolume_SunDirection   = sun.transform.forward;
            fogData.FogVolume_SunDirection.w = settings.sunLightStength.value;
        }
        else
        {
            fogData.FogVolume_SunColor       = Color.black;
            fogData.FogVolume_SunDirection.w = 0;
        }
        
        fogVolumeData[0] = fogData;
        Shader.SetGlobalConstantBuffer(FogVolumeConstantBuffer, fogVolumeDataBuffer, 0, fogVolumeDataBuffer.stride);
        context.command.SetBufferData(fogVolumeDataBuffer, fogVolumeData);
        context.command.SetGlobalConstantBuffer(fogVolumeDataBuffer, FogVolumeConstantBuffer, 0, fogVolumeDataBuffer.stride);

        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
    }
}
}
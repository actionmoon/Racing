Shader "RacingClone/VertexSurface"
{
    Properties
    {
        _BaseMap("Texture", 2D) = "white" {}
        _BaseColor("Color", Color) = (1,1,1,1)
        _Cull("Cull", Float) = 2
        _Cutoff("Cutoff", Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        Pass
        {
            Tags { "LightMode"="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            struct Attributes { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; float4 color:COLOR; };
            struct Varyings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 normalWS:TEXCOORD1; float4 color:COLOR; float fog:TEXCOORD2; float3 positionWS:TEXCOORD3; };
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST; float4 _BaseColor;
            CBUFFER_END
            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionCS=TransformObjectToHClip(v.positionOS.xyz);
                o.normalWS=TransformObjectToWorldNormal(v.normalOS);
                o.positionWS=TransformObjectToWorld(v.positionOS.xyz);
                o.uv=TRANSFORM_TEX(v.uv,_BaseMap); o.color=v.color;
                o.fog=ComputeFogFactor(o.positionCS.z);
                return o;
            }
            half4 frag(Varyings i):SV_Target
            {
                Light sun=GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half3 n=normalize(i.normalWS);
                half3 light=SampleSH(n)+sun.color*saturate(dot(n,sun.direction))*sun.shadowAttenuation;
                half4 c=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv)*_BaseColor*i.color;
                return half4(MixFog(c.rgb*light,i.fog),c.a);
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
    }
}

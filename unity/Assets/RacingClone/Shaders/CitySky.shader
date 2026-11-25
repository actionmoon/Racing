Shader "RacingClone/CitySky"
{
    Properties
    {
        _Top("Top", Color) = (0.184,0.498,0.878,1)
        _Horizon("Horizon", Color) = (0.812,0.918,1,1)
        _Bottom("Bottom", Color) = (0.561,0.722,0.847,1)
    }
    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Background" "RenderPipeline"="UniversalPipeline" }
        Cull Off ZWrite Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct A { float4 p:POSITION; };
            struct V { float4 p:SV_POSITION; float3 direction:TEXCOORD0; };
            float4 _Top, _Horizon, _Bottom;
            V vert(A i) { V o; o.p=TransformObjectToHClip(i.p.xyz); o.direction=i.p.xyz; return o; }
            half4 frag(V i):SV_Target
            {
                float y=normalize(i.direction).y;
                return y>0 ? lerp(_Horizon,_Top,pow(saturate(y),0.65)) : lerp(_Horizon,_Bottom,saturate(-y*3));
            }
            ENDHLSL
        }
    }
}

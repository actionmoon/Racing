Shader "RacingClone/Water"
{
    Properties { _BaseColor("Water",Color)=(0.1,0.5,0.8,0.92) }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
        Cull Off ZWrite Off Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct A { float4 p:POSITION; };
            struct V { float4 p:SV_POSITION; float3 world:TEXCOORD0; };
            float4 _BaseColor;
            V vert(A i) { V o; o.world=TransformObjectToWorld(i.p.xyz); o.p=TransformWorldToHClip(o.world); return o; }
            half4 frag(V i):SV_Target
            {
                float t=_Time.y;
                float wave=sin(i.world.x*.12+t*.6)*sin(i.world.z*.16-t*.8);
                float ripple=sin(i.world.x*.6+i.world.z*.4+t*1.4);
                float glint=pow(saturate(wave*.5+ripple*.2+.3),12);
                return half4(_BaseColor.rgb*(.82+wave*.12)+glint*.45,_BaseColor.a);
            }
            ENDHLSL
        }
    }
}

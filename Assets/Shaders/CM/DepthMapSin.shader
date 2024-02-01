Shader "Custom/DepthMapSin"
{
    Properties
    {
    }

    SubShader
    {
        Tags
        {
            "Directional Shadow" = "1"
            "Spot Shadow" = "2"
            "Point Shadow" = "3"
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            uniform float3 _l;
            uniform float farPlane;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 vert : TEXCOORD1;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.vert = v.vertex;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 worldPos = mul(unity_ObjectToWorld, float4(i.vert.xyz, 1.0)).xyz;
                float3 ldir = worldPos - _l;
                float depth = length(ldir) / 60;

                float4 Frag2;
                float PI = 3.14159265358979;
                float4 kv = PI * depth * float4(1.0, 3.0, 5.0, 7.0);
                Frag2 = sin(kv);
                Frag2 = Frag2 * 0.5 + 0.5;

                return Frag2;
            }

            ENDCG

        }
    }
}

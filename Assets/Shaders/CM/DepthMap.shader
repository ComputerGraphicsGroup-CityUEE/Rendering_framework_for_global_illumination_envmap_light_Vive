Shader "Custom/DepthMap"
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

            uniform float farPlane;
            uniform float3 _l;

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
                float3 ldir = (worldPos - _l).xyz;
                float depth = length(ldir) / 60;

                float4 Frag0;
                float PI = 3.14159265358979;
                Frag0 = float4(depth, 1.0, 1.0, 1.0);
                Frag0 = Frag0 * 0.5 + 0.5;

                return Frag0;
            }
            ENDCG
        }
    }
}

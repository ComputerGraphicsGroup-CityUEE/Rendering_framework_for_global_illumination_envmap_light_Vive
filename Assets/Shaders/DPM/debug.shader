Shader "Custom/debug"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _Tex("Texture", 2D) = "white" {}
    }
        SubShader
    {

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            struct appdata
            {
                float2 uv : TEXCOORD0;
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD2;
                float3 bv : TEXCOORD3;
            };
            UNITY_DECLARE_TEX2DARRAY(_gShadowMapTextureArray_RT);

            UNITY_DECLARE_TEX2DARRAY(_gShadowMapTextureArray0);
            UNITY_DECLARE_TEX2DARRAY(_gShadowMapTextureArray1);
            uniform int _index;

            uniform float4x4 _gWorldToLightCamera;//当前片段从世界坐标转换到光源相机空间坐标的变换矩阵
            uniform sampler2D _gShadowMapTexture0, _gShadowMapTexture1, _gShadowMapTexture2, _gShadowMapTexture3, _gShadowMapTexture4, _gShadowMapTexture5, _gShadowMapTexture6, _gShadowMapTexture7, _gShadowMapTexture8, _gShadowMapTexture9;
            uniform float4 _gShadowMapTexture0_TexelSize;
            uniform float _gShadowStrength;
            uniform float _gShadowBias;

            uniform float3 _l;

            uniform sampler2D _Tex;
            uniform float4 _Tex_ST;
            uniform int Debug;

            float4 _Color;

            v2f vert(appdata v)
            {
                
                v2f o;

                float4 hp = UnityObjectToClipPos(v.vertex);//MVP

                o.pos = hp;

                //o.uv = TRANSFORM_TEX(v.uv, _Tex);
                o.uv = v.uv;
                o.bv = v.vertex.xyz;
                
                return o;

            }


            float4 frag(v2f i) : SV_Target
            {

                //return UNITY_SAMPLE_TEX2DARRAY(_gShadowMapTextureArray0, float3(i.uv.xy, _index));
                
                return UNITY_SAMPLE_TEX2DARRAY(_gShadowMapTextureArray_RT, float3(i.uv.xy, _index));

                /*sampler2D dpmap[10] =
                {
                    _gShadowMapTexture0,
                    _gShadowMapTexture1,
                    _gShadowMapTexture2,
                    _gShadowMapTexture3,
                    _gShadowMapTexture4,
                    _gShadowMapTexture5,
                    _gShadowMapTexture6,
                    _gShadowMapTexture7,
                    _gShadowMapTexture8,
                    _gShadowMapTexture9
                };
                switch (Debug)
                {
                    case 0:
                        return tex2D(dpmap[0], i.uv);
                    case 1:
                        return tex2D(dpmap[1], i.uv);
                    case 2:
                        return tex2D(dpmap[2], i.uv);
                    case 3:
                        return tex2D(dpmap[3], i.uv);
                    case 4:
                        return tex2D(dpmap[4], i.uv);
                    case 5:
                        return tex2D(dpmap[5], i.uv);
                    case 6:
                        return tex2D(dpmap[6], i.uv);
                    case 7:
                        return tex2D(dpmap[7], i.uv);
                    case 8:
                        return tex2D(dpmap[8], i.uv);
                    case 9:
                        return tex2D(dpmap[9], i.uv);
                    default:
                        return tex2D(dpmap[0], i.uv); 
                }*/
            }
            ENDCG
        }
    }
}


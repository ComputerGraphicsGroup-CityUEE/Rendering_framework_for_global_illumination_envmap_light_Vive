Shader "Custom/Point Shadow2"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo (RGB)", 2D) = "white" {}
    }

    SubShader
    {
        Tags {"Point Shadow" = "3"}

        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            uniform float4 _Color;
            //uniform float4x4 _CubeShadowV;
            uniform float _CubeBias;
            uniform float _CubeLightBrightness;
            uniform float _CubeNearPlane;
            uniform float _CubeFarPlane;
            uniform int _CubeMapSize;
            uniform float _CubeLightSize;
            uniform float3 _l;
            uniform int _CubeDiffuse;
            uniform int _CubeAtten;
            uniform int _CubeShadow;
            uniform float4 _CubeLightColor;
            uniform float M;
            uniform float ALPHA;
            uniform float K;
            uniform float OFFSET;
            uniform float SCALEFACTOR;
            uniform float SHADOW_A;
            uniform float SHADOW_B;
            //uniform float4x4 _CubeShadowVP;

            samplerCUBE _CubeMap0;
            samplerCUBE _CubeMap1;
            samplerCUBE _CubeMap2;
            samplerCUBE _CubeMap3;
            samplerCUBE _CubeMap4;

            sampler2D _MainTex;

            #define PI 3.14159265358979f

            float supress_flag = 0.0;

            float pcss(float3 uv, float objectDepth)
            {
                //step1
                float blockerDepth = objectDepth / _CubeFarPlane;
                float filterSize = (_CubeLightSize) * (objectDepth - _CubeNearPlane) / objectDepth;
                //if(objectDepth > 1) return 1.0f;
                filterSize = clamp(filterSize, 0.0f, 1.0f);
                filterSize = log(_CubeMapSize * filterSize) / log(2.0f);
                blockerDepth = texCUBElod(_CubeMap0, float4(normalize(uv) ,filterSize)).r;
                if (blockerDepth >= objectDepth - _CubeBias)
                    return 1.0f;
                //return blockerDepth;
                filterSize = (_CubeLightSize) * (objectDepth / _CubeFarPlane - blockerDepth) / blockerDepth;
                filterSize = log(_CubeMapSize * filterSize) / log(2.0f);
                float d = texCUBElod(_CubeMap0, float4(normalize(uv) ,filterSize)).r;
                return  d < objectDepth / _CubeFarPlane - _CubeBias ? d : 1;
            }

            float calFilterSize(float objectDepth, float blockerDepth)
            {
                float a, b, c;
                a = _CubeLightSize / objectDepth;
                b = _CubeLightSize / blockerDepth;
                a = clamp(a, 0.0f, 1.0f);
                b = clamp(b, 0.0f, 1.0f);
                c = a * b + sqrt((1.0f - a * a) * (1.0f - b * b));
                return sqrt(1.0f / (c * c) - 1.0f);
            }

            float4 getTextureVal(samplerCUBE cubeMap, float3 uv, float filterSize)
            {
                float lod = log(_CubeMapSize * filterSize) / log(2.0f);
                return texCUBElod(cubeMap, float4(normalize(uv), lod)) * 2.0f - 1.0f;
            }

            float cssmBasis(samplerCUBE cubeMap1, samplerCUBE cubeMap2, float3 uv, float objectDepthZ, float filterSize)
            {
                float4 cosVal = getTextureVal(cubeMap1, uv,filterSize),
                sinVal = getTextureVal(cubeMap2, uv, filterSize),
                temp = PI * float4(1.0f, 3.0f, 5.0f, 7.0f),
                weights = float4(exp(-ALPHA * (K) * (K) / (M * M)),
                    exp(-ALPHA * (K + 1.0f) * (K + 1.0f) / (M * M)),
                    exp(-ALPHA * (K + 2.0f) * (K + 2.0f) / (M * M)),
                    exp(-ALPHA * (K + 3.0f) * (K + 3.0f) / (M * M)));
                float sum1 = dot(cos(temp * (objectDepthZ - _CubeBias)) / temp, sinVal * weights),
                sum2 = dot(sin(temp * (objectDepthZ - _CubeBias)) / temp, cosVal * weights);
                float rec = 0.5f + 2.0f * (sum1 - sum2);
                if (supress_flag == 1.0)
                    rec = SCALEFACTOR * (rec - OFFSET);
                return clamp(1.0f * rec, 0.0f, 1.0f);
            }

            float cssmBasisZ(samplerCUBE cubeMap0, samplerCUBE cubeMap3, samplerCUBE cubeMap4, float3 uv, float objectDepthZ, float filterSize)
            {
                float4 cosZVal = getTextureVal(cubeMap3, uv, filterSize),
                sinZVal = getTextureVal(cubeMap4, uv, filterSize),
                temp = PI * float4(1.0f, 3.0f, 5.0f, 7.0f),
                weights = float4(exp(-ALPHA * (K) * (K) / (M * M)),
                    exp(-ALPHA * (K + 1.0f) * (K + 1.0f) / (M * M)),
                    exp(-ALPHA * (K + 2.0f) * (K + 2.0f) / (M * M)),
                    exp(-ALPHA * (K + 3.0f) * (K + 3.0f) / (M * M)));
                float depth = getTextureVal(cubeMap0, uv, filterSize).x,
                sum1 = dot(sin(temp * (objectDepthZ - _CubeBias)) / temp, cosZVal * weights),
                sum2 = dot(cos(temp * (objectDepthZ - _CubeBias)) / temp, sinZVal * weights);
                return 0.5f * depth + 2.0f * (sum1 - sum2);
            }


            float css(
                samplerCUBE cubeMap0,
                samplerCUBE cubeMap1,
                samplerCUBE cubeMap2,
                samplerCUBE cubeMap3,
                samplerCUBE cubeMap4,
                float3 uv,
                float objectDepth
            )
            {
                float objectDepthZ = objectDepth / _CubeFarPlane;
                // Blocker search filter size
                float filterSize = calFilterSize(objectDepth, _CubeNearPlane);
                //filterSize = clamp(filterSize, 0.0f, 2.0f);
                supress_flag = 0.0f;

                if (objectDepthZ > 1.2f)
                    return 0;

                float blockedNum = 1.0f - cssmBasis(cubeMap1, cubeMap2, uv, objectDepthZ, filterSize);

                float blockerDepth;

                if (blockedNum > 0.001f)
                {
                    blockerDepth = cssmBasisZ(cubeMap0,
                        cubeMap3,
                        cubeMap4,
                        uv,
                        objectDepthZ,
                        filterSize) / blockedNum * _CubeFarPlane;
                }
                else
                {
                    blockerDepth = 0.0f;
                }

                if (objectDepth == 0.0f ||
                    blockerDepth >= objectDepth ||
                    blockerDepth == 0.0f
                    )
                    return 1.0f;

                // Penumbral filter size
                float filterSize2 = calFilterSize(objectDepth, blockerDepth);
                supress_flag = 1.0f;

                float shadow;
                shadow = cssmBasis(cubeMap1, cubeMap2, uv, objectDepthZ, filterSize2);
                shadow = pow(shadow, 1.0f + SHADOW_A * exp(SHADOW_B * (blockerDepth - objectDepth)));
                //shadow = pow(shadow, 2);

                return shadow;
            }

            struct appdata
            {
                float4 vertex : POSITION;
                float3 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 normal : TEXCOORD2;
                float3 ldir : POSITION1;
                float3 in_ldir : POSITION2;
                float4 vert : POSITION3;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.normal = v.normal;
                float4 worldVert = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1.0));
                o.ldir = worldVert - _l;

                // o.ldir = mul( _CubeShadowV, mul( unity_ObjectToWorld, v.vertex));
                // o.ldir.z = -o.ldir.z;

                o.in_ldir = _l - worldVert;
                o.vert = v.vertex;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 color = tex2D(_MainTex, i.uv) * _Color;
                float3 ldir = mul(unity_ObjectToWorld, float4(i.vert.xyz, 1.0)) - _l;
                float ld = length(ldir);
                //return texCUBE(_CubeMap1, i.ldir);
                float shadow = 1.0f;
                float diffuse = 1.0f;
                float atten = 1.0f;

                if (_CubeShadow)
                {
                    // shadow = css(_CubeMap0,
                    // _CubeMap1,
                    // _CubeMap2,
                    // _CubeMap3,
                    // _CubeMap4,
                    // i.ldir, length(i.ldir));
                    //
                    shadow = css(_CubeMap0,
                                 _CubeMap1,
                                 _CubeMap2,
                                 _CubeMap3,
                                 _CubeMap4,
                                 ldir, ld);
                    //shadow = pcss(ldir, ld);
                }

                if (_CubeDiffuse)
                {
                    diffuse = _CubeLightBrightness
                              * max(dot(normalize(i.in_ldir), normalize(i.worldNormal)), 0.0f);
                }

                if (_CubeAtten)
                {
                    atten = clamp(1.0f / (0.5f + 0.03f * ld + 0.0022f * ld * ld), 0.0f, 1.0f);
                }

                color.xyz *= _CubeLightColor * atten * diffuse * shadow;
                color *= shadow;
                //color=float4(abs(i.worldNormal),1.0);
                return color;
            }

            ENDCG
        }
    }
}

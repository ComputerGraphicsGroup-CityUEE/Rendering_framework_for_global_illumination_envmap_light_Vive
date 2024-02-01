Shader "Custom/Receiver_PCF"
{
    Properties
    {
        _Color("Color", Color) = (1, 0, 0, 1)
        _Tex("Texture", 2D) = "white" {}
    }

        SubShader
    {
        Tags { "RenderType" = "Opaque" "LightMode" = "ForwardBase" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            #define PI 3.14159265358979
            #define M 4
            #define fCSMBias 0.068
            #define OFFSET 0.02
            #define SCALEFACTOR 1.11
            #define ALPHA 0.06

            float supress_flag = 0.0;

            struct appdata
            {
                float2 uv : TEXCOORD0;
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 bv : TEXCOORD3;
            };

            uniform float4x4 _gWorldToLightCamera;
            uniform sampler2D _gShadowMapTexture0, _gShadowMapTexture1, _gShadowMapTexture2, _gShadowMapTexture3, _gShadowMapTexture4, _gShadowMapTexture5, _gShadowMapTexture6, _gShadowMapTexture7, _gShadowMapTexture8, _gShadowMapTexture9;
            uniform float4 _gShadowMapTexture0_TexelSize;
            uniform float _gShadowStrength;
            uniform float _gShadowBias;
            uniform float3 _l;
            uniform sampler2D _Tex;
            uniform float4 _Tex_ST;
            uniform float farPlane;

            float4 _Color;

            float4 getweights(float alpha, float k, float m)
            {
                float4 weights = float4(
                    exp(-alpha * (k) * (k) / (m * m)),
                    exp(-alpha * (k + 1.0) * (k + 1.0) / (m * m)),
                    exp(-alpha * (k + 2.0) * (k + 2.0) / (m * m)),
                    exp(-alpha * (k + 3.0) * (k + 3.0) / (m * m))
                );
                return weights;
            }

            float estimateFilterWidth(float lightsize, float currentDepth, float blockerDepth)
            {
                float receiver = currentDepth;
                float FilterWidth = (receiver - blockerDepth) * lightsize / (2.0 * currentDepth * blockerDepth);
                return FilterWidth;
            }

            float estimatefwo(float lightsize, float distance, float smpos)
            {
                float aa, bb, cc;
                aa = lightsize / distance;
                bb = lightsize / smpos;

                aa = clamp(aa, 0, 1);
                bb = clamp(bb, 0, 1);
                cc = aa * bb + sqrt((1.0 - aa * aa) * (1.0 - bb * bb));

                return sqrt(1.0 - cc * cc) / (1.0 + cc);
            }

            float fscm2dp(float ws)
            {
                return ws;

                ws = clamp(ws, 0.0, 2.0);
                if (ws < 1.0)
                {
                    ws /= sqrt(ws * ws + 1.0) + 1.0;
                }
                else
                {
                    ws = 2.0 - ws;
                    ws = sqrt(ws * ws + 1.0) - ws;
                }
                return ws;
            }

            float4 f4mipmap2D(sampler2D dpmap, float2 tc, float fs)
            {
                float W0 = float(_gShadowMapTexture0_TexelSize.z);
                float ml = log(W0 * fs) / log(2.0);
                float4 result = tex2Dlod(dpmap, float4(tc * .5 + .5, 0, ml));
                return result;
            }

            float wfunc(float zval, float fs)
            {
                float s0 = sqrt(1.0 - zval * zval) / (1.0 + abs(zval));
                float sb = min((1.0 - s0) / fs, 1.0) * sign(zval);
                return sb * .5 + .5;
            }

            float ufunc(float zval, float fs)
            {
                float2 p = float2(sqrt(1.0 - zval * zval), abs(zval));
                float2 t = float2(2.0 * fs, 1.0 - fs * fs) / (1.0 + fs * fs);
                return max(p.x / (1.0 + p.y) - (p.x * t.y - p.y * t.x) / (1.0 + dot(p, t)), fs);
            }

            float ufunca(float zval, float fs)
            {
                float2 p = float2(abs(zval), sqrt(1.0 - zval * zval));
                float2 t = float2(1.0 - fs * fs, 2.0 * fs) / (1.0 + fs * fs);
                float sina = abs(zval);
                float cosa = sqrt(1.0 - sina * sina);
                float sint = t.y;
                float cost = t.x;
                float s0 = cosa / (1.0 + sina);
                float s1 = (cosa * cost + sina * sint) / (1.0 + cosa * cost - sina * sint);

                if (0.5 - s0 > fs)
                    return abs(s1 - s0);
                else
                    return fs;
            }

            float4 _f4mipmapDPMAP(sampler2D frontface, sampler2D backface, float3 uv, float fs)
            {
                float4 cfront, cback, result;

                // convert the filterwidth from cube to dual paraboloid map
                fs = fscm2dp(fs);

                // convert the direction from cube to dp
                uv = normalize(uv);
                uv.z = -uv.z;

                // dp texture lookup changed
                // fs = ufunc(uv.z, fs);
                // fs = ufunca(uv.z, fs);
                fs = .74 * ufunc(uv.z, fs);
                // fs = .74 * fs;

                float W0 = float(_gShadowMapTexture0_TexelSize.z);
                float ml = log(W0 * fs) / log(2.0);

                float2 tc = float2(uv.x, uv.y) / (1.0 + uv.z);
                cfront = tex2Dlod(frontface, float4(tc * .5 + .5, 0, ml));

                uv.x = -uv.x;
                tc = uv.xy / (1.0 - uv.z);
                cback = tex2Dlod(backface, float4(tc * .5 + .5, 0, ml));

                float resolution = 1.0 / fs;
                float sss = clamp((length(uv.xy) / (1.0 + abs(uv.z)) - 1.0) * resolution + 1.0, 0.0, 1.0) * .5;
                if (uv.z < 0.0)
                    sss = 1.0 - sss;

                return lerp(cback, cfront, wfunc(uv.z, fs));
            }

            float4 f4mipmapDPMAP(sampler2D frontface, sampler2D backface, float3 uv, float fs)
            {
                return _f4mipmapDPMAP(frontface, backface, uv, fs) * 2.0 - 1.0;
            }

            float CSSM_Z_Basis(float3 uv, float currentDepth, float filterwidth, sampler2D dpmap[2 * (M + 1)])
            {
                float4 tmp, sin_val_z, cos_val_z;
                float sum0, sum1;

                float2 ddd = f4mipmapDPMAP(dpmap[0], dpmap[1], uv, filterwidth).xy;
                float sld_angle = ddd.y;
                float depthvalue = ddd.x / sld_angle;

                sin_val_z = f4mipmapDPMAP(dpmap[5], dpmap[5 + M], uv, filterwidth) / sld_angle;
                cos_val_z = f4mipmapDPMAP(dpmap[4], dpmap[4 + M], uv, filterwidth) / sld_angle;

                float k = 1.0;
                tmp = PI * (2.0 * float4(k, k + 1.0, k + 2.0, k + 3.0) - 1.0);

                float4 weights = getweights(ALPHA, k, float(M));

                sum0 = dot(sin(tmp * (currentDepth - fCSMBias)) / tmp, cos_val_z * weights);
                sum1 = dot(cos(tmp * (currentDepth - fCSMBias)) / tmp, sin_val_z * weights);

                return 0.5 * depthvalue + 2.0 * (sum0 - sum1);
            }

            float CSSM_Basis(float3 uv, float currentDepth, float filterwidth, sampler2D dpmap[2 * (M + 1)])
            {
                float4 tmp, sin_val, cos_val;
                float sum0, sum1;

                float sld_angle = f4mipmapDPMAP(dpmap[0], dpmap[1], uv, filterwidth).y;
                sin_val = f4mipmapDPMAP(dpmap[3], dpmap[3 + M], uv, filterwidth) / sld_angle;
                cos_val = f4mipmapDPMAP(dpmap[2], dpmap[2 + M], uv, filterwidth) / sld_angle;

                float k = 1.0;
                tmp = PI * (2.0 * float4(k, k + 1.0, k + 2.0, k + 3.0) - 1.0);

                float4 weights = getweights(ALPHA, k, float(M));

                sum0 = dot(cos(tmp * (currentDepth - fCSMBias)) / tmp, sin_val * weights);
                sum1 = dot(sin(tmp * (currentDepth - fCSMBias)) / tmp, cos_val * weights);

                float rec = 0.5 + 2.0 * (sum0 - sum1);

                if (supress_flag == 1.0)
                    rec = SCALEFACTOR * (rec - OFFSET);

                return clamp((1.0f * rec), 0.0, 1.0);
            }


            float FindBlockDepth(
                float3 uv,
                float currentDepth,
                float distance,
                float lightsize,
                sampler2D dpmap[2 * (M + 1)],
                float zNear,
                float zFar
            ) {
                float fs = estimatefwo(lightsize, distance, zNear);
                fs = clamp(fs, 0.0, 2.0);

                supress_flag = 0.0;
                float blockedNum = 1.0 - CSSM_Basis(uv, currentDepth, fs, dpmap);
                //return blockedNum;

                float Z_avg;
                if (blockedNum > 0.001)
                {
                    Z_avg = CSSM_Z_Basis(uv, currentDepth, fs, dpmap) / blockedNum;
                    return Z_avg * zFar;
                }
                else
                {
                    return 0.0;
                }

            }

            //dual paraboloid map csm pcf filter
            float csm_pcf_filter(
                float3 uv,
                float currentDepth,
                float filterWidth,
                sampler2D dpmap[2 * (M + 1)]
            ) {
                supress_flag = 1.0;
                float shadow = CSSM_Basis(uv, currentDepth, filterWidth, dpmap);
                return shadow;
            }


            float CSM_SoftShadow(
                float3 uv,
                float currentDepth,
                float distance,
                float lightsize,
                sampler2D dpmap[2 * (M + 1)],
                float zNear,
                float zFar,
                float shadow_a,
                float shadow_b
            ) {
                float blockerdepth = FindBlockDepth(uv, currentDepth, distance, lightsize, dpmap, zNear, zFar); //return dp map look up result

                if (distance == 0.0 || blockerdepth >= distance || blockerdepth == 0.0)
                    return 1.0;

                float FilterWidth = estimatefwo(lightsize, distance, blockerdepth);

                float shadow = csm_pcf_filter(uv, currentDepth, FilterWidth, dpmap);

                float temp = shadow_b * (blockerdepth - distance);
                //temp=clamp(temp,0.0,shadow_b);

                float power = 1.0 + shadow_a * exp(temp);

                shadow = pow(shadow, power);

                return shadow;
            }

            float sfunc(float F, float3 v)
            {
                float ll = length(v);
                return ll - 2.0 * F * ll / (ll + v.z) + F;
            }

            v2f vert(appdata v)
            {
                v2f o;

                float4 hp = UnityObjectToClipPos(v.vertex); 
                o.pos = hp;
                o.uv = TRANSFORM_TEX(v.uv, _Tex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.bv = v.vertex.xyz;

                return o;
            }

            //float PCFSample(float depth,float2 uv)
            //{
            //    float shadow = 0.0;
            //    for (int x = -1; x <= 1; ++x)
            //    {
            //        for (int y = -1; y <= 1; ++y)
            //        {
            //            float4 col = tex2D(_gShadowMapTexture0,uv + float2(x,y) * _gShadowMapTexture_TexelSize.xy);
            //            float sampleDepth = DecodeFloatRGBA(col);
            //            shadow += (sampleDepth + _gShadowBias) < depth ? _gShadowStrength : 1;
            //        }
            //    }
            //    return shadow / 9;
            //}


            float4 test(sampler2D dpmap[2 * (M + 1)], float2 frontUV, float2 backUV, float depth)
            {
                    float shadow = 0.0;
                    for (int x = -2; x <= 2; ++x)
                    {
                        for (int y = -2; y <= 2; ++y)
                        {
                            float4 col = min(tex2D(dpmap[0], frontUV + float2(x, y) * _gShadowMapTexture0_TexelSize.xy), tex2D(dpmap[1], backUV + float2(x, y) * _gShadowMapTexture0_TexelSize.xy));
                            float sampleDepth = col.x;
                            shadow += (sampleDepth + _gShadowBias) < depth ? _gShadowStrength : 1;
                        }
                    }
                    return shadow / 25;
            }
            fixed4 frag(v2f i) : SV_Target
            {
                sampler2D dpmap[10] = {_gShadowMapTexture0, _gShadowMapTexture1, _gShadowMapTexture2, _gShadowMapTexture3, _gShadowMapTexture4, _gShadowMapTexture5, _gShadowMapTexture6, _gShadowMapTexture7, _gShadowMapTexture8, _gShadowMapTexture9};

                fixed4 color = tex2D(_Tex, i.uv);

                float3 worldPos = mul(unity_ObjectToWorld, float4(i.bv.xyz, 1.0)).xyz;
                float3 ldir = worldPos - _l;

                float4x4 lightmv = (_gWorldToLightCamera);
                ldir = mul(float4(ldir.xyz, 1), lightmv).xyz;

                float currentDepth = length(ldir);
                float shadow = 0.0;
                float bias = 0;
                float3 uv = normalize(ldir);

                float lightsize = 50.0f;
                float zNear = 0.01f;
                float zFar = farPlane;
                float shadow_a = 25.0;
                float shadow_b = 20.0;

                float closestDepth = 0;
                float offset = 2.0;

                float fs = estimatefwo(lightsize, currentDepth, zNear);
                fs = clamp(fs, 0.0, 2.0);

                float W0 = float(_gShadowMapTexture0_TexelSize.z);

                fs = fscm2dp(fs);
                fs = .74 * ufunc(uv.z, fs);
                float ml = log(W0 * fs) / log(2.0);

                uv = normalize(ldir);
                uv.z = -uv.z;
                float2 front_tc = float2(uv.x, uv.y) / (1.0 + uv.z);
                front_tc = front_tc * 0.5 + 0.5;

                uv.x = -uv.x;
                float2 back_tc = uv.xy / (1.0 - uv.z);
                back_tc = back_tc * 0.5 + 0.5;

                for (float x = -offset; x <= offset; x += 1.0)
                {
                    for (float y = -offset; y <= offset; y += 1.0)
                    {
                        float4 cfront = tex2D(dpmap[0], float2(front_tc + float2(x, y) * _gShadowMapTexture0_TexelSize.xy));
                        float4 cback = tex2D(dpmap[1], float2(back_tc + float2(x, y) * _gShadowMapTexture0_TexelSize.xy));

                        closestDepth = (lerp(cback, cfront, wfunc(uv.z, fs)) * 2.0 - 1.0).r;
                        closestDepth *= zFar;

                        if (currentDepth - bias > closestDepth)
                        {
                            shadow += 1.0;
                        }
                    }
                }

                shadow /= 25.0;
                shadow = 1 - shadow;

                return color * shadow;
            }

            ENDCG
        }
    }
}


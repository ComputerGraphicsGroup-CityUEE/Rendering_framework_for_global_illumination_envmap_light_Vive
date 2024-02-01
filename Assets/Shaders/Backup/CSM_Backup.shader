Shader "Custom/CSM_Backup"
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

            #define PI 3.14159265358979
            #define M 4
            #define fCSMBias 0.068
            #define OFFSET 0.02
            #define SCALEFACTOR 1.11
            #define ALPHA 0.06
            float supress_flag = 0.0;

            uniform float4x4 _gWorldToLightCamera, _gWorldToLightCamera_back;
            uniform sampler2D _gShadowMapTexture0, _gShadowMapTexture1, _gShadowMapTexture2, _gShadowMapTexture3, _gShadowMapTexture4, _gShadowMapTexture5, _gShadowMapTexture6, _gShadowMapTexture7, _gShadowMapTexture8, _gShadowMapTexture9;
            uniform float4 _gShadowMapTexture0_TexelSize;
            uniform float ShadowMapSize;
            uniform float _gShadowStrength;
            uniform float _gShadowBias;
            uniform float lightsize;
            uniform float farPlane;
            uniform float nearPlane;
            uniform float3 _l;
            uniform sampler2D _Tex;
            uniform float4 _Tex_ST;
            uniform float _gLightStrength;
            float4 _Color;

            float4 getweights(float alpha, float k, float m)
            {
                float4 weights = float4(exp(-alpha * (k) * (k) / (m * m)),
                    exp(-alpha * (k + 1.0) * (k + 1.0) / (m * m)),
                    exp(-alpha * (k + 2.0) * (k + 2.0) / (m * m)),
                    exp(-alpha * (k + 3.0) * (k + 3.0) / (m * m)));
                return weights;
            }

            float estimateFilterWidth(float lightsize, float currentDepth, float blockerDepth)
            {
                float receiver = currentDepth;
                float FilterWidth = (receiver - blockerDepth) * lightsize / (2.0f * currentDepth * blockerDepth);
                return FilterWidth;
            }

            float estimatefwo(float lightsize, float distance, float smpos)
            {
                float aa, bb, cc;
                aa = lightsize / distance;
                bb = lightsize / smpos;

                aa = clamp(aa, 0.0f, 1.0f);
                bb = clamp(bb, 0.0f, 1.0f);
                cc = aa * bb + sqrt((1.0f - aa * aa) * (1.0f - bb * bb));
                return sqrt(1.0f - cc * cc) / (1.0f + cc);
            }

            float fscm2dp(float ws)
            {
                ws = clamp(ws, 0.0f, 2.0f);
                if (ws < 1.0f)
                {
                    ws /= sqrt(ws * ws + 1.0f) + 1.0f;
                }
                else
                {
                    ws = 2.0f - ws;
                    ws = sqrt(ws * ws + 1.0f) - ws;
                }
                return ws;
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

            float4 mix(float4 x, float4 y, float a)
            {
                return x * (1 - a) + y * a;
            }

            float4 _f4mipmapDPMAP(sampler2D frontface, sampler2D backface, float3 uv, float fs)
            {
                float4 cfront, cback, result;
                fs = fscm2dp(fs);
                fs = .74 * ufunc(uv.z, fs);
                float W0 = ShadowMapSize * sqrt(3);
                float ml = log(W0 * fs) / log(2.0);
                uv = normalize(uv);
                uv.z = -uv.z;
                float2 front_tc = float2(uv.x, uv.y) / (1.0 + uv.z);
                front_tc = front_tc * 0.5 + 0.5;
                cfront = tex2Dlod(frontface, float4(front_tc, 0, ml));
                uv.x = -uv.x;
                float2 back_tc = uv.xy / (1.0 - uv.z);
                back_tc = back_tc * 0.5 + 0.5;
                cback = tex2Dlod(backface, float4(back_tc, 0, ml));
                float resolution = 1.0 / fs;
                float sss = clamp((length(uv.xy) / (1.0 + abs(uv.z)) - 1.0) * resolution + 1.0, 0.0, 1.0) * .5;
                if (uv.z < 0.0)
                    sss = 1.0 - sss;
                return mix(cback, cfront, wfunc(uv.z, fs));
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
                sum0 = dot(sin(tmp * (currentDepth - _gShadowBias)) / tmp, cos_val_z * weights);
                sum1 = dot(cos(tmp * (currentDepth - _gShadowBias)) / tmp, sin_val_z * weights);

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
                sum0 = dot(cos(tmp * (currentDepth - _gShadowBias)) / tmp, sin_val * weights);
                sum1 = dot(sin(tmp * (currentDepth - _gShadowBias)) / tmp, cos_val * weights);

                float rec = 0.5 + 2.0 * (sum0 - sum1);

                if (supress_flag == 1.0)
                    rec = SCALEFACTOR * (rec - OFFSET);

                return clamp(1.0f * rec, 0.0, 1.0);
            }

            float FindBlockDepth(float3 uv, float currentDepth, float distance, float lightsize, sampler2D dpmap[2 * (M + 1)], float zNear, float zFar)
            {
                float fs = estimatefwo(lightsize, distance, zNear);
                fs = clamp(fs, 0.0, 2.0);

                supress_flag = 0.0;
                float blockedNum = 1.0 - CSSM_Basis(uv, currentDepth, fs, dpmap);

                float Z_avg;
                if (blockedNum > 0.001)
                {
                    Z_avg = CSSM_Z_Basis(uv, currentDepth, fs, dpmap) / blockedNum;
                    return Z_avg * zFar;
                }

                return 0.0;
            }

            float csm_pcf_filter(float3 uv, float currentDepth, float filterWidth, sampler2D dpmap[2 * (M + 1)])
            {
                supress_flag = 1.0;
                float shadow = CSSM_Basis(uv, currentDepth, filterWidth, dpmap);
                return shadow;
            }

            float CSM_SoftShadow(float3 uv, float currentDepth, float distance, float lightsize, sampler2D dpmap[2 * (M + 1)], float zNear, float zFar, float shadow_a, float shadow_b)
            {
                float blockerdepth = FindBlockDepth(uv, currentDepth, distance, lightsize, dpmap, zNear, zFar);

                if (distance == 0.0 || blockerdepth >= distance || blockerdepth == 0.0)
                    return 1.0;

                float FilterWidth = estimatefwo(lightsize, distance, blockerdepth);
                float shadow = csm_pcf_filter(uv, currentDepth, FilterWidth, dpmap);
                float temp = shadow_b * (blockerdepth - distance);
                float power = 1.0 + shadow_a * exp(temp);
                shadow = pow(shadow, power);

                return shadow;
            }

            float sfunc(float F, float3 v)
            {
                float ll = length(v);
                return ll - 2.0 * F * ll / (ll + v.z) + F;
            }

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
                float3 vert : POSITION1;
                float4 bc : TEXCOORD3;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _Tex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.vert = v.vertex;

                float4 hp = mul(_gWorldToLightCamera, mul(unity_ObjectToWorld, v.vertex));
                hp.z = -hp.z;
                o.bc.xyz = v.vertex.xyz;
                o.bc.w = hp.z / hp.w;

                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                sampler2D dpmap[10] =
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

                float4 color = tex2D(_Tex, i.uv);
                float d0, vb, distance;

                float4 worldPos = mul(unity_ObjectToWorld, float4(i.bc.xyz, 1.0));
                float3 ldir = worldPos - _l;
                float dis = length(ldir);

                float4x4 lightmv = _gWorldToLightCamera;
                ldir = mul(float4(ldir.xyz, 1), lightmv).xyz;

                distance = length(ldir);
                float zFar = farPlane;
                float zNear = nearPlane;
                float shadow_a = 25.0;
                float shadow_b = 20.0;
                d0 = length(ldir) / 60;
                vb = CSM_SoftShadow(ldir, d0, distance, lightsize, dpmap, zNear, zFar, shadow_a, shadow_b);

                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLight = normalize(_l - worldPos);
                fixed3 diffuse = _Color * max(dot(worldNormal, worldLight), 0);
                color.rgb *= diffuse;

                return color * vb / (distance * distance) * _gLightStrength;
            }

            ENDCG
        }

    }

}


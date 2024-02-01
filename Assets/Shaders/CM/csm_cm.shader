Shader "Custom/CSM_CM"
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
            #pragma target 5.0
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

            uniform float4x4 _gWorldToLightCamera;
            uniform float ShadowMapSize;
            uniform float _gShadowStrength;
            uniform float _gShadowBias;
            uniform float lightsize;
            uniform float farPlane;
            uniform float nearPlane;
            uniform float3 _l;
            uniform sampler2D _Tex;
            uniform float4 _Tex_ST;
            float4 _Color;
            samplerCUBE _CubeMap0;
            samplerCUBE _CubeMap1;
            samplerCUBE _CubeMap2;
            samplerCUBE _CubeMap3;
            samplerCUBE _CubeMap4;
            uniform float _gLightStrength;

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
                // receiver depth
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

                return sqrt(1.0 / (cc * cc) - 1.0);
            }

            float3 unicube(float3 R)
            {
                float3 T = abs(R);
                R /= max(max(T.x, T.y), T.z);
                R = 6.0 / PI * asin(R / sqrt(R * R * 2.0 + 2.0));
                return R;
            }

            float adjustcmmipmap(float3 l, float fs)
            {
                l = abs(l);
                l /= max(l.x, max(l.y, l.z));

                float3 sina = l;
                float3 cosa = sqrt(1.0 - sina * sina);
                float sint = fs;
                float cost = sqrt(1.0 - sint * sint);
                float3 ss = sina - (sina * cost - cosa * sint);

                if (l.x > l.y && l.x > l.z)
                    return sqrt(ss.y * ss.z);
                else if (l.y > l.z)
                    return sqrt(ss.x * ss.z);
                else
                    return sqrt(ss.x * ss.y);
            }

            float4 _f4mipmapCMMAP(samplerCUBE cmmap, float3 uv, float fs)
            {
                float4 result;

                uv = normalize(uv); // look up vector

                //cubemap mipmap look up
                float W0 = ShadowMapSize;
                float ml = log(W0 * fs) / log(2.0);

                result = texCUBElod(cmmap, float4(uv, ml));

                return result;
            }

            float4 f4mipmapCMMAP(samplerCUBE cmmap, float3 uv, float fs)
            {
                return _f4mipmapCMMAP(cmmap, uv, fs) * 2.0 - 1.0;
            }

            float CSSM_CM_Z_Basis(
                float3 uv,
                float currentDepth,
                float filterwidth,
                samplerCUBE cmmap[M + 1]
            ) {
                float4 tmp, sin_val_z, cos_val_z;
                float sum0, sum1;

                float2 ddd = f4mipmapCMMAP(cmmap[0], uv, filterwidth).xy;  
                float sld_angle = ddd.y;
                float depthvalue = ddd.x / sld_angle;

                sin_val_z = f4mipmapCMMAP(cmmap[4], uv, filterwidth) / sld_angle;
                cos_val_z = f4mipmapCMMAP(cmmap[3], uv, filterwidth) / sld_angle;

                float k = 1.0;

                tmp = PI * (2.0 * float4(k, k + 1.0, k + 2.0, k + 3.0) - 1.0);
                float4 weights = getweights(ALPHA, k, float(M));

                sum0 = dot(sin(tmp * (currentDepth - fCSMBias)) / tmp, cos_val_z * weights);  
                sum1 = dot(cos(tmp * (currentDepth - fCSMBias)) / tmp, sin_val_z * weights);

                return 0.5 * depthvalue + 2.0 * (sum0 - sum1);
            }

            //cube map basis
            float CSSM_CM_Basis(
                float3 uv,
                float currentDepth,
                float filterwidth,
                samplerCUBE cmmap[M + 1]
            ) {
                float4 tmp, sin_val, cos_val;
                float sum0, sum1;

                float sld_angle = f4mipmapCMMAP(cmmap[0], uv, filterwidth).y;

                int i = 0;
                sin_val = f4mipmapCMMAP(cmmap[2], uv, filterwidth) / sld_angle;
                cos_val = f4mipmapCMMAP(cmmap[1], uv, filterwidth) / sld_angle;

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

            //cube map Find block depth
            float FindBlockDepth_CM(
                float3 uv,
                float currentDepth,
                float distance,
                float lightsize,
                samplerCUBE cmmap[M + 1],
                float zNear,
                float zFar
            ) {
                float fs = estimatefwo(lightsize, distance, zNear);

                fs = clamp(fs, 0.0, 2.0);

                supress_flag = 0.0;
                float blockedNum = 1.0 - CSSM_CM_Basis(uv, currentDepth, fs, cmmap);

                float Z_avg;
                if (blockedNum > 0.001)
                {
                    Z_avg = CSSM_CM_Z_Basis(uv, currentDepth, fs, cmmap) / blockedNum;
                    return Z_avg * zFar;
                }
                else
                {
                    return 0.0;
                }

            }

            //cube map csm pcf filter
            float csm_cm_pcf_filter(
                float3 uv,
                float currentDepth,
                float filterWidth,
                samplerCUBE cmmap[M + 1]
            ) {
                supress_flag = 1.0;
                float shadow = CSSM_CM_Basis(uv, currentDepth, filterWidth, cmmap);
                return shadow;
            }


            //cube map soft shadow
            float CSM_CM_SoftShadow(
                float3 uv, float currentDepth, float distance,
                float lightsize, samplerCUBE cmmap[M + 1], float zNear, float zFar,
                float shadow_a, float shadow_b
            ) {
                float blockerdepth = FindBlockDepth_CM(uv, currentDepth, distance, lightsize, cmmap, zNear, zFar);

                if (distance == 0.0 || blockerdepth >= distance || blockerdepth == 0.0)
                    return 1.0;

                float FilterWidth = estimatefwo(lightsize, distance, blockerdepth);

                float shadow = csm_cm_pcf_filter(uv, currentDepth, FilterWidth, cmmap);

                float temp = shadow_b * (blockerdepth - distance);

                float power = 1.0 + shadow_a * exp(temp);

                shadow = pow(shadow, power);

                return shadow;
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
                o.bc = v.vertex;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                samplerCUBE cmmap[5] =
                {
                    _CubeMap0,
                    _CubeMap1,
                    _CubeMap2,
                    _CubeMap3,
                    _CubeMap4
                };

                float4 color = tex2D(_Tex, i.uv);
                float d0, vb, distance;

                float4 worldPos = mul(unity_ObjectToWorld, float4(i.bc.xyz, 1.0));
                float3 ldir = worldPos - _l;
                float dis = length(ldir);

                distance = length(ldir);
                float zFar = farPlane;
                float zNear = nearPlane;
                float shadow_a = 25.0;
                float shadow_b = 20.0;
                d0 = length(ldir) / 60;
                vb = CSM_CM_SoftShadow(ldir, d0, distance, lightsize, cmmap, zNear, zFar, shadow_a, shadow_b);

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


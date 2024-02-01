Shader "Custom/CSM"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _Tex("Texture", 2D) = "white" {}
        _Diffuse("Diffuse",Color) = (1,1,1,1)
        _Specular("Specular",Color) = (1,1,1,1)
        _Gloss("Gloss",Range(0,256)) = 20
    }
        SubShader
    {

        Tags{ "Queue" = "Geometry" "RenderType" = "Opaque" "LightMode" = "ForwardBase" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            //#pragma geometry geom
            #pragma fragment frag

            #include "UnityCG.cginc"

            #define PI 3.14159265358979
            #define M 4
            #define fCSMBias 0.068
            #define OFFSET 0.02
            #define SCALEFACTOR 1.11
            #define ALPHA 0.06
            float supress_flag = 0.0;


            uniform float4x4 _gWorldToLightCamera0, _gWorldToLightCamera_back0;
            uniform float4x4 _gWorldToLightCamera1, _gWorldToLightCamera_back1;
            uniform float4x4 _gWorldToLightCamera2, _gWorldToLightCamera_back2;
            uniform float4x4 _gWorldToLightCamera3, _gWorldToLightCamera_back3;
            uniform float4x4 _gWorldToLightCamera4, _gWorldToLightCamera_back4;
            uniform float4x4 _gWorldToLightCamera5, _gWorldToLightCamera_back5;
            uniform float4x4 _gWorldToLightCamera6, _gWorldToLightCamera_back6;
            uniform float4x4 _gWorldToLightCamera7, _gWorldToLightCamera_back7;
            //uniform sampler2D _gShadowMapTexture0, _gShadowMapTexture1, _gShadowMapTexture2, _gShadowMapTexture3, _gShadowMapTexture4, _gShadowMapTexture5, _gShadowMapTexture6, _gShadowMapTexture7, _gShadowMapTexture8, _gShadowMapTexture9;
            uniform float4 _gShadowMapTexture0_TexelSize;
            uniform float ShadowMapSize;
            uniform float _gShadowStrength;
            uniform float _gShadowBias;
            uniform float lightsize0, lightsize1, lightsize2, lightsize3, lightsize4, lightsize5, lightsize6, lightsize7;
            uniform float farPlane;
            uniform float nearPlane;

            uniform float3 _l0, _l1, _l2, _l3, _l4, _l5, _l6, _l7;

            uniform sampler2D _Tex;
            uniform float4 _Tex_ST;

            float4 _Color;

            fixed4 _Diffuse;
            fixed4 _Specular;
            fixed _Gloss;

            UNITY_DECLARE_TEX2DARRAY(_gShadowMapTextureArray0);
            UNITY_DECLARE_TEX2DARRAY(_gShadowMapTextureArray1);
            UNITY_DECLARE_TEX2DARRAY(_gShadowMapTextureArray2);
            UNITY_DECLARE_TEX2DARRAY(_gShadowMapTextureArray3);
            UNITY_DECLARE_TEX2DARRAY(_gShadowMapTextureArray4);
            UNITY_DECLARE_TEX2DARRAY(_gShadowMapTextureArray5);
            UNITY_DECLARE_TEX2DARRAY(_gShadowMapTextureArray6);
            UNITY_DECLARE_TEX2DARRAY(_gShadowMapTextureArray7);


            float4 getweights(float alpha, float k, float m)
            {
                float4 weights = float4(exp(-alpha * (k) * (k) / (m * m)),
                    exp(-alpha * (k + 1.0) * (k + 1.0) / (m * m)),
                    exp(-alpha * (k + 2.0) * (k + 2.0) / (m * m)),
                    exp(-alpha * (k + 3.0) * (k + 3.0) / (m * m)));
                return weights;
            }

            float estimateFilterWidth(float lightsize, float currentDepth, float blockerDepth)
            {   // receiver depth
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
                //return sqrt(1.0f / (cc*cc) - 1.0f);
                return sqrt(1.0f - cc * cc) / (1.0f + cc);  // DP map filter size
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

            float4 _f4mipmapDPMAP(int dpmap, int layer0, int layer1, float3 uv, float fs)
            {
               

                float4 cfront, cback, result;

                cfront = 0;
                cback = 0;
                //convert the filterwidth from cube to dual paraboloid map
                fs = fscm2dp(fs);


                fs = .74 * ufunc(uv.z, fs);

                float W0 = ShadowMapSize * sqrt(3);
                //float W0 = ShadowMapSize;

                float ml = log(W0 * fs) / log(2.0);

                uv = normalize(uv);
                uv.z = -uv.z;
                float2 front_tc = float2(uv.x, uv.y) / (1.0 + uv.z);
                front_tc = front_tc * 0.5 + 0.5;
                //cfront = tex2Dlod(frontface, float4(front_tc, 0, ml));
                if(dpmap == 0)
                    cfront = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray0, float3(front_tc, layer0), ml);
                else if (dpmap == 1)
                    cfront = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray1, float3(front_tc, layer0), ml);
                else if (dpmap == 2)
                    cfront = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray2, float3(front_tc, layer0), ml);
                else if (dpmap == 3)
                    cfront = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray3, float3(front_tc, layer0), ml);
                else if (dpmap == 4)
                    cfront = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray4, float3(front_tc, layer0), ml);
                else if (dpmap == 5)
                    cfront = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray5, float3(front_tc, layer0), ml);
                else if (dpmap == 6)
                    cfront = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray6, float3(front_tc, layer0), ml);
                else if (dpmap == 7)
                    cfront = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray7, float3(front_tc, layer0), ml);

                uv.x = -uv.x;
                float2 back_tc = uv.xy / (1.0 - uv.z);
                back_tc = back_tc * 0.5 + 0.5;
                //cback = tex2Dlod(backface, float4(back_tc, 0, ml));
                if (dpmap == 0)
                    cback = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray0, float3(back_tc, layer1), ml);
                else if(dpmap == 1)
                    cback = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray1, float3(back_tc, layer1), ml);
                else if (dpmap == 2)
                    cback = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray2, float3(back_tc, layer1), ml);
                else if (dpmap == 3)
                    cback = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray3, float3(back_tc, layer1), ml);
                else if (dpmap == 4)
                    cback = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray4, float3(back_tc, layer1), ml);
                else if (dpmap == 5)
                    cback = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray5, float3(back_tc, layer1), ml);
                else if (dpmap == 6)
                    cback = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray6, float3(back_tc, layer1), ml);
                else if (dpmap == 7)
                    cback = UNITY_SAMPLE_TEX2DARRAY_LOD(_gShadowMapTextureArray7, float3(back_tc, layer1), ml);

                float resolution = 1.0 / fs;
                float sss = clamp((length(uv.xy) / (1.0 + abs(uv.z)) - 1.0) * resolution + 1.0, 0.0, 1.0) * .5;
                if (uv.z < 0.0)
                    sss = 1.0 - sss;


                // delete seams
                // return mix(cfront, cback, sss); 
                // return mix(cfront, cback, sss); 
                return mix(cback, cfront, wfunc(uv.z, fs));
                //return lerp(cback, cfront, wfunc(uv.z, fs));

            }

            float4 f4mipmapDPMAP(int dpmap, int layer0, int layer1, float3 uv, float fs)
            {
                return _f4mipmapDPMAP(dpmap, layer0, layer1, uv, fs) * 2.0 - 1.0;
            }

            float CSSM_Z_Basis(float3 uv, float currentDepth, float filterwidth, int dpmap)
            {
                float4 tmp, sin_val_z, cos_val_z;

                float sum0, sum1;  // = 0.0;

                float2 ddd = f4mipmapDPMAP(dpmap, 0, 1, uv, filterwidth).xy;

                float sld_angle = ddd.y;
                float depthvalue = ddd.x / sld_angle;

                sin_val_z = f4mipmapDPMAP(dpmap, 5, 5 + M, uv, filterwidth) / sld_angle;
                cos_val_z = f4mipmapDPMAP(dpmap, 4, 4 + M, uv, filterwidth) / sld_angle;


                //int k= i*4+1;
                float k = 1.0;

                tmp = PI * (2.0 * float4(k, k + 1.0, k + 2.0, k + 3.0) - 1.0);
                //tmp = PI * float4(k, k + 1.0, k + 2.0, k + 3.0);

                float4 weights = getweights(ALPHA, k, float(M));

                sum0 = dot(sin(tmp * (currentDepth - _gShadowBias)) / tmp, cos_val_z * weights); //+=
                sum1 = dot(cos(tmp * (currentDepth - _gShadowBias)) / tmp, sin_val_z * weights);

                return 0.5 * depthvalue + 2.0 * (sum0 - sum1);
            }


            float CSSM_Basis(
                float3 uv,
                float currentDepth,
                float filterwidth,
                int dpmap
            ) {
                float4 tmp, sin_val, cos_val;

                float sum0, sum1;//= 0.0;


                float sld_angle = f4mipmapDPMAP(dpmap, 0, 1, uv, filterwidth).y;

                sin_val = f4mipmapDPMAP(dpmap, 3, 3 + M, uv, filterwidth) / sld_angle;
                cos_val = f4mipmapDPMAP(dpmap, 2, 2 + M, uv, filterwidth) / sld_angle;

                //int k= i*4+1;
                float k = 1.0;

                //paper ck--wzn 181219
                tmp = PI * (2.0 * float4(k, k + 1.0, k + 2.0, k + 3.0) - 1.0);
                //tmp = PI * float4(k, k + 1.0, k + 2.0, k + 3.0);

                float4 weights = getweights(ALPHA, k, float(M));

                sum0 = dot(cos(tmp * (currentDepth - _gShadowBias)) / tmp, sin_val * weights); //+=
                sum1 = dot(sin(tmp * (currentDepth - _gShadowBias)) / tmp, cos_val * weights);

                float rec = 0.5 + 2.0 * (sum0 - sum1);

                if (supress_flag == 1.0)
                    rec = SCALEFACTOR * (rec - OFFSET);

                return clamp(1.0f * rec, 0.0, 1.0);
            }


            float FindBlockDepth(
                float3 uv,
                float currentDepth,
                float distance,
                float lightsize,
                int dpmap,
                float zNear,
                float zFar
            ) {
                float fs = estimatefwo(lightsize, distance, zNear);
                //if (fs > 0.0)
                //    return 0.0;
                //else
                //    return 1.0;
                //return fs;
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

            //dual paraboloid map csm pcf filter
            float csm_pcf_filter(
                float3 uv,
                float currentDepth,
                float filterWidth,
                int dpmap
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
                int dpmap,
                float zNear,
                float zFar,
                float shadow_a,
                float shadow_b
            ) {

                

                float blockerdepth = FindBlockDepth(uv, currentDepth, distance, lightsize, dpmap, zNear, zFar); //return dp map look up result--wzn181220

                //return blockerdepth;

                if (distance == 0.0 || blockerdepth >= distance || blockerdepth == 0.0)
                    return 1.0;


                //if (distance == 0.0 || blockerdepth < distance || blockerdepth == 0.0)
                //    return 1.0;


                float FilterWidth = estimatefwo(lightsize, distance, blockerdepth);



                float shadow = csm_pcf_filter(uv, currentDepth, FilterWidth, dpmap);

                

                float temp = shadow_b * (blockerdepth - distance);
                //float temp = shadow_b * (distance - blockerdepth);


                //temp=clamp(temp,0.0,shadow_b);

                float power = 1.0 + shadow_a * exp(temp);

                shadow = pow(shadow, power);//

                

                //return 0.0;
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
                //float4 shadowCoord : TEXCOORD0;
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD2;
                float3 vert : POSITION1;
                float3 bc : TEXCOORD3;
            };


            //struct g2f
            //{
            //    //float4 pos : SV_POSITION;
            //    //float3 normal : TEXCOORD0;
            //    float3 normal0 : TEXCOORD4;
            //    float3 normal1 : TEXCOORD5;
            //    float3 normal2 : TEXCOORD6;
            //    float3 vert0 : TEXCOORD7;
            //    float3 vert1 : TEXCOORD8;
            //    float3 vert2 : TEXCOORD9;
            //    //float3 vert : TEXCOORD8;

            //    float2 uv : TEXCOORD0;
            //    float3 worldNormal : TEXCOORD2;
            //    float3 vert : POSITION1;
            //    float4 bc : TEXCOORD3;
            //    float4 pos : SV_POSITION;


            //};


            v2f vert(appdata v)
            {
                
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.uv = TRANSFORM_TEX(v.uv, _Tex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.vert = v.vertex;

                //float4 hp = mul(_gWorldToLightCamera, mul(unity_ObjectToWorld, v.vertex));
                //hp.z = -hp.z;
                o.bc.xyz = v.vertex.xyz;
                //o.bc.w = hp.z / hp.w;

                return o;

            }

            //[maxvertexcount(3)]
            //void geom(triangle v2f IN[3], inout TriangleStream<g2f> triStream)
            //{
            //    g2f o;

            //    // Compute the normal
            //    float3 vecA = IN[1].vert - IN[0].vert;
            //    float3 vecB = IN[2].vert - IN[0].vert;
            //    float3 normal0 = cross(vecA, vecB);
            //    //o.normal0 = normalize(mul(normal0, (float3x3) unity_WorldToObject));
            //    o.normal0 = normalize(IN[0].worldNormal);

            //    // Compute the normal
            //    float3 vecA1 = IN[2].vert - IN[1].vert;
            //    float3 vecB1 = IN[0].vert - IN[1].vert;
            //    float3 normal1 = cross(vecA1, vecB1);
            //    //o.normal1 = normalize(mul(normal1, (float3x3) unity_WorldToObject));
            //    o.normal1 = normalize(IN[1].worldNormal);

            //    // Compute the normal
            //    float3 vecA2 = IN[0].vert - IN[2].vert;
            //    float3 vecB2 = IN[1].vert - IN[2].vert;
            //    float3 normal2 = cross(vecA2, vecB2);
            //    //o.normal2 = normalize(mul(normal2, (float3x3) unity_WorldToObject));
            //    o.normal2 = normalize(IN[2].worldNormal);

            //    o.vert0 = IN[0].vert;
            //    o.vert1 = IN[1].vert;
            //    o.vert2 = IN[2].vert;

            //    

            //    for (int i = 0; i < 3; i++)
            //    {

            //        o.uv = IN[i].uv;
            //        o.worldNormal = IN[i].worldNormal;
            //        o.vert = IN[i].vert;
            //        o.bc = IN[i].bc;
            //        o.pos = IN[i].pos;
            //        triStream.Append(o);

            //    }
            //}

            float3 cal_barycentric_coord(float3 v0, float3 v1, float3 v2, float3 pt)
            {
                float3 pc;
                pc.x = length(cross(v1 - pt, v2 - pt)) / length(cross(v1 - v0, v2 - v0));
                pc.y = length(cross(v2 - pt, v0 - pt)) / length(cross(v2 - v1, v0 - v1));
                pc.z = 1 - pc.x - pc.y;
                return pc;
            }


            float4 frag(v2f i) : SV_Target
            {
                
                float4 color = tex2D(_Tex, i.uv);

                float d0, d1, d2, d3, d4, d5, d6, d7;
                float vb0, vb1, vb2, vb3, vb4, vb5, vb6, vb7;
                float distance0, distance1, distance2, distance3, distance4, distance5, distance6, distance7;

                float4 worldPos = mul(unity_ObjectToWorld, float4(i.bc, 1.0));

                float3 ldir0 = worldPos - _l0;
                float3 ldir1 = worldPos - _l1;
                float3 ldir2 = worldPos - _l2;
                float3 ldir3 = worldPos - _l3;
                float3 ldir4 = worldPos - _l4;
                float3 ldir5 = worldPos - _l5;
                float3 ldir6 = worldPos - _l6;
                float3 ldir7 = worldPos - _l7;

                float dis0 = length(ldir0);
                float dis1 = length(ldir1);
                float dis2 = length(ldir2);
                float dis3 = length(ldir3);
                float dis4 = length(ldir4);
                float dis5 = length(ldir5);
                float dis6 = length(ldir6);
                float dis7 = length(ldir7);


                float4x4 lightmv0 = _gWorldToLightCamera0;
                ldir0 = mul(float4(ldir0.xyz, 1), lightmv0).xyz;

                float4x4 lightmv1 = _gWorldToLightCamera1;
                ldir1 = mul(float4(ldir1.xyz, 1), lightmv1).xyz;

                float4x4 lightmv2 = _gWorldToLightCamera2;
                ldir2 = mul(float4(ldir2.xyz, 1), lightmv2).xyz;

                float4x4 lightmv3 = _gWorldToLightCamera3;
                ldir3 = mul(float4(ldir3.xyz, 1), lightmv3).xyz;

                float4x4 lightmv4 = _gWorldToLightCamera4;
                ldir4 = mul(float4(ldir4.xyz, 1), lightmv4).xyz;

                float4x4 lightmv5 = _gWorldToLightCamera5;
                ldir5 = mul(float4(ldir5.xyz, 1), lightmv5).xyz;

                float4x4 lightmv6 = _gWorldToLightCamera6;
                ldir6 = mul(float4(ldir6.xyz, 1), lightmv6).xyz;

                float4x4 lightmv7 = _gWorldToLightCamera7;
                ldir7 = mul(float4(ldir7.xyz, 1), lightmv7).xyz;

                distance0 = length(ldir0);
                distance1 = length(ldir1);
                distance2 = length(ldir2);
                distance3 = length(ldir3);
                distance4 = length(ldir4);
                distance5 = length(ldir5);
                distance6 = length(ldir6);
                distance7 = length(ldir7);
                
                float zFar = farPlane;
                float zNear = nearPlane;
                float shadow_a = 25.0;
                float shadow_b = 20.0;

                d0 = length(ldir0) / zFar;
                d1 = length(ldir1) / zFar;
                d2 = length(ldir2) / zFar;
                d3 = length(ldir3) / zFar;
                d4 = length(ldir4) / zFar;
                d5 = length(ldir5) / zFar;
                d6 = length(ldir6) / zFar;
                d7 = length(ldir7) / zFar;
                

                vb0 = CSM_SoftShadow(ldir0, d0, distance0, lightsize0, 0, zNear, zFar, shadow_a, shadow_b);
                vb1 = CSM_SoftShadow(ldir1, d1, distance1, lightsize1, 1, zNear, zFar, shadow_a, shadow_b);
                vb2 = CSM_SoftShadow(ldir2, d2, distance2, lightsize2, 2, zNear, zFar, shadow_a, shadow_b);
                vb3 = CSM_SoftShadow(ldir3, d3, distance3, lightsize3, 3, zNear, zFar, shadow_a, shadow_b);
                vb4 = CSM_SoftShadow(ldir4, d4, distance4, lightsize4, 4, zNear, zFar, shadow_a, shadow_b);
                vb5 = CSM_SoftShadow(ldir5, d5, distance5, lightsize5, 5, zNear, zFar, shadow_a, shadow_b);
                vb6 = CSM_SoftShadow(ldir6, d6, distance6, lightsize6, 6, zNear, zFar, shadow_a, shadow_b);
                vb7 = CSM_SoftShadow(ldir7, d7, distance7, lightsize7, 7, zNear, zFar, shadow_a, shadow_b);



                fixed3 worldNormal = normalize(i.worldNormal);

                fixed3 worldLight0 = _l0 - worldPos;
                fixed3 worldLight1 = _l1 - worldPos;
                fixed3 worldLight2 = _l2 - worldPos;
                fixed3 worldLight3 = _l3 - worldPos;
                fixed3 worldLight4 = _l4 - worldPos;
                fixed3 worldLight5 = _l5 - worldPos;
                fixed3 worldLight6 = _l6 - worldPos;
                fixed3 worldLight7 = _l7 - worldPos;
     
                float3 tmple0 =  float3(653.766846, 500.968536, 463.145081);
                float3 tmple1 =  float3(435.257538, 358.090302, 370.116486);
                float3 tmple2 =  float3(1013.427795, 751.373474, 561.850891);
                float3 tmple3 =  float3(934.985596, 643.564941, 473.207184);
                float3 tmple4 =  float3(1049.918091, 744.753113, 594.493042);
                float3 tmple5 =  float3(53.823242, 32.297832, 25.698626);
                float3 tmple6 =  float3(459.423737, 310.439880, 262.451355);
                float3 tmple7 =  float3(45.370766, 28.192625, 22.930178);

                fixed3 diffuse0 = saturate(dot(worldNormal, worldLight0)) * _Color;
                fixed3 diffuse1 = saturate(dot(worldNormal, worldLight1)) * _Color;
                fixed3 diffuse2 = saturate(dot(worldNormal, worldLight2)) * _Color;
                fixed3 diffuse3 = saturate(dot(worldNormal, worldLight3)) * _Color;
                fixed3 diffuse4 = saturate(dot(worldNormal, worldLight4)) * _Color;
                fixed3 diffuse5 = saturate(dot(worldNormal, worldLight5)) * _Color;
                fixed3 diffuse6 = saturate(dot(worldNormal, worldLight6)) * _Color;
                fixed3 diffuse7 = saturate(dot(worldNormal, worldLight7)) * _Color;

                fixed3 reflectDir0 = normalize(reflect(-worldLight0, i.worldNormal));
                fixed3 reflectDir1 = normalize(reflect(-worldLight1, i.worldNormal));
                fixed3 reflectDir2 = normalize(reflect(-worldLight2, i.worldNormal));
                fixed3 reflectDir3 = normalize(reflect(-worldLight3, i.worldNormal));
                fixed3 reflectDir4 = normalize(reflect(-worldLight4, i.worldNormal));
                fixed3 reflectDir5 = normalize(reflect(-worldLight5, i.worldNormal));
                fixed3 reflectDir6 = normalize(reflect(-worldLight6, i.worldNormal));
                fixed3 reflectDir7 = normalize(reflect(-worldLight7, i.worldNormal));

                fixed3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);

                fixed3 specular0 = _Color.rgb * _Specular
                    * pow(saturate(dot(viewDir, reflectDir0)), _Gloss);
                fixed3 specular1 = _Color.rgb * _Specular
                    * pow(saturate(dot(viewDir, reflectDir1)), _Gloss);
                fixed3 specular2 = _Color.rgb * _Specular
                    * pow(saturate(dot(viewDir, reflectDir2)), _Gloss);
                fixed3 specular3 = _Color.rgb * _Specular
                    * pow(saturate(dot(viewDir, reflectDir3)), _Gloss);
                fixed3 specular4 = _Color.rgb * _Specular
                    * pow(saturate(dot(viewDir, reflectDir4)), _Gloss);
                fixed3 specular5 = _Color.rgb * _Specular
                    * pow(saturate(dot(viewDir, reflectDir5)), _Gloss);
                fixed3 specular6 = _Color.rgb * _Specular
                    * pow(saturate(dot(viewDir, reflectDir6)), _Gloss);
                fixed3 specular7 = _Color.rgb * _Specular
                    * pow(saturate(dot(viewDir, reflectDir7)), _Gloss);
        





                fixed4 color0 = fixed4(tmple0, 1) * fixed4(diffuse0 + specular0, 1) * vb0 * 0.001 / (distance0 * distance0) * 5;
                fixed4 color1 = fixed4(tmple1, 1) * fixed4(diffuse1 + specular1, 1) * vb1 * 0.001 / (distance1 * distance1) * 5;
                fixed4 color2 = fixed4(tmple2, 1) * fixed4(diffuse2 + specular2, 1) * vb2 * 0.001 / (distance2 * distance2) * 5;
                fixed4 color3 = fixed4(tmple3, 1) * fixed4(diffuse3 + specular3, 1) * vb3 * 0.001 / (distance3 * distance3) * 5;
                fixed4 color4 = fixed4(tmple4, 1) * fixed4(diffuse4 + specular4, 1) * vb4 * 0.001 / (distance4 * distance4) * 5;
                fixed4 color5 = fixed4(tmple5, 1) * fixed4(diffuse5 + specular5, 1) * vb5 * 0.001 / (distance5 * distance5) * 5;
                fixed4 color6 = fixed4(tmple6, 1) * fixed4(diffuse6 + specular6, 1) * vb6 * 0.001 / (distance6 * distance6) * 5;
                fixed4 color7 = fixed4(tmple7, 1) * fixed4(diffuse7 + specular7, 1) * vb7 * 0.001 / (distance7 * distance7) * 5;


                return color * (color0 + color1 + color2 + color3 + color4 + color5 + color6 + color7) ;
                //return color * (color0);




            }
            ENDCG
        }

    }

}


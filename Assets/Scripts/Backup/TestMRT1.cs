using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Profiling;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class TestMRT1 : MonoBehaviour
{
    [Range(0, 9)] public int debug = 0;
    public float zFar = 10f;
    public float zNear = 0.01f;
    [Range(0f, 30f)] public float lightsize = 10f;
    [Range(-1f, 1f)] public float Bias = 0.005f;
    [Range(0, 0.5f)] public float CutOff = 0.1f;
    public int ShadowMapSize = 1024;
    public bool control = false;

    private Color[] backgroundColors =
    {
        new (1f,1f,1f,1f),
        new (0f,0f,0f,0f),
        new (0.5f,0.5f,0.5f,0.5f),
        new (0f,0f,0f,0f),
        new (0.5f,0.5f,0.5f,0.5f)
    };

    private RenderTexture[][] rts =
    {
        new RenderTexture[5],
        new RenderTexture[5]
    };
    private RenderBuffer[][] rbs =
    {
        new RenderBuffer[5],
        new RenderBuffer[5]
    };

    private GameObject[] Cameras = new GameObject[2];
    private Camera[] cameras = new Camera[2];
    public Shader shader;

    void CreateRTRB(RenderTexture[] rts, RenderBuffer[] rbs, RenderTextureDescriptor rtd)
    {
        for (int i = 0; i < 5; i++)
        {
            rts[i] = RenderTexture.GetTemporary(rtd);
            rts[i].wrapMode = TextureWrapMode.Clamp;
            rts[i].filterMode = FilterMode.Trilinear;
            rbs[i] = rts[i].colorBuffer;
        }
    }

    void DestroyRT(RenderTexture[] rts)
    {
        for (int i = 0; i < 5; i++)
        {
            RenderTexture.ReleaseTemporary(rts[i]);
        }
    }

    private void CreateCameras()
    {
        for (int i = 0; i < 2; i++)
        {

            Cameras[i] = new GameObject("Camera" + i);
            Cameras[i].transform.SetParent(transform);
            Cameras[i].AddComponent<Camera>();
            //Cameras[i].AddComponent<Shader>();
            Camera camera = Cameras[i].GetComponent<Camera>();
            camera.orthographic = true;
            camera.nearClipPlane = zNear;
            camera.farClipPlane = 10f;
            camera.fieldOfView = 180;
            camera.transform.localPosition = Vector3.zero;
            camera.aspect = 1.0f;

            camera.depthTextureMode = DepthTextureMode.Depth;
            camera.clearFlags = CameraClearFlags.Nothing;
            camera.renderingPath = RenderingPath.Forward;
        }
    }

    private bool needCreate()
    {
        bool isMissing = false;
        for (int i = 0; i < 2; i++)
        {
            if (transform.Find("Camera" + i) != null)
            {
                Cameras[i] = transform.Find("Camera" + i).gameObject;
            }
            else
            {
                isMissing = true;
                break;
            }
        }

        if (isMissing)
        {
            while (true)
            {
                if (transform.childCount != 0)
                    DestroyImmediate(transform.GetChild(0).gameObject);
                else
                    break;
            }

        }
        return isMissing;
    }
    void Start()
    {
        RenderTextureDescriptor rtd = new RenderTextureDescriptor(ShadowMapSize, ShadowMapSize,
            RenderTextureFormat.ARGB32);
        rtd.useMipMap = true;
        rtd.dimension = TextureDimension.Tex2D;


        if (needCreate()) CreateCameras();

        for (int i = 0; i < 2; i++)
        {
            cameras[i] = Cameras[i].GetComponent<Camera>();
            CreateRTRB(rts[i], rbs[i], rtd);
        }

    }

    private void OnDestroy()
    {
        for (int i = 0; i < 2; i++)
        {
            DestroyRT(rts[i]);
        }
    }
    void Update()
    {

        for (int i = 0; i < 2; i++)
        {
            for (int j = 0; j < 5; j++)
            {
                RenderTexture.active = rts[i][j];
                GL.Clear(false, true, backgroundColors[j]);
            }

            cameras[i].farClipPlane = zFar;
            cameras[i].nearClipPlane = zNear;
            cameras[i].SetTargetBuffers(rbs[i], rts[i][0].depthBuffer);
            cameras[i].SetReplacementShader(shader, null);
            cameras[i].Render();


            // Camera camera = cameras[i].GetComponent<Camera>();
            // camera.depthTextureMode = DepthTextureMode.Depth;
            // camera.renderingPath = RenderingPath.Forward;

        }

        int index = 0;
        for (int i = 0; i < 2; i++)
            for (int j = 0; j < 5; j++)
                Shader.SetGlobalTexture("_gShadowMapTexture" + (++index), rts[i][j]);


        Shader.SetGlobalInt("Debug", debug);
        Shader.SetGlobalFloat("ShadowMapSize", ShadowMapSize);
        Shader.SetGlobalFloat("_gShadowBias", Bias);
        Shader.SetGlobalFloat("_clipValue", CutOff);
        Shader.SetGlobalFloat("farPlane", zFar);
        if (control)
            Shader.SetGlobalFloat("lightsize", lightsize);
        Shader.SetGlobalVector("_l", transform.position);
        Shader.SetGlobalMatrix("_gWorldToLightCamera", cameras[0].worldToCameraMatrix); //当前片段从世界坐标转换到光源相机空间坐标
        Shader.SetGlobalMatrix("_gWorldToLightCamera_back", cameras[1].worldToCameraMatrix); //当前片段从世界坐标转换到光源相机空间坐标

        Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(cameras[0].projectionMatrix, true);
        Matrix4x4 projectionMatrix_back = GL.GetGPUProjectionMatrix(cameras[1].projectionMatrix, true);

        Shader.SetGlobalMatrix("_gProjectionMatrix", projectionMatrix * cameras[0].worldToCameraMatrix);
        Shader.SetGlobalMatrix("_gProjectionMatrix_back", projectionMatrix_back * cameras[1].worldToCameraMatrix);
    }

}
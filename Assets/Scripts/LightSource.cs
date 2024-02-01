using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteInEditMode]
public class LightSource : MonoBehaviour
{
    [Range(0, 9)] public int debug = 0;
    public float zFar = 10f;
    public float zNear = 0.01f;
    [Range(0f, 30f)] public float lightsize = 10f;
    [Range(-1f, 1f)] public float Bias = 0.005f;
    [Range(0, 0.5f)] public float CutOff = 0.1f;
    public int ShadowMapSize = 1024;
    public Shader[] Shaders = new Shader[10];
    public GameObject[] Cameras = new GameObject[10];
    private Camera[] cameras = new Camera[10];
    private RenderTextureDescriptor rtd;
    public RenderTexture[] tempRts = new RenderTexture[10];

    public bool control = false;

    private Color[] backgroundColors =
    {
        new(1f, 1f, 1f, 1f),
        new(1f, 1f, 1f, 1f),
        new(0f, 0f, 0f, 0f),
        new(0.5f, 0.5f, 0.5f, 0.5f),
        new(0f, 0f, 0f, 0f),
        new(0.5f, 0.5f, 0.5f, 0.5f),
        new(0f, 0f, 0f, 0f),
        new(0.5f, 0.5f, 0.5f, 0.5f),
        new(0f, 0f, 0f, 0f),
        new(0.5f, 0.5f, 0.5f, 0.5f)
    };

    private void CreateCameras()
    {
        for (int i = 0; i < 10; i++)
        {
            Cameras[i] = new GameObject("Camera" + i);
            Cameras[i].transform.SetParent(transform);
            Cameras[i].AddComponent<Camera>();
            Camera camera = Cameras[i].GetComponent<Camera>();
            camera.orthographic = true;
            camera.nearClipPlane = zNear;
            camera.farClipPlane = 10f;
            camera.fieldOfView = 180;
            camera.transform.localPosition = Vector3.zero;
            camera.aspect = 1.0f;

            camera.depthTextureMode = DepthTextureMode.Depth;
            camera.clearFlags = CameraClearFlags.Skybox;
            camera.renderingPath = RenderingPath.Forward;

        }
    }

    private bool needCreate()
    {
        bool isMissing = false;
        for (int i = 0; i < 10; i++)
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
        //if (needCreate()) CreateCameras();
        for (int i = 0; i < 10; i++)
        {
            cameras[i] = Cameras[i].GetComponent<Camera>();
        }
        
    }

    void Update()
    {
        rtd = new RenderTextureDescriptor(ShadowMapSize, ShadowMapSize,
            RenderTextureFormat.ARGB32);
        rtd.useMipMap = true;

        for (int i = 0; i < 10; i++)
        {
            //RenderTexture.ReleaseTemporary(tempRts[i]);
            //tempRts[i] = RenderTexture.GetTemporary(rtd);
            tempRts[i].wrapMode = TextureWrapMode.Clamp;
            tempRts[i].filterMode = FilterMode.Trilinear;
            cameras[i].nearClipPlane = zNear;
            cameras[i].farClipPlane = zFar;
            cameras[i].backgroundColor = backgroundColors[i];
            cameras[i].Render();
            cameras[i].targetTexture = tempRts[i];
            cameras[i].SetReplacementShader(Shaders[i], null);
            Shader.SetGlobalTexture("_gShadowMapTexture" + i, tempRts[i]);

            Camera camera = cameras[i].GetComponent<Camera>();
            camera.depthTextureMode = DepthTextureMode.Depth;
            camera.renderingPath = RenderingPath.Forward;

        }

        Shader.SetGlobalInt("Debug", debug);
        Shader.SetGlobalFloat("ShadowMapSize", ShadowMapSize);
        Shader.SetGlobalFloat("_gShadowBias", Bias);
        Shader.SetGlobalFloat("_clipValue", CutOff);
        Shader.SetGlobalFloat("farPlane", zFar);
        if(control)
            Shader.SetGlobalFloat("lightsize", lightsize);
        Shader.SetGlobalVector("_l", transform.position);
        Shader.SetGlobalMatrix("_gWorldToLightCamera", cameras[0].worldToCameraMatrix); 
        Shader.SetGlobalMatrix("_gWorldToLightCamera_back", cameras[1].worldToCameraMatrix); 

        Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(cameras[0].projectionMatrix, true);
        Matrix4x4 projectionMatrix_back = GL.GetGPUProjectionMatrix(cameras[1].projectionMatrix, true);

        Shader.SetGlobalMatrix("_gProjectionMatrix", projectionMatrix * cameras[0].worldToCameraMatrix); 
        Shader.SetGlobalMatrix("_gProjectionMatrix_back", projectionMatrix_back * cameras[1].worldToCameraMatrix);

        //Debug.Log(cameras[0].worldToCameraMatrix);

    }
}

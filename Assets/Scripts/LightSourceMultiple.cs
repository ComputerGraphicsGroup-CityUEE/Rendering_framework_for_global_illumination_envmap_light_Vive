using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class LightSourceMultiple : MonoBehaviour
{
    public int LightIndex = 0;
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

    //public RenderTexture tempRts;
    public Texture2DArray textureArray;


    


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
            //Cameras[i].AddComponent<Shader>();
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

    // Start is called before the first frame update
    void Start()
    {

        //if (needCreate()) CreateCameras();
        for (int i = 0; i < 2; i++)
        {
            cameras[i] = Cameras[i].GetComponent<Camera>();
        }


        //for (int i = 0; i < 10; i++)
        //{
        //    tempRts[i].width = ShadowMapSize;
        //    tempRts[i].height = ShadowMapSize;
        //}

        //tempRts = new RenderTexture(ShadowMapSize, ShadowMapSize, 0, RenderTextureFormat.ARGB32);
        //tempRts.volumeDepth = 10;
        //tempRts.dimension = UnityEngine.Rendering.TextureDimension.Tex2DArray;
        //tempRts.useMipMap = true;
        //tempRts.autoGenerateMips = true;
        //tempRts.wrapMode = TextureWrapMode.Clamp;
        //tempRts.filterMode = FilterMode.Trilinear;
        //tempRts.enableRandomWrite = true;
        //tempRts.Create();



        textureArray = new Texture2DArray(ShadowMapSize, ShadowMapSize, 10, TextureFormat.ARGB32, true);
        //textureArray.useMipMap = true;
        //textureArray.autoGenerateMips = true;
        textureArray.wrapMode = TextureWrapMode.Clamp;
        textureArray.filterMode = FilterMode.Trilinear;




    }

    private void Awake()
    {
        Application.targetFrameRate = -1;
    }


    void Update()
    {

        /*        rtd = new RenderTextureDescriptor(ShadowMapSize, ShadowMapSize,
                    RenderTextureFormat.ARGB32);
                rtd.useMipMap = true;*/


        //Shader.SetGlobalTexture("_gShadowMapTextureArray_RT", tempRts);

        Shader.SetGlobalTexture("_gShadowMapTextureArray" + LightIndex, textureArray);
        //for (int i = 0; i < 2; i++)
        //{
        //    cameras[i].nearClipPlane = zNear;
        //    cameras[i].farClipPlane = zFar;

        //    for (int j = 0; j < 5; j++)
        //    {
        //        cameras[i].backgroundColor = backgroundColors[i * 5 + j];
        //        cameras[i].SetReplacementShader(Shaders[i * 5 + j], null);
        //        cameras[i].targetTexture = tempRts;
        //        CommandBuffer cb = new CommandBuffer();
        //        cb.SetRenderTarget(tempRts, 0, CubemapFace.Unknown, i);
        //        cameras[i].AddCommandBuffer(CameraEvent.BeforeForwardAlpha, cb);
        //        cameras[i].Render();


        //    }


        //}

        for (int i = 0; i < 2; i++)
        {
            cameras[i].nearClipPlane = zNear;
            cameras[i].farClipPlane = zFar;

            for (int j = 0; j < 5; j++)
            {
                cameras[i].backgroundColor = backgroundColors[i * 5 + j];
                cameras[i].SetReplacementShader(Shaders[i * 5 + j], null);
                cameras[i].targetTexture = tempRts[i * 5 + j];
                cameras[i].Render();


                for (int k = 0; k < tempRts[i * 5 + j].mipmapCount; k++)
                    Graphics.CopyTexture(tempRts[i * 5 + j], 0, k, textureArray, i * 5 + j, k);
            }


        }


        Shader.SetGlobalInt("Debug", debug);
        Shader.SetGlobalFloat("ShadowMapSize", ShadowMapSize);
        Shader.SetGlobalFloat("_gShadowBias", Bias);
        Shader.SetGlobalFloat("_clipValue", CutOff);
        Shader.SetGlobalFloat("farPlane", zFar);
        if(control)
        {
            Shader.SetGlobalFloat("lightsize" + LightIndex, lightsize);
        }
            
        Shader.SetGlobalVector("_l" + LightIndex, transform.position);
        Shader.SetGlobalMatrix("_gWorldToLightCamera" + LightIndex, cameras[0].worldToCameraMatrix); 
        Shader.SetGlobalMatrix("_gWorldToLightCamera_back" + LightIndex, cameras[1].worldToCameraMatrix); 

        Shader.SetGlobalInt("_index", debug);
    }
}

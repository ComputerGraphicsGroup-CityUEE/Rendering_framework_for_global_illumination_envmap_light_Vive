using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class PointLight2 : MonoBehaviour
{
    public bool DebugMode = false;
    [Range(-1f, 1f)] public float ALPHA = 0.06f;
    [Range(-4f, 4f)] public float K = 1.0f;
    [Range(-50f, 50f)] public float M = 4.0f;
    [Range(-0.1f, 0.1f)] public float OFFSET = 0.02f;
    [Range(0, 4f)] public float SCALEFACTOR = 1.11f;
    [Range(-50f, 50f)] public float SHADOW_A = 20f;
    [Range(-50f, 2000f)] public float SHADOW_B = 25f;
    [Range(0, 4)] public int CubeMapIndex = 0;
    public bool CutCorner = true;
    public bool Diffuse = true;
    public bool Atten = true;
    public bool Shadow = true;
    [SerializeField] public float NearPlane = 0.3f;
    [SerializeField] public float FarPlane = 20;
    [SerializeField] public int ShadowMapSize = 128;
    [Range(0.01f, 2f)] public float LightSize = 0.005f;
    [Range(0, 0.2f)] public float bias = 0.005f;
    [Range(0, 5.0f)] public float Brightness = 1f;
    public Color LightColor = Color.white;
    private bool isOrthographic = false;
    private int FieldOfView = 60;
    private GameObject[] Cameras = new GameObject[5];
    public Shader[] Shaders = new Shader[5];
    private Camera[] cameras = new Camera[5];
    private RenderTexture tempRt;
    private Color[] backgroundColors =
    {
        new (1f,1f,1f,1f),
        new (0f,0f,0f,0f),
        new (0.5f,0.5f,0.5f,0.5f),
        new (0f,0f,0f,0f),
        new (0.5f,0.5f,0.5f,0.5f)
    };
    private RenderTextureDescriptor rtd;
    private RenderTexture[] tempRts = new RenderTexture[5];

    private void CreateCameras()
    {
        for (int i = 0; i < 5; i++)
        {
            Cameras[i] = new GameObject("Camera" + i);
            Cameras[i].transform.SetParent(transform);
            Cameras[i].AddComponent<Camera>();
            Camera camera = Cameras[i].GetComponent<Camera>();
            camera.orthographic = isOrthographic;
            camera.nearClipPlane = NearPlane;
            camera.farClipPlane = FarPlane;
            camera.fieldOfView = FieldOfView;
            camera.transform.localPosition = Vector3.zero;
            camera.aspect = 1.0f;
        }
    }

    private bool needCreate()
    {
        bool isMissing = false;
        for (int i = 0; i < 5; i++)
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
        if (needCreate()) CreateCameras();
        for (int i = 0; i < 5; i++)
        {
            cameras[i] = Cameras[i].GetComponent<Camera>();
        }
    }

    void OnDrawGizmos()
    {
        if (DebugMode)
        {
            Gizmos.color = Color.red;
            Gizmos.DrawSphere(transform.position, FarPlane);
        }
    }

    private void OnDestroy()
    {
        for (int i = 0; i < 5; i++) RenderTexture.ReleaseTemporary(tempRts[i]);
    }

    void Update()
    {
        rtd = new RenderTextureDescriptor(ShadowMapSize, ShadowMapSize,
            RenderTextureFormat.ARGB32);
        rtd.useMipMap = true;
        rtd.dimension = TextureDimension.Cube;

        for (int i = 0; i < 5; i++)
        {
            RenderTexture.ReleaseTemporary(tempRts[i]);
            tempRts[i] = RenderTexture.GetTemporary(rtd);
            tempRts[i].wrapMode = TextureWrapMode.Clamp;
            tempRts[i].filterMode = FilterMode.Trilinear;
            cameras[i].nearClipPlane = NearPlane;
            cameras[i].farClipPlane = FarPlane;
            cameras[i].backgroundColor = backgroundColors[i];
            cameras[i].RenderToCubemap(tempRts[i], 63);
            cameras[i].SetReplacementShader(Shaders[i], null);
            Shader.SetGlobalTexture("_CubeMap" + i, tempRts[i]);
        }

        Shader.SetGlobalInt("_CubeCutCorner", CutCorner ? 1 : 0);
        Shader.SetGlobalMatrix("_CubeShadowV", transform.worldToLocalMatrix);
        Shader.SetGlobalVector("_l", transform.position);
        Shader.SetGlobalFloat("_CubeBias", bias);
        Shader.SetGlobalFloat("_CubeNearPlane", NearPlane);
        Shader.SetGlobalFloat("_CubeFarPlane", FarPlane);
        Shader.SetGlobalFloat("_CubeLightBrightness", Brightness);
        Shader.SetGlobalFloat("_CubeLightSize", LightSize);
        Shader.SetGlobalInt("_CubeMapSize", ShadowMapSize);
        Shader.SetGlobalInt("_CubeDiffuse", Diffuse ? 1 : 0);
        Shader.SetGlobalInt("_CubeAtten", Atten ? 1 : 0);
        Shader.SetGlobalInt("_CubeShadow", Shadow ? 1 : 0);
        Shader.SetGlobalColor("_CubeLightColor", LightColor);
        Shader.SetGlobalInt("_CubeMapIndex", CubeMapIndex);
        Shader.SetGlobalFloat("ALPHA", ALPHA);
        Shader.SetGlobalFloat("M", M);
        Shader.SetGlobalFloat("K", K);
        Shader.SetGlobalFloat("OFFSET", OFFSET);
        Shader.SetGlobalFloat("SCALEFACTOR", SCALEFACTOR);
        Shader.SetGlobalFloat("SHADOW_A", SHADOW_A);
        Shader.SetGlobalFloat("SHADOW_B", SHADOW_B);
        Shader.SetGlobalMatrix("_gWorldToLightCamera", cameras[0].worldToCameraMatrix);
    }
}

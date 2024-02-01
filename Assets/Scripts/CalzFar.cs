using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CalzFar : MonoBehaviour
{
    public LightSourceMultiple[] light;
    // Start is called before the first frame update
    void Start()
    {
        for(int i=0;i<light.Length;i++)
        {
            light[i].transform.position *= 10;
            float temp = calzFar(light[i].transform.position);
            Debug.Log(temp);
            light[i].zFar = temp;

        }
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    float vdot(Vector3 a, Vector3 b)
    {
      return a.x* b.x + a.y* b.y + a.z* b.z;
    }

    float norm(Vector3 temp) 
    {
      return Mathf.Sqrt(vdot(temp, temp) );
    }

    float g_signf(float f) 
    { 
        return f>0 ? 1 : -1; 
    }

    float calzFar(Vector3 lightpos)
    {
        Vector3 farCorner;

        farCorner = new Vector3(-g_signf(lightpos.x), -g_signf(lightpos.y), -g_signf(lightpos.z));
        return norm(farCorner - lightpos);
        
    }
}

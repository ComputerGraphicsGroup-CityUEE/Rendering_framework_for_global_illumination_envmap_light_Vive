using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TimeStop_Record : MonoBehaviour
{
    public float temp = 10f;
    public AnimationChange animationChange;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (temp > 0f)
            temp -= 1f;
        else
        {
            //Time.timeScale = 0.0f;
            animationChange.flag = 1;
            animationChange.AnimationOff();
            //animationChange.hint.Show("Animation Change");
        }
    }
}

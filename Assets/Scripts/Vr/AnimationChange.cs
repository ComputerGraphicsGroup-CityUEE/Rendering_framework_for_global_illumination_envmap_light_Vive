/*
This script is used to implement VR interaction(set the light strength to a low value using the controller button).
*/

using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class AnimationChange : MonoBehaviour
{
    public int flag = 0;
    public Animator[] animators;
    //float temp = 1f;

    private void Awake()
    {

    }


    void Start()
    {
        

    }

    void Update()
    {
        //if(temp > 0.0f)
        //{
        //    temp -= 0.1f;
        //    if (temp <= 0.0f)
        //    {
        //        ToggleByMenu();
        //    }
        //}

    }

    public void ToggleByMenu()
    {

        flag++;
        if (flag == 2)
        {
            flag = 0;
        }

        if (flag == 0)
        {
            AnimationOn();
        }
        else if (flag == 1)
        {
            AnimationOff();
        }

    }

    public void AnimationOn()
    {
        foreach (Animator anim in animators)
        {
            anim.enabled = true;
        }

    }

    public void AnimationOff()
    {
        foreach (Animator anim in animators)
        {
            anim.enabled = false;
        }

    }
}

/*
This script is used to generate the robots and assign their movements.
*/

using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.Audio;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class GenRobot : MonoBehaviour
{
    public int num;
    public Transform origin;
    public GameObject robot;
    public TextMeshProUGUI robotNumText;
    public GameObject[] parents;
    public AnimationChange animationChange;

    void Start()
    {
        for (int index = 0; index < 13; index++)
        {
            num = index;
            float t = 360.0f / num;
            //Calculate the initial position and rotational movement angle for the robots according to their quantity
            for (int i = 0; i < num; i++)
            {
                float angle = t * i;
                float posX = origin.position.x - Mathf.Cos(angle * Mathf.Deg2Rad) * 3;
                float posZ = origin.position.z + Mathf.Sin(angle * Mathf.Deg2Rad) * 3;
                GameObject temp = Instantiate(robot, new Vector3(posX, 0.0f, posZ), Quaternion.identity);
                temp.GetComponent<Movement>().animationChange = animationChange;
                temp.transform.Rotate(0f, angle, 0f);
                temp.transform.parent = parents[index].transform;
            }
            parents[index].SetActive(false);
        }
        SetRobotNum(6);
    }

    //Set the quantity of robots
    public void SetRobotNum(float _volume)
    {
        if (robotNumText != null)
            robotNumText.text = _volume.ToString("#0");

        num = (int)_volume;
        genRobot(num);
    }

    public void genRobot(int num)
    {
        for (int i = 0; i < 13; i++)
        {
            if (i == num)
                parents[i].SetActive(true);
            else
                parents[i].SetActive(false);
        }
    }
}

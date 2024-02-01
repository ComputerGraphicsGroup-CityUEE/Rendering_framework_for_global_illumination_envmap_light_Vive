using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RobotAnim : MonoBehaviour
{
    public Animation anim;
    public string[] names;
    public int index;
    // Start is called before the first frame update
    void Start()
    {
        /*anim.PlayQueued("Death", QueueMode.CompleteOthers);
        anim.PlayQueued("Dance", QueueMode.CompleteOthers);
        anim.PlayQueued("Idle", QueueMode.CompleteOthers);*/
        //names[] = { "Dance", "Death", "Idle", "Jump", "No", "Punch", "Running", "Sitting", "Standing", "ThumbsUp", "Walking", "WalkJump", "Wave", "Yes" };
        index = 0;
    }

    // Update is called once per frame
    void Update()
    {
        /*if (Input.GetKeyDown(KeyCode.Q))
        {
            index = index + 1;
            if (index >= 14)
            {
                index = 0;
            }

            //anim.Stop();
            anim.Play(names[index]);
            
        }*/
    }
}

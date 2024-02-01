using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class SwitchDPM : MonoBehaviour
{
    public Material DPM, CM;
    public GameObject camera;
    public GameObject CM_Object;
    public GameObject plane;

    public bool control;
    public InputActionReference toggleReference = null;


    private void Awake()
    {
        toggleReference.action.started += Toggle;
    }

    private void OnDestroy()
    {
        toggleReference.action.started -= Toggle;
    }


    void Update()
    {
        //if (control)
        //    SwitchToCM();
        //else
        //    SwitchToDPM();

    }

    public void SwitchToCM()
    {

        this.gameObject.GetComponent<LightSource>().enabled = false;
        camera.SetActive(false);
        CM_Object.SetActive(true);
        plane.GetComponent<MeshRenderer>().material = CM;
    }


    public void SwitchToDPM()
    {

        this.gameObject.GetComponent<LightSource>().enabled = true;
        camera.SetActive(true);
        CM_Object.SetActive(false);
        plane.GetComponent<MeshRenderer>().material = DPM;
    }

    private void Toggle(InputAction.CallbackContext context)
    {
        control = !control;
        if (control)
            SwitchToCM();
        else
            SwitchToDPM();
    }
}

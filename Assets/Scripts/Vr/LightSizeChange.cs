using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;


public class LightSizeChange : MonoBehaviour
{
    public InputActionReference lightSizeDecreaseReference = null;
    public InputActionReference lightSizeIncreaseReference = null;
    private float temp = 1.00f;
    public DisplayFPS displayFPS;
    public Transform light;

    private void Update()
    {
        float valueDecrease = lightSizeDecreaseReference.action.ReadValue<float>();
        float valueIncrease = lightSizeIncreaseReference.action.ReadValue<float>();
        DecreaseLightSize(valueDecrease);
        IncreaseLightSize(valueIncrease);
    }

    private void DecreaseLightSize(float value)
    {
        temp -= 0.01f * value;
        if (temp <= 0.00f)
            temp = 0.00f;

        displayFPS.lightSize = temp;
        Shader.SetGlobalFloat("lightsize", temp);
        light.localScale = new Vector3(1.0f + temp, 1.0f + temp, 1.0f + temp);
    }

    private void IncreaseLightSize(float value)
    {
        
        temp += 0.01f * value;
        if (temp >= 1.5f)
            temp = 1.5f;

        displayFPS.lightSize = temp;
        Shader.SetGlobalFloat("lightsize", temp);
        light.localScale = new Vector3(1.0f + temp, 1.0f + temp, 1.0f + temp);

    }
}

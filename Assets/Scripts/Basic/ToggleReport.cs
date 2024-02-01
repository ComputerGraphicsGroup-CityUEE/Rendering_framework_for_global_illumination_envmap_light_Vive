using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class ToggleReport : MonoBehaviour
{
    public InputActionReference toggleReference = null;
    public GameObject img, text;

    private void Awake()
    {
        toggleReference.action.started += Toggle;
    }

    private void OnDestroy()
    {
        toggleReference.action.started -= Toggle;
    }

    private void Toggle(InputAction.CallbackContext context)
    {
        bool isActive = !img.activeSelf;
        img.SetActive(isActive);
        text.SetActive(isActive);
    }
}

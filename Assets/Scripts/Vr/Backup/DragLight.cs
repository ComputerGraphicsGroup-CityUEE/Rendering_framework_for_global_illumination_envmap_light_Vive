using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class DragLight : MonoBehaviour
{
    public InputActionReference toggleReference = null;
    public Material origin, change;
    public bool control;
    public Transform vrTransform;

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
        control = !control;

        if (control)
        {
            this.GetComponent<MeshRenderer>().material = change;

            RaycastHit hit;
            if (Physics.Raycast(vrTransform.position, vrTransform.forward, out hit))
            {
                if (hit.collider.gameObject.CompareTag("Top"))
                {
                    transform.position = hit.point;
                }
            }
        }
        else
        {
            this.GetComponent<MeshRenderer>().material = origin;
        }
    }
}

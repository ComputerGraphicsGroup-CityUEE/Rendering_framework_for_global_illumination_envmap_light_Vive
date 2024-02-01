using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Drag : MonoBehaviour
{
    public Material origin, change;
    public bool control;

    IEnumerator OnMouseDown()    
    {
        if (control)
        {
            Vector3 targetScreenPos = Camera.main.WorldToScreenPoint(transform.position);
            var offset = transform.position - Camera.main.ScreenToWorldPoint(new Vector3(Input.mousePosition.x, Input.mousePosition.y, targetScreenPos.z));

            while (Input.GetMouseButton(0))
            {
                Vector3 mousePos = new Vector3(Input.mousePosition.x, Input.mousePosition.y, targetScreenPos.z);
                var targetPos = Camera.main.ScreenToWorldPoint(mousePos) + offset;
                transform.position = targetPos;
                yield return new WaitForFixedUpdate();
                this.GetComponent<MeshRenderer>().material = change;
            }

            this.GetComponent<MeshRenderer>().material = origin;
        }
    }
}

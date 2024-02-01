using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;

public class CameraControlAndroid : MonoBehaviour
{
    private Touch _OldTouch1;
    private Touch _OldTouch2;

    Vector2 _M_Screenpos = new Vector2();
    bool _bMoveOrRotation;
    Vector3 _OldPosition;
    Quaternion _OldRotation;
    float _OldFOV;

    public float perspectiveZoomSpeed = 0.5f;
    public float orthoZoomSpeed = 0.5f;
    public Camera cam;
    public bool control;

    void Start()
    {
        _OldPosition = Camera.main.transform.position;
        _OldRotation = Camera.main.transform.rotation;
        cam = GetComponent<Camera>();
        _OldFOV = cam.fieldOfView;
        control = false;
    }

    void Update()
    {
        if (control)
        {
            if (EventSystem.current.IsPointerOverGameObject(Input.GetTouch(0).fingerId) == true)
            {
                return;
            }

            if (Input.touchCount <= 0)
            {
                return;
            }

            if (1 == Input.touchCount)
            {
                if (_bMoveOrRotation)
                {
                    Touch _Touch = Input.GetTouch(0);
                    Vector2 _DeltaPos = _Touch.deltaPosition;
                    transform.Rotate(0.1f * Vector3.up * _DeltaPos.x, Space.World);
                    transform.Rotate(0.1f * Vector3.left * _DeltaPos.y, Space.World);
                }
                else
                {
                    if (Input.touches[0].phase == TouchPhase.Began)
                    {
                        _M_Screenpos = Input.touches[0].position;
                    }
                    else if (Input.touches[0].phase == TouchPhase.Moved)
                    {
                        Camera.main.transform.Translate(new Vector3(-Input.touches[0].deltaPosition.x * Time.deltaTime * 0.1f, -Input.touches[0].deltaPosition.y * Time.deltaTime * 0.1f, 0));
                    }
                }
            }

            if (Input.touchCount == 2)
            {
                Touch touchZero = Input.GetTouch(0);
                Touch touchOne = Input.GetTouch(1);

                Vector2 touchZeroPrevPos = touchZero.position - touchZero.deltaPosition;
                Vector2 touchOnePrevPos = touchOne.position - touchOne.deltaPosition;

                float prevTouchDeltaMag = (touchZeroPrevPos - touchOnePrevPos).magnitude;
                float touchDeltaMag = (touchZero.position - touchOne.position).magnitude;

                float deltaMagnitudeDiff = prevTouchDeltaMag - touchDeltaMag;

                if (cam.orthographic)
                {
                    cam.orthographicSize += deltaMagnitudeDiff * orthoZoomSpeed;
                    cam.orthographicSize = Mathf.Max(cam.orthographicSize, 0.1f);
                }
                else
                {
                    cam.fieldOfView += deltaMagnitudeDiff * perspectiveZoomSpeed;
                    cam.fieldOfView = Mathf.Clamp(cam.fieldOfView, 10f, 40f);
                }
            }
        }
    }

    public void BackPosition()
    {
        Camera.main.transform.position = _OldPosition;
        Camera.main.transform.rotation = _OldRotation;
        cam.fieldOfView = _OldFOV;
    }

    public void RotationOrMove()
    {
        _bMoveOrRotation = !_bMoveOrRotation;
    }

    public void ChangeControl()
    {
        control = !control;
    }
}

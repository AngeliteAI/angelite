using UnityEngine;

public class ObliqueCamera : MonoBehaviour
{
    public float cameraHeight = 100f;
    public float cameraSize = 50f;

    private Camera cam;

    void Start()
    {
        cam = GetComponent<Camera>();
        SetObliqueView();
    }

    void SetObliqueView()
    {
        // Position the camera at the desired height
        transform.position = new Vector3(0f, cameraHeight, 0f);

        // Rotate the camera to achieve the isometric oblique angle
        transform.rotation = Quaternion.Euler(135f, 135f, 90f);

        // Set the camera to orthographic projection
        cam.orthographic = true;

        // Set the orthographic size (vertical FOV)
        cam.orthographicSize = cameraSize;
    }
}
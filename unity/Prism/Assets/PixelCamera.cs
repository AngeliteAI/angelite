using Unity.VisualScripting;
using UnityEngine;

public class PixelCamera : MonoBehaviour
{
    public float scale;
    public Camera orthographic;

    public GameObject displayPlane;
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        var width = (int)(Screen.width / scale);
        var height = (int)(Screen.height / scale);
        GetComponent<Camera>().targetTexture = new RenderTexture(width, height, 24);
        GetComponent<Camera>().targetTexture.filterMode = FilterMode.Point;
        displayPlane.GetComponent<Renderer>().material.SetTexture("_MainTex", GetComponent<Camera>().targetTexture);
    }

    // Update is called once per frame
    void Update()
    {
        var orthoHeight = 2f *  orthographic.orthographicSize;
        var orthoWidth = orthoHeight * orthographic.aspect;
        displayPlane.transform.localScale = new Vector3(orthoWidth, 1, orthoHeight); 
    }
}

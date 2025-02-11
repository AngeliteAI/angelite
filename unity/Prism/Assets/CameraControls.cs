using UnityEngine;

public class CameraControls : MonoBehaviour
{
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        Vector2 direction = Vector2.zero;
        
        if (Input.GetKey(KeyCode.W))
        {
            direction += Vector2.up;    
        }

        if (Input.GetKey(KeyCode.S))
        {
            direction += Vector2.down;
        }

        if (Input.GetKey(KeyCode.A))
        {
            direction += Vector2.left;
            
        }

        if (Input.GetKey(KeyCode.D))
        {
            direction += Vector2.right;
        }
        Vector3 movement3d =  new Vector3(direction.x, 0, direction.y);
        transform.position += movement3d * Time.deltaTime;
    }
}

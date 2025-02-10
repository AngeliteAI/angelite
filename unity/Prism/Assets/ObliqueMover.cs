using UnityEngine;

public class ObliqueMover : MonoBehaviour
{
    public Vector3 excess;

    void rectify()
    {
        var frameExcess = new Vector3(this.transform.position.x % 1.0f, this.transform.position.y % 1.0f,
            this.transform.position.z % 1.0f);
        this.excess += frameExcess;
        var temp = new Vector3(0f,0f,0f);
        for (int d = 0; d < 3; d++)
        {
            if (Mathf.Abs(this.excess[d]) >= 1.0)
            {
                temp[d] += this.excess[d];
                this.excess[d] = 0.0f;
            }
        }
        this.transform.position += temp;
        this.transform.position = this.transform.position - frameExcess;
    }

    void Start()
    {
        rectify();
    }

    // Update is called once per frame
    void Update()
    {
        rectify();
    }
}

using UnityEngine;
using System.Collections;

public class RotateCtrl : MonoBehaviour {
    public GameObject rotateCore;   //旋转中心物体
    public bool bCoreRotate = true; //是否绕中心旋转
    public bool bLockRotate = false; //是否保持初始的朝向（不能和自转一起勾选）
    public int RotateSpeed = 90;    //绕中心旋转速度
    public bool bSelfRotate = true; //是否自转
    public int SelfRotateSpeed = 90;   //自转速度
    private Quaternion startRotation;  //初始旋转状态
    public bool bUpdown = true;   //是否上下浮动
    public float updownDistance = 0.5f;   //上下浮动距离
    private Vector3 startPosition;   //起始位置
    private Vector3 unit = new Vector3(0,1,0);   //上下浮动距离
    public float updownSpeedRate = 1f;   //上下浮动速度
    public Vector3 offset = new Vector3(0, 0, 0);
	// Use this for initialization
	void Start () {
        startRotation = this.transform.rotation;
        startPosition = this.transform.localPosition + offset;
	}
	
	// Update is called once per frame
	void Update () {
        if (rotateCore != null && bCoreRotate == true && bUpdown == false) 
        {
            this.transform.RotateAround(rotateCore.transform.position, Vector3.up, RotateSpeed * Time.deltaTime);
            if (bLockRotate == true)
                this.transform.rotation = startRotation;
        }
        if (bSelfRotate == true)
        {
            this.transform.Rotate(Vector3.up, SelfRotateSpeed * Time.deltaTime);
        }

        if (bUpdown == true) 
        {
            float temp = Mathf.Repeat(Time.time * updownSpeedRate, 4 * updownDistance) - 2 * updownDistance;
            if (temp > updownDistance)
            {
                temp = 2 * updownDistance - temp;
            }
            else if (temp < -updownDistance)
            {
                temp = -2 * updownDistance - temp;
            }
            //Vector3 tempPosition = this.transform.localPosition;
            this.transform.localPosition = startPosition + unit * temp;           
        }
	}
}

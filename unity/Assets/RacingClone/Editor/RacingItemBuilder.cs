using System;
using System.Linq;
using UnityEditor;
using UnityEngine;
using B = RacingDrivingBuilder;

// Editor-only geometry. Runtime objects are local snapshot presentations.
public static class RacingItemBuilder
{
    static Material Material(string name,Color color,bool transparent=false)
    {
        const string folder="Assets/RacingClone/Materials";
        if(!AssetDatabase.IsValidFolder(folder)) AssetDatabase.CreateFolder("Assets/RacingClone","Materials");
        var path=folder+"/Item_"+name+".mat";
        var mat=AssetDatabase.LoadAssetAtPath<Material>(path);
        if(mat==null) { mat=new Material(Shader.Find("Universal Render Pipeline/Lit")); AssetDatabase.CreateAsset(mat,path); }
        mat.SetColor("_BaseColor",color);
        mat.EnableKeyword("_EMISSION"); mat.SetColor("_EmissionColor",new Color(color.r,color.g,color.b)*.45f);
        if(transparent)
        {
            mat.SetFloat("_Surface",1); mat.SetFloat("_SrcBlend",5); mat.SetFloat("_DstBlend",10);
            mat.SetFloat("_ZWrite",0); mat.EnableKeyword("_SURFACE_TYPE_TRANSPARENT"); mat.renderQueue=3000;
        }
        EditorUtility.SetDirty(mat);
        return mat;
    }
    static GameObject Shape(Transform parent,string name,PrimitiveType kind,Vector3 pos,Vector3 scale,Material mat)
    {
        var go=GameObject.CreatePrimitive(kind); go.name=name; go.layer=6; go.transform.SetParent(parent,false);
        go.transform.localPosition=pos; go.transform.localScale=scale;
        UnityEngine.Object.DestroyImmediate(go.GetComponent<Collider>());
        go.GetComponent<Renderer>().sharedMaterial=mat;
        return go;
    }
    public static void Build(GameObject controls,DouyinScript hud)
    {
        var old=GameObject.Find("Item Presentation");
        if(old!=null) UnityEngine.Object.DestroyImmediate(old);
        var root=new GameObject("Item Presentation"); root.layer=6;
        var cyan=Material("Box",new Color(.15f,.5f,1,.85f),true);
        var yellow=Material("Banana",new Color(1,.78f,.03f));
        var white=Material("Missile",Color.white);
        var red=Material("Nose",new Color(1,.15f,.08f));
        var shieldMat=Material("Shield",new Color(1,.85f,.3f,.2f),true);
        var magnetMat=Material("Magnet",new Color(.3f,.8f,1,.8f),true);
        var boxes=new GameObject("Boxes"); boxes.transform.SetParent(root.transform,false);
        for(int i=1;i<=20;i++)
        {
            var box=Shape(boxes.transform,"Box "+i,PrimitiveType.Cube,Vector3.zero,Vector3.one*1.8f,cyan);
            for(int face=0;face<4;face++)
            {
                var text=new GameObject("Question",typeof(TextMesh)); text.layer=6; text.transform.SetParent(box.transform,false);
                text.transform.localRotation=Quaternion.Euler(0,face*90,0);
                text.transform.localPosition=text.transform.localRotation*new Vector3(0,0,-.51f);
                var tm=text.GetComponent<TextMesh>(); tm.text="?"; tm.anchor=TextAnchor.MiddleCenter; tm.alignment=TextAlignment.Center;
                tm.fontSize=100; tm.characterSize=.14f; tm.color=Color.white;
            }
            box.SetActive(false);
        }
        var banana=new GameObject("Banana Template"); banana.layer=6; banana.transform.SetParent(root.transform,false);
        for(int i=0;i<9;i++)
        {
            float angle=(i/8f*1.3f-.15f)*Mathf.PI;
            var piece=Shape(banana.transform,"Peel "+i,PrimitiveType.Sphere,new Vector3(Mathf.Cos(angle)*.75f,.1f,Mathf.Sin(angle)*.75f),new Vector3(.4f,.23f,.4f),yellow);
        }
        for(int i=0;i<3;i++)
        {
            var peel=Shape(banana.transform,"Stem "+i,PrimitiveType.Cylinder,new Vector3(Mathf.Cos(i*2.1f)*.5f,.2f,Mathf.Sin(i*2.1f)*.5f),new Vector3(.2f,.49f,.2f),yellow);
            peel.transform.localRotation=Quaternion.Euler(0,i*120,65);
        }
        banana.SetActive(false);
        var missile=new GameObject("Missile Template"); missile.layer=6; missile.transform.SetParent(root.transform,false);
        Shape(missile.transform,"Body",PrimitiveType.Cylinder,Vector3.zero,new Vector3(.44f,.8f,.44f),white).transform.localRotation=Quaternion.Euler(90,0,0);
        Shape(missile.transform,"Nose",PrimitiveType.Sphere,new Vector3(0,0,.9f),new Vector3(.44f,.44f,.6f),red);
        Shape(missile.transform,"Flame",PrimitiveType.Sphere,new Vector3(0,0,-1),new Vector3(.3f,.3f,.65f),yellow);
        missile.SetActive(false);
        var shields=new GameObject("Shields"); shields.transform.SetParent(root.transform,false);
        var magnets=new GameObject("Magnets"); magnets.transform.SetParent(root.transform,false);
        for(int i=1;i<=6;i++)
        {
            Shape(shields.transform,"Shield "+i,PrimitiveType.Sphere,Vector3.zero,new Vector3(4.8f,3,5.2f),shieldMat).SetActive(false);
            var go=new GameObject("Magnet "+i,typeof(LineRenderer)); go.layer=6; go.transform.SetParent(magnets.transform,false);
            var line=go.GetComponent<LineRenderer>(); line.sharedMaterial=magnetMat; line.positionCount=2;
            line.startWidth=.18f; line.endWidth=.08f; line.useWorldSpace=true; go.SetActive(false);
        }
        B.Script(GameObject.Find("RaceClient"),"Client/RaceItemVisuals.lua",B.Ref("root",root,"GameObject"));
        var slots=B.Label(controls.transform,"Item Slots","",new Vector2(.5f,0),new Vector2(0,55),new Vector2(580,80),24);
        var notice=B.Label(controls.transform,"Item Notice","",new Vector2(.5f,.55f),Vector2.zero,new Vector2(650,60),30);
        B.Button(controls.transform,"换位 · Alt","swap",new Vector2(.5f,0),new Vector2(0,120),new Vector2(160,45));
        var use=controls.transform.Find("氮气/Label").GetComponent<UnityEngine.UI.Text>();
        hud.ParaLuaBindingData=hud.ParaLuaBindingData.Concat(new DouyinLuaDataVar[]{
            B.Ref("itemSlots",slots,"UnityEngine.UI.Text"),B.Ref("itemNotice",notice,"UnityEngine.UI.Text"),
            B.Ref("useLabel",use,"UnityEngine.UI.Text"),B.Ref("swapButton",controls.transform.Find("换位 · Alt").gameObject,"GameObject")}).ToArray();
        EditorUtility.SetDirty(hud);
    }
}

using System;
using UnityEngine;
using UnityEngine.UI;
using UnityEditor;
using UnityEditor.SceneManagement;
using Newtonsoft.Json.Linq;
using System.Linq;
using B = RacingDrivingBuilder;

public static class RacingMatchBuilder
{
    static GameObject Panel(Transform parent, string name, Vector2 position, Vector2 size)
    {
        var go=new GameObject(name,typeof(RectTransform),typeof(Image));
        go.transform.SetParent(parent,false);
        var rect=go.GetComponent<RectTransform>();
        rect.anchorMin=rect.anchorMax=new Vector2(.5f,.5f);
        rect.anchoredPosition=position; rect.sizeDelta=size;
        go.GetComponent<Image>().color=new Color(.015f,.045f,.09f,.96f);
        return go;
    }
    public static GameObject Button(Transform parent,string label,string action,int value,Vector2 position,Vector2 size,bool enabled=true)
    {
        var go=Panel(parent,label,position,size);
        go.GetComponent<Image>().color=enabled ? new Color(.05f,.32f,.48f,1) : new Color(.10f,.12f,.15f,1);
        var button=go.AddComponent<Button>(); button.transition=Selectable.Transition.ColorTint; button.interactable=enabled;
        B.Label(go.transform,"Label",label,new Vector2(.5f,.5f),Vector2.zero,size,20);
        if(enabled)
        {
            var script=B.Script(go,"Client/RaceMenuButton.lua",
                new DouyinLuaDataString {varName="action",Data=action},
                new DouyinLuaDataDouble {varName="value",Data=value});
            UnityEditor.Events.UnityEventTools.AddStringPersistentListener(button.onClick,script.CallMethod,"Click");
        }
        return go;
    }
    [MenuItem("Tools/Racing Clone/Build Match")]
    public static void Build()
    {
        B.Build();
        if(UnityEngine.Object.FindObjectOfType<UnityEngine.EventSystems.EventSystem>()==null)
            new GameObject("Racing UI EventSystem",typeof(UnityEngine.EventSystems.EventSystem),typeof(UnityEngine.EventSystems.StandaloneInputModule));
        var grid=GameObject.Find("Starting Grid").transform;
        if(PrefabUtility.IsPartOfPrefabInstance(grid.gameObject))
            PrefabUtility.UnpackPrefabInstance(PrefabUtility.GetOutermostPrefabInstanceRoot(grid.gameObject),PrefabUnpackMode.Completely,InteractionMode.AutomatedAction);
        string[] skins={"red","blue","purple","yellow","white","pink","green","black"};
        int slot=0;
        foreach(Transform seat in grid)
        {
            seat.name="Seat "+(++slot);
            if(PrefabUtility.IsPartOfPrefabInstance(seat.gameObject))
                PrefabUtility.UnpackPrefabInstance(PrefabUtility.GetOutermostPrefabInstanceRoot(seat.gameObject),PrefabUnpackMode.Completely,InteractionMode.AutomatedAction);
            while(seat.childCount>0) UnityEngine.Object.DestroyImmediate(seat.GetChild(0).gameObject);
            for(int skin=0;skin<skins.Length;skin++)
            {
                var prefab=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/RacingClone/Prefabs/Vehicles/RacingVehicle_"+skins[skin]+".prefab");
                var instance=(GameObject)PrefabUtility.InstantiatePrefab(prefab,seat);
                instance.name="Skin_"+skin; instance.transform.localPosition=Vector3.zero;
                instance.transform.localRotation=Quaternion.Euler(0,180,0);
                foreach(var node in instance.GetComponentsInChildren<Transform>(true))
                    if(node.name=="Group_22" || node.name=="Group_25")
                    {
                        node.name=node.name.Replace("Group_","flame_");
                        foreach(Transform cone in node) cone.gameObject.SetActive(true);
                        node.gameObject.SetActive(false);
                    }
                instance.SetActive(skin==(slot-1)%8);
            }
        }
        var old=GameObject.Find("Match Interface");
        if(old!=null) UnityEngine.Object.DestroyImmediate(old);
        var ui=new GameObject("Match Interface",typeof(RectTransform),typeof(Canvas),typeof(CanvasScaler),typeof(GraphicRaycaster));
        ui.GetComponent<Canvas>().renderMode=RenderMode.ScreenSpaceOverlay;
        ui.GetComponent<Canvas>().sortingOrder=100;
        var scaler=ui.GetComponent<CanvasScaler>(); scaler.uiScaleMode=CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution=new Vector2(1280,720); scaler.matchWidthOrHeight=.5f;
        var info=B.Label(ui.transform,"Race Info","",new Vector2(.5f,1),new Vector2(0,-28),new Vector2(760,55),22);
        var countdown=B.Label(ui.transform,"Countdown","",new Vector2(.5f,.58f),Vector2.zero,new Vector2(1000,90),48);
        var minimap=Panel(ui.transform,"Minimap",new Vector2(480,180),new Vector2(170,170));
        minimap.GetComponent<Image>().raycastTarget=false;
        var arrays=JObject.Parse(System.IO.File.ReadAllText("../docs/reference/qqfeiche3d/tracks/city.json"))["track"]["arrays"];
        var xs=arrays["px"].Values<float>().ToArray(); var zs=arrays["pz"].Values<float>().ToArray();
        float cx=(xs.Min()+xs.Max())/2,cz=(zs.Min()+zs.Max())/2,mapScale=145/Mathf.Max(xs.Max()-xs.Min(),zs.Max()-zs.Min());
        Func<int,Vector2> point=i=>new Vector2((xs[i]-cx)*mapScale,(cz-zs[i])*mapScale);
        for(int i=0;i<128;i++)
        {
            var a=point(i*xs.Length/128); var b=point((i+1)*xs.Length/128%xs.Length);
            var line=Panel(minimap.transform,"Road "+i,(a+b)/2,new Vector2((b-a).magnitude+1,2));
            line.GetComponent<Image>().color=new Color(.2f,.7f,.9f,.8f); line.GetComponent<Image>().raycastTarget=false;
            line.transform.localRotation=Quaternion.Euler(0,0,Mathf.Atan2(b.y-a.y,b.x-a.x)*Mathf.Rad2Deg);
        }
        for(int i=1;i<=6;i++)
        {
            var marker=Panel(minimap.transform,"Marker "+i,Vector2.zero,new Vector2(7,7));
            marker.GetComponent<Image>().raycastTarget=false;
        }
        var lobby=Panel(ui.transform,"Lobby",Vector2.zero,new Vector2(1060,620));
        var lobbyInfo=B.Label(lobby.transform,"Room Settings","等待房间状态",new Vector2(.5f,.5f),new Vector2(-250,0),new Vector2(490,570),24);
        lobbyInfo.alignment=TextAnchor.MiddleLeft;
        B.Label(lobby.transform,"Track Heading","地图与模式",new Vector2(.5f,.5f),new Vector2(245,245),new Vector2(450,45),26);
        string[] maps={"11城","情迷爱琴海","法老金字塔","雪地大冒险"};
        for(int i=0;i<4;i++) Button(lobby.transform,maps[i],"map",i,new Vector2(140+i%2*220,195-i/2*50),new Vector2(205,45));
        Button(lobby.transform,"竞速","mode",0,new Vector2(150,90),new Vector2(190,40));
        Button(lobby.transform,"道具","mode",1,new Vector2(360,90),new Vector2(190,40));
        B.Label(lobby.transform,"Lap Heading","比赛圈数",new Vector2(.5f,.5f),new Vector2(245,50),new Vector2(450,30),20);
        int[] laps={1,2,3,5};
        for(int i=0;i<4;i++) Button(lobby.transform,laps[i]+" 圈","laps",laps[i],new Vector2(90+i*110,10),new Vector2(95,35));
        string[] difficulties={"新手","熟练","车神"};
        for(int i=0;i<3;i++) Button(lobby.transform,difficulties[i],"diff",i,new Vector2(110+i*145,-35),new Vector2(125,35));
        B.Label(lobby.transform,"Skin Heading","我的赛车配色",new Vector2(.5f,.5f),new Vector2(245,-85),new Vector2(450,40),22);
        string[] colors={"红","蓝","紫","黄","白","粉","绿","黑"};
        for(int i=0;i<8;i++) Button(lobby.transform,colors[i],"skin",i,new Vector2(85+i%4*110,-130-i/4*50),new Vector2(95,40));
        Button(lobby.transform,"开始比赛 · Enter","start",0,new Vector2(250,-255),new Vector2(400,60));
        var modal=Panel(ui.transform,"Match Modal",Vector2.zero,new Vector2(1100,600));
        var modalInfo=B.Label(modal.transform,"Modal Text","",new Vector2(.5f,.5f),new Vector2(0,55),new Vector2(1050,450),23);
        var resume=Button(modal.transform,"继续比赛","resume",0,new Vector2(-330,-235),new Vector2(240,60));
        Button(modal.transform,"重新开始","restart",0,new Vector2(0,-235),new Vector2(240,60));
        Button(modal.transform,"返回大厅","quit",0,new Vector2(330,-235),new Vector2(240,60));
        B.Script(GameObject.Find("RaceClient"),"Client/RaceHUD.lua",
            B.Ref("lobby",lobby,"GameObject"),B.Ref("modal",modal,"GameObject"),
            B.Ref("raceInfo",info,"UnityEngine.UI.Text"),B.Ref("countdownLabel",countdown,"UnityEngine.UI.Text"),
            B.Ref("lobbyInfo",lobbyInfo,"UnityEngine.UI.Text"),B.Ref("modalInfo",modalInfo,"UnityEngine.UI.Text"),
            B.Ref("resumeButton",resume,"GameObject")).updateOrder=10;
        var controls=Resources.FindObjectsOfTypeAll<GameObject>();
        GameObject driving=null;
        foreach(var go in controls) if(go.scene.IsValid() && go.name=="Driving Controls") driving=go;
        if(driving==null) throw new Exception("Driving controls missing");
        Button(driving.transform,"暂停 · Esc","pause",0,new Vector2(490,315),new Vector2(180,45));
        var status=driving.transform.Find("Driving Status").GetComponent<RectTransform>();
        status.anchoredPosition=new Vector2(0,-105); status.sizeDelta=new Vector2(650,80);
        var gauge=Panel(driving.transform,"Gauge",new Vector2(0,205),new Vector2(240,8));
        var fill=Panel(gauge.transform,"Fill",Vector2.zero,new Vector2(240,8)).GetComponent<Image>();
        fill.type=Image.Type.Filled; fill.fillMethod=Image.FillMethod.Horizontal; fill.fillOrigin=0;
        fill.color=new Color(.2f,.9f,1,1); fill.fillAmount=0; fill.raycastTarget=false;
        var hud=GameObject.Find("RaceClient").GetComponents<DouyinScript>().First(s=>s.ScriptAsset.assetPath.EndsWith("/RaceHUD.lua"));
        hud.ParaLuaBindingData=hud.ParaLuaBindingData.Concat(new DouyinLuaDataVar[]{
            B.Ref("minimap",minimap,"GameObject"),B.Ref("gaugeFill",fill,"UnityEngine.UI.Image")}).ToArray();
        EditorUtility.SetDirty(hud);
        RacingItemBuilder.Build(driving,hud);
        modal.SetActive(false);
        EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());
        EditorSceneManager.SaveOpenScenes(); AssetDatabase.SaveAssets();
        Debug.Log("[RacingClone] Match and item mode interface saved.");
    }
}

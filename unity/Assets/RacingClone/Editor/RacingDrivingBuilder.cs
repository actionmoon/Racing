using System;
using System.Linq;
using UnityEngine;
using UnityEngine.UI;
using UnityEditor;
using UnityEditor.SceneManagement;

/// <summary>Scene wiring only. All driving and network logic runs in Lua.</summary>
public static class RacingDrivingBuilder
{
    const string Root = "Assets/RacingClone/Lua/";
    public static DouyinScript Script(GameObject go, string path, params DouyinLuaDataVar[] bindings)
    {
        var assetPath = path.StartsWith("Assets/") ? path : Root + path;
        var script = go.GetComponents<DouyinScript>().FirstOrDefault(s => s.ScriptAsset != null && s.ScriptAsset.assetPath == assetPath);
        if (script == null) script = go.AddComponent<DouyinScript>();
        script.ScriptAsset = AssetDatabase.LoadAssetAtPath<DouyinScriptAsset>(assetPath);
        if (script.ScriptAsset == null) throw new Exception("Lua import missing: " + path);
        script.IsManualedVar = true;
        script.ParaLuaBindingData = bindings;
        EditorUtility.SetDirty(script);
        return script;
    }
    public static DouyinLuaDataUObject Ref(string name, UnityEngine.Object value, string type)
        => new DouyinLuaDataUObject { varName = name, Data = value, varType = type };
    public static Text Label(Transform parent, string name, string text, Vector2 anchor, Vector2 position, Vector2 size, int fontSize)
    {
        var go = new GameObject(name, typeof(RectTransform), typeof(Text));
        go.transform.SetParent(parent, false);
        var rect = go.GetComponent<RectTransform>();
        rect.anchorMin = rect.anchorMax = anchor;
        rect.anchoredPosition = position;
        rect.sizeDelta = size;
        var label = go.GetComponent<Text>();
        label.font = Resources.GetBuiltinResource<Font>("Arial.ttf");
        label.fontSize = fontSize;
        label.color = Color.white;
        label.text = text;
        label.alignment = TextAnchor.MiddleCenter;
        label.raycastTarget = false;
        return label;
    }
    public static void Button(Transform parent, string name, string action, Vector2 anchor, Vector2 pos, Vector2 size)
    {
        var go = new GameObject(name, typeof(RectTransform), typeof(Image), typeof(Button));
        go.transform.SetParent(parent, false);
        var rect = go.GetComponent<RectTransform>();
        rect.anchorMin = rect.anchorMax = anchor;
        rect.anchoredPosition = pos;
        rect.sizeDelta = size;
        go.GetComponent<Image>().color = new Color(0.03f, 0.11f, 0.2f, 0.78f);
        go.GetComponent<Button>().transition = Selectable.Transition.None;
        Label(go.transform, "Label", name, new Vector2(0.5f, 0.5f), Vector2.zero, size, 22);
        var script=Script(go, "Client/RaceTouchButton.lua", new DouyinLuaDataString {varName="action",Data=action});
        var trigger=go.AddComponent<UnityEngine.EventSystems.EventTrigger>();
        foreach(var kind in new[]{UnityEngine.EventSystems.EventTriggerType.PointerDown,UnityEngine.EventSystems.EventTriggerType.PointerUp,UnityEngine.EventSystems.EventTriggerType.PointerExit})
        {
            var entry=new UnityEngine.EventSystems.EventTrigger.Entry {eventID=kind};
            UnityEditor.Events.UnityEventTools.AddStringPersistentListener(entry.callback,script.CallMethod,
                kind==UnityEngine.EventSystems.EventTriggerType.PointerDown ? "Press" : "Release");
            trigger.triggers.Add(entry);
        }
    }
    [MenuItem("Tools/Racing Clone/Build Driving")]
    public static void Build()
    {
        AssetDatabase.Refresh();
        var world = GameObject.Find("DouyinWorldRoot");
        var loader = world.GetComponent<DouyinScriptLoader>();
        loader.CustomScriptsPath = Root + "Modules";
        loader.CustomScripts = AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(Root + "Modules");
        loader.PackAllScripts();
        EditorUtility.SetDirty(loader);
        // Use the supported platform camera service for target offset, yaw and FOV.
        var config = world.GetComponent<DouyinWorldRoot>();
        config.EnableCustomCamera = false;
        config.CustomCameraList = new Camera[0];
        var bootstrap = GameObject.Find("Bootstrap Camera");
        if (bootstrap != null) bootstrap.GetComponent<Camera>().enabled = false;
        EditorUtility.SetDirty(config);
        // Source export records inherited visibility on the two exhaust groups
        // and their cone meshes. Keep the cones enabled beneath a toggled group.
        var grid = GameObject.Find("Starting Grid");
        foreach (Transform vehicle in grid.transform)
            foreach (var node in vehicle.GetComponentsInChildren<Transform>(true))
                if (node.name == "Group_22" || node.name == "Group_25" || node.name.StartsWith("flame_"))
                {
                    node.name = node.name.Replace("Group_", "flame_");
                    foreach (Transform cone in node) cone.gameObject.SetActive(true);
                    node.gameObject.SetActive(false);
                }
        foreach (var old in Resources.FindObjectsOfTypeAll<GameObject>().Where(go=>go!=null && go.scene.IsValid() && go.name=="Driving Controls").ToArray())
            UnityEngine.Object.DestroyImmediate(old);
        var ui = new GameObject("Driving Controls",typeof(RectTransform),typeof(Canvas),typeof(CanvasScaler),typeof(GraphicRaycaster));
        var canvas = ui.GetComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 50;
        var scaler = ui.GetComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1280,720);
        scaler.matchWidthOrHeight = 0.5f;
        var status = Label(ui.transform,"Driving Status","驾驶就绪",new Vector2(0.5f,1),new Vector2(0,-70),new Vector2(650,100),24);
        var events = Label(ui.transform,"Driving Event","",new Vector2(0.5f,0.65f),Vector2.zero,new Vector2(500,60),36);
        Button(ui.transform,"油门","up",new Vector2(1,0),new Vector2(-95,210),new Vector2(120,80));
        Button(ui.transform,"制动","down",new Vector2(1,0),new Vector2(-230,210),new Vector2(120,80));
        Button(ui.transform,"漂移","shift",new Vector2(1,0),new Vector2(-230,110),new Vector2(120,80));
        Button(ui.transform,"氮气","nitro",new Vector2(1,0),new Vector2(-95,110),new Vector2(120,80));
        Button(ui.transform,"小喷","small",new Vector2(1,0),new Vector2(-365,110),new Vector2(120,80));
        Button(ui.transform,"复位","reset",new Vector2(0,1),new Vector2(70,-145),new Vector2(100,50));
        Button(ui.transform,"镜头","camera",new Vector2(0,1),new Vector2(180,-145),new Vector2(100,50));
        var input = Script(GameObject.Find("RaceClient"),"Client/RaceInput.lua");
        input.updateOrder = -20;
        var client = Script(GameObject.Find("RaceClient"),"Client/RaceClient.lua",
            new DouyinLuaDataMono {varName="inputScript",Data=input,varType="DouyinScript"},
            Ref("telemetry",status,"UnityEngine.UI.Text"),Ref("eventLabel",events,"UnityEngine.UI.Text"),
            Ref("controls",ui,"GameObject"),new DouyinLuaDataNetString {varName="raceSnapshot",Data=""});
        client.IsNetworked = true;
        client.CreateNetBehaviourComponent();
        client.updateOrder = 0;
        var camera = Script(GameObject.Find("RaceClient"),"Client/RaceCamera.lua");
        camera.updateOrder = 20;
        ui.SetActive(false);
        Script(GameObject.Find("RaceServer"),"Server/RaceServer.lua").IsServerScript = true;
        AssetDatabase.SaveAssets();
        EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());
        EditorSceneManager.SaveOpenScenes();
        Debug.Log("[RacingClone] Step4 driving, shared modules, network snapshot and controls saved.");
    }
}

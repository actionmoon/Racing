using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Rendering.Universal;
using B = RacingDrivingBuilder;

public static class RacingPresentationBuilder
{
    const string Root="Assets/RacingClone";
    static GameObject SceneObject(string name) => Resources.FindObjectsOfTypeAll<GameObject>()
        .FirstOrDefault(go=>go.scene.IsValid() && go.name==name);
    static AudioSource Audio(Transform parent,string id,bool loop)
    {
        var go=new GameObject(id);go.transform.SetParent(parent,false);
        var source=go.AddComponent<AudioSource>();
        source.clip=AssetDatabase.LoadAssetAtPath<AudioClip>(Root+"/Audio/"+id+".wav");
        if(source.clip==null) throw new Exception("Audio missing "+id);
        source.loop=loop;source.playOnAwake=false;source.spatialBlend=0;
        source.volume=loop ? 0 : 1;
        return source;
    }
    public static void BuildClient()
    {
        var old=SceneObject("Racing Audio");if(old!=null) UnityEngine.Object.DestroyImmediate(old);
        var audio=new GameObject("Racing Audio");
        foreach(var name in new[]{"music0","music1","music2","music3","engine","skid","wind"})
        {
            var source=Audio(audio.transform,name,true);
            if(name.StartsWith("music")) source.volume=1;
        }
        foreach(var name in new[]{"count","go","nitro","small","double","gauge","crash","scrape","lap","finish","pad","land","item","missile","boom","banana","shield","click","wrong"})
            Audio(audio.transform,name,false);
        var client=GameObject.Find("RaceClient");
        B.Script(client,"Client/RaceAudio.lua",B.Ref("root",audio,"GameObject")).updateOrder=15;
        ConfigureQuality();
        old=SceneObject("Settings Interface");if(old!=null) UnityEngine.Object.DestroyImmediate(old);
        var ui=new GameObject("Settings Interface",typeof(RectTransform),typeof(Canvas),typeof(CanvasScaler),typeof(GraphicRaycaster));
        ui.GetComponent<Canvas>().renderMode=RenderMode.ScreenSpaceOverlay;
        ui.GetComponent<Canvas>().sortingOrder=200;
        var scaler=ui.GetComponent<CanvasScaler>();scaler.uiScaleMode=CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution=new Vector2(1280,720);
        var panel=new GameObject("Local Settings",typeof(RectTransform),typeof(Image));
        panel.transform.SetParent(ui.transform,false);
        panel.GetComponent<RectTransform>().sizeDelta=new Vector2(690,610);
        panel.GetComponent<Image>().color=new Color(.015f,.045f,.09f,.98f);
        B.Label(panel.transform,"Heading","个人设置",new Vector2(.5f,.5f),new Vector2(0,255),new Vector2(650,45),30);
        var info=B.Label(panel.transform,"Settings Info","",new Vector2(.5f,.5f),new Vector2(0,170),new Vector2(650,110),22);
        string[] quality={"流畅","均衡","精致"},camera={"追逐","远景","近景"};
        for(int i=0;i<3;i++)
        {
            RacingMatchBuilder.Button(panel.transform,quality[i],"quality",i,new Vector2(-210+i*210,70),new Vector2(190,55));
            RacingMatchBuilder.Button(panel.transform,camera[i],"camera",i,new Vector2(-210+i*210,-5),new Vector2(190,55));
        }
        RacingMatchBuilder.Button(panel.transform,"音乐开关","music",0,new Vector2(0,-80),new Vector2(400,55));
        RacingMatchBuilder.Button(panel.transform,"上一首","song",-1,new Vector2(-155,-155),new Vector2(290,55));
        RacingMatchBuilder.Button(panel.transform,"下一首","song",1,new Vector2(155,-155),new Vector2(290,55));
        RacingMatchBuilder.Button(panel.transform,"返回","closeSettings",0,new Vector2(0,-240),new Vector2(400,60));
        var match=SceneObject("Match Interface");var driving=SceneObject("Driving Controls");
        foreach(var tr in new[]{match.transform.Find("Lobby/个人设置"),driving.transform.Find("个人设置"),driving.transform.Find("左转"),driving.transform.Find("右转")})
            if(tr!=null) UnityEngine.Object.DestroyImmediate(tr.gameObject);
        RacingMatchBuilder.Button(match.transform.Find("Lobby"),"个人设置","settings",0,new Vector2(-250,-260),new Vector2(420,50));
        RacingMatchBuilder.Button(driving.transform,"个人设置","settings",0,new Vector2(490,255),new Vector2(180,45));
        B.Button(driving.transform,"左转","left",new Vector2(0,0),new Vector2(80,210),new Vector2(120,80));
        B.Button(driving.transform,"右转","right",new Vector2(0,0),new Vector2(215,210),new Vector2(120,80));
        B.Script(client,"Client/RaceSettings.lua",B.Ref("post",SceneObject("Step3 Post Processing"),"GameObject"),
            B.Ref("panel",panel,"GameObject"),B.Ref("settingInfo",info,"UnityEngine.UI.Text"),
            B.Ref("quality0",AssetDatabase.LoadAssetAtPath<ScriptableObject>(Root+"/Settings/RacingQuality0.asset"),"UnityEngine.ScriptableObject"),
            B.Ref("quality1",AssetDatabase.LoadAssetAtPath<ScriptableObject>(Root+"/Settings/RacingQuality1.asset"),"UnityEngine.ScriptableObject"),
            B.Ref("quality2",AssetDatabase.LoadAssetAtPath<ScriptableObject>(Root+"/Settings/RacingQuality2.asset"),"UnityEngine.ScriptableObject")).updateOrder=-15;
        B.Script(client,"Client/RaceLayout.lua",B.Ref("matchUI",match,"GameObject"),
            B.Ref("drivingUI",driving,"GameObject"),B.Ref("settingsUI",ui,"GameObject")).updateOrder=30;
        panel.SetActive(false);
        GameObject.Find("DouyinWorldRoot").GetComponent<DouyinScriptLoader>().PackAllScripts();
        AssetDatabase.SaveAssets();
        EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());
        EditorSceneManager.SaveOpenScenes();
        Debug.Log("[RacingClone] Step7 client audio, settings and responsive UI saved.");
    }
    static void ConfigureQuality()
    {
        var settings=new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/QualitySettings.asset")[0]);
        var levels=settings.FindProperty("m_QualitySettings");
        string[] labels={"流畅","均衡","精致"};
        if(!AssetDatabase.IsValidFolder(Root+"/Settings")) AssetDatabase.CreateFolder(Root,"Settings");
        for(int i=0;i<3;i++)
        {
            string path=Root+"/Settings/RacingQuality"+i+".asset";
            var asset=AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(path);
            if(asset==null)
            {
                asset=UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>("Assets/Settings/URP-HighFidelity.asset"));
                AssetDatabase.CreateAsset(asset,path);
            }
            asset.name="RacingQuality"+i;asset.renderScale=new[]{.65f,.85f,1f}[i];
            asset.msaaSampleCount=i==2 ? 4 : 1;asset.shadowDistance=i==0 ? 0 : i==1 ? 100 : 180;
            asset.supportsHDR=i==2;asset.shadowCascadeCount=i==2 ? 2 : 1;
            var serialized=new SerializedObject(asset);
            serialized.FindProperty("m_MainLightShadowsSupported").boolValue=i>0;
            serialized.FindProperty("m_MainLightShadowmapResolution").intValue=i==2 ? 2048 : 1024;
            serialized.FindProperty("m_SoftShadowsSupported").boolValue=i==2;
            serialized.ApplyModifiedPropertiesWithoutUndo();
            var level=levels.GetArrayElementAtIndex(i);
            level.FindPropertyRelative("name").stringValue=labels[i];
            level.FindPropertyRelative("customRenderPipeline").objectReferenceValue=asset;
            level.FindPropertyRelative("vSyncCount").intValue=0;
            EditorUtility.SetDirty(asset);
        }
        settings.ApplyModifiedPropertiesWithoutUndo();QualitySettings.SetQualityLevel(1,true);
    }
    public static void BuildMaps()
    {
        foreach(var id in new[]{"aegean","egypt","snow"}) RacingCityBuilder.BuildMapAssets(id);
        var old=GameObject.Find("Racing Maps");
        if(old!=null) UnityEngine.Object.DestroyImmediate(old);
        var root=new GameObject("Racing Maps");
        var city=GameObject.Find("City11");
        if(city==null) throw new Exception("Existing city missing");
        city.transform.SetParent(root.transform,true);
        var bindings=new System.Collections.Generic.List<DouyinLuaDataVar>();
        foreach(var id in new[]{"city","aegean","egypt","snow"})
        {
            var map=id=="city" ? city : (GameObject)PrefabUtility.InstantiatePrefab(
                AssetDatabase.LoadAssetAtPath<GameObject>(Root+"/Prefabs/Maps/Map_"+id+".prefab"),root.transform);
            bindings.Add(B.Ref(id,map,"GameObject"));
            var config=JObject.Parse(File.ReadAllText("../docs/reference/qqfeiche3d/tracks/"+id+".json"))["config"];
            var path=Root+"/Materials/"+id+"Sky.mat";
            var sky=AssetDatabase.LoadAssetAtPath<Material>(path);
            if(sky==null){sky=new Material(Shader.Find("RacingClone/CitySky"));AssetDatabase.CreateAsset(sky,path);}
            foreach(var key in new[]{"top","horizon","bottom"})
            {
                ColorUtility.TryParseHtmlString((string)config["sky"][key],out var c);
                sky.SetColor("_"+char.ToUpperInvariant(key[0])+key.Substring(1),c);
            }
            EditorUtility.SetDirty(sky);
            bindings.Add(B.Ref(id+"Sky",sky,"UnityEngine.Material"));
            if(id=="snow")
            {
                var snow=new GameObject("Snowfall");snow.transform.SetParent(map.transform,false);
                snow.transform.position=new Vector3(0,42,0);
                var particles=snow.AddComponent<ParticleSystem>();
                var main=particles.main;main.startLifetime=18;main.startSpeed=0;
                main.startSize=.16f;main.maxParticles=2500;main.simulationSpace=ParticleSystemSimulationSpace.World;
                var shape=particles.shape;shape.shapeType=ParticleSystemShapeType.Box;shape.scale=new Vector3(800,4,800);
                var emission=particles.emission;emission.rateOverTime=120;
                var velocity=particles.velocityOverLifetime;velocity.enabled=true;
                velocity.space=ParticleSystemSimulationSpace.World;velocity.x=.7f;velocity.y=-3;velocity.z=.25f;
                particles.GetComponent<ParticleSystemRenderer>().sharedMaterial=new Material(Shader.Find("Universal Render Pipeline/Particles/Unlit"));
            }
            map.SetActive(true);
        }
        bindings.Add(B.Ref("sun",GameObject.Find("Directional Light").GetComponent<Light>(),"UnityEngine.Light"));
        B.Script(GameObject.Find("RaceClient"),"Client/RaceMapView.lua",bindings.ToArray()).updateOrder=5;
        AssetDatabase.SaveAssets();
        EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());
        EditorSceneManager.SaveOpenScenes();
    }
}

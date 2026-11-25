using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;

/// <summary>Builds separate scenes with controlled boost/landing initial states.</summary>
public static class RacingDrivingVerification
{
    public static void BuildFixture(string scenario)
    {
        var main = "Assets/Scenes/RacingClone.unity";
        EditorSceneManager.OpenScene(main);
        RacingDrivingBuilder.Build();
        var target = "Assets/Scenes/RacingDriving_" + scenario + ".unity";
        EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene(),target,true);
        EditorSceneManager.OpenScene(target);
        var fixtureAsset = AssetDatabase.LoadAssetAtPath<DouyinScriptAsset>("Assets/RacingClone/Verification/DrivingFixture.lua");
        var server = new GameObject("Driving Verification Fixture");
        server.transform.SetParent(GameObject.Find("DouyinServerRoot").transform);
        var setup = server.AddComponent<DouyinScript>();
        setup.ScriptAsset = fixtureAsset;
        setup.IsManualedVar = true;
        setup.ParaLuaBindingData = new DouyinLuaDataVar[]{new DouyinLuaDataString{varName="scenario",Data=scenario}};
        setup.updateOrder = -100;
        setup.IsServerScript = true;
        var clientGo = GameObject.Find("RaceClient");
        var input = clientGo.AddComponent<DouyinScript>();
        input.ScriptAsset = fixtureAsset;
        input.IsManualedVar = true;
        input.ParaLuaBindingData = new DouyinLuaDataVar[]{new DouyinLuaDataString{varName="scenario",Data=scenario}};
        input.updateOrder = -20;
        foreach(var script in clientGo.GetComponents<DouyinScript>())
        {
            if(script.ScriptAsset.assetPath.EndsWith("/RaceInput.lua")) script.enabled = false;
            if(script.ScriptAsset.assetPath.EndsWith("/RaceClient.lua"))
                foreach(var binding in script.ParaLuaBindingData)
                    if(binding.varName=="inputScript") ((DouyinLuaDataMono)binding).Data=input;
        }
        EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());
        EditorSceneManager.SaveOpenScenes();
        AssetDatabase.SaveAssets();
        EditorApplication.ExecuteMenuItem("Tools/ScenePackage");
    }
}

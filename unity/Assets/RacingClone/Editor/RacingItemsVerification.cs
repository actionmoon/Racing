using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
public static class RacingItemsVerification
{
    public static void BuildFixture()
    {
        EditorSceneManager.OpenScene("Assets/Scenes/RacingClone.unity");
        RacingMatchBuilder.Build();
        var target="Assets/Scenes/RacingItems_Verification.unity";
        EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene(),target,true);
        EditorSceneManager.OpenScene(target);
        var client=GameObject.Find("RaceClient");
        RacingDrivingBuilder.Script(GameObject.Find("RaceServer"),
            "Assets/RacingClone/Verification/ItemsFixture.lua").updateOrder=-40;
        var input=RacingDrivingBuilder.Script(client,"Assets/RacingClone/Verification/ItemsFixture.lua");
        input.updateOrder=-40;
        DouyinScript real=null;
        foreach(var script in client.GetComponents<DouyinScript>())
            if(script.ScriptAsset.assetPath.EndsWith("/RaceInput.lua")) real=script;
        input.ParaLuaBindingData=new DouyinLuaDataVar[] {
            new DouyinLuaDataMono { varName="realInput",Data=real,varType="DouyinScript" }
        };
        foreach(var script in client.GetComponents<DouyinScript>())
            if(script.ScriptAsset.assetPath.EndsWith("/RaceClient.lua"))
                foreach(var binding in script.ParaLuaBindingData)
                    if(binding.varName=="inputScript") ((DouyinLuaDataMono)binding).Data=input;
        EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());
        EditorSceneManager.SaveOpenScenes(); AssetDatabase.SaveAssets();
        EditorApplication.ExecuteMenuItem("Tools/ScenePackage");
    }
}

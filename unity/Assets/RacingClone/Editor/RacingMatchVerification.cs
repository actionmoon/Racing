using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
public static class RacingMatchVerification
{
    public static void BuildFixture()
    {
        EditorSceneManager.OpenScene("Assets/Scenes/RacingClone.unity");
        RacingMatchBuilder.Build();
        var target="Assets/Scenes/RacingMatch_Verification.unity";
        EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene(),target,true);
        EditorSceneManager.OpenScene(target);
        var input=RacingDrivingBuilder.Script(GameObject.Find("RaceClient"),"Assets/RacingClone/Verification/MatchFixture.lua");
        input.updateOrder=-20;
        foreach(var script in GameObject.Find("RaceClient").GetComponents<DouyinScript>())
        {
            if(script.ScriptAsset.assetPath.EndsWith("/RaceInput.lua")) script.enabled=false;
            if(script.ScriptAsset.assetPath.EndsWith("/RaceClient.lua"))
                foreach(var binding in script.ParaLuaBindingData)
                    if(binding.varName=="inputScript") ((DouyinLuaDataMono)binding).Data=input;
        }
        EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());
        EditorSceneManager.SaveOpenScenes(); AssetDatabase.SaveAssets();
        EditorApplication.ExecuteMenuItem("Tools/ScenePackage");
    }
}

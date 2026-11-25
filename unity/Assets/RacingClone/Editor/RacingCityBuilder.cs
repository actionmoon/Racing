using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>Rebuilds step 3 assets from captured geometry without changing gameplay.</summary>
public static class RacingCityBuilder
{
    const string Root = "Assets/RacingClone";
    static string Source = Root + "/Source/City.racingmesh";
    static JObject data;
    static Dictionary<string, Mesh> meshes;
    static Dictionary<string, Material> materials;
    static Dictionary<string, JToken> textures;
    public static Vector3 Position(JToken p) => new Vector3((float)p[0], (float)p[1], -(float)p[2]);
    public static Quaternion Rotation(JToken q) => new Quaternion(-(float)q[0], -(float)q[1], (float)q[2], (float)q[3]);
    static Color RGB(JToken c) => new Color((float)c[0], (float)c[1], (float)c[2]);
    static Color SkinColor(int hex) => new Color(((hex >> 16) & 255) / 255f, ((hex >> 8) & 255) / 255f, (hex & 255) / 255f);

    static Material MakeMaterial(JToken src, JToken skin = null)
    {
        string role = (string)src["role"];
        string name = (string)src["id"] + (skin == null ? "" : "_" + (string)skin["id"]);
        string path = Root + "/Materials/Imported/" + name + ".mat";
        bool unlit = (string)src["type"] == "MeshBasicMaterial" || (string)src["type"] == "SpriteMaterial";
        string shader = (string)src["type"] == "ShaderMaterial" ? "RacingClone/Water" : (bool)src["vertexColors"] ? "RacingClone/VertexSurface"
            : unlit ? "Universal Render Pipeline/Unlit" : "Universal Render Pipeline/Lit";
        var mat = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (mat == null) { mat = new Material(Shader.Find(shader)); AssetDatabase.CreateAsset(mat, path); }
        else mat.shader = Shader.Find(shader);
        Color color = RGB(src["color"]).gamma;
        if ((string)src["type"] == "ShaderMaterial" && data["config"]["water"] is JObject)
            ColorUtility.TryParseHtmlString((string)data["config"]["water"]["color"], out color);
        if (skin != null && !string.IsNullOrEmpty(role)) color = SkinColor((int)skin[role]);
        color.a = (float)src["opacity"];
        mat.SetColor("_BaseColor", color);
        mat.SetFloat("_Metallic", (float)src["metalness"]);
        mat.SetFloat("_Smoothness", 1 - (float)src["roughness"]);
        if ((string)src["type"] == "ShaderMaterial")
        {
            mat.SetFloat("_Metallic", 0.25f);
            mat.SetFloat("_Smoothness", 0.9f);
        }
        Color emission = RGB(src["emissive"]).gamma;
        if (skin != null && !string.IsNullOrEmpty(role) && emission.maxColorComponent > 0)
            emission = SkinColor((int)skin[role]);
        mat.SetColor("_EmissionColor", emission * (float)src["emission"]);
        if (emission.maxColorComponent > 0) mat.EnableKeyword("_EMISSION");
        string map = (string)src["map"];
        if (string.IsNullOrEmpty(map)) map = (string)src["alphaMap"];
        if (!string.IsNullOrEmpty(map))
        {
            JToken t = textures[map];
            mat.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>((string)t["asset"]));
            float flip = (bool)t["flipY"] ? 1 : -1;
            mat.SetTextureScale("_BaseMap", new Vector2((float)t["repeat"][0], (float)t["repeat"][1] * flip));
            mat.SetTextureOffset("_BaseMap", new Vector2((float)t["offset"][0], (float)t["offset"][1] + (flip < 0 ? 1 : 0)));
        }
        mat.SetFloat("_Cull", (int)src["side"] == 2 || unlit ? 0 : (int)src["side"] == 1 ? 1 : 2);
        if ((bool)src["transparent"])
        {
            mat.SetFloat("_Surface", 1);
            mat.SetFloat("_Blend", 0);
            mat.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
            mat.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
            mat.SetFloat("_ZWrite", (bool)src["depthWrite"] ? 1 : 0);
            mat.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
            mat.SetOverrideTag("RenderType", "Transparent");
            mat.renderQueue = 3000;
        }
        EditorUtility.SetDirty(mat);
        return mat;
    }

    static GameObject BuildHierarchy(JArray nodes, Dictionary<string, Material> mats, bool city)
    {
        var objects = new Dictionary<int, GameObject>();
        foreach (var n in nodes)
        {
            int id = (int)n["id"];
            var go = new GameObject((string)n["name"] + "_" + id);
            objects.Add(id, go);
            if ((int)n["parent"] >= 0) go.transform.SetParent(objects[(int)n["parent"]].transform, false);
            go.transform.localPosition = Position(n["position"]);
            go.transform.localRotation = Rotation(n["quaternion"]);
            go.transform.localScale = new Vector3((float)n["scale"][0], (float)n["scale"][1], (float)n["scale"][2]);
            go.SetActive((bool)n["visible"]);
            string geometry = (string)n["geometry"];
            if (string.IsNullOrEmpty(geometry)) continue;
            // The procedural Three.js sky shader is replaced by the Unity skybox.
            if (city && (string)n["path"] == "City/2") { go.SetActive(false); continue; }
            go.AddComponent<MeshFilter>().sharedMesh = meshes[geometry];
            var renderer = go.AddComponent<MeshRenderer>();
            var assigned = n["materials"].Select(m => mats[(string)m]).ToArray();
            // Three.js ignores geometry groups when the mesh has a single material.
            renderer.sharedMaterials = assigned.Length == 1
                ? Enumerable.Repeat(assigned[0], meshes[geometry].subMeshCount).ToArray() : assigned;
            renderer.shadowCastingMode = (bool)n["castShadow"] ? ShadowCastingMode.On : ShadowCastingMode.Off;
            renderer.receiveShadows = (bool)n["receiveShadow"];
            if ((bool)n["sprite"])
                go.transform.rotation = Rotation(data["camera"]["quaternion"]);
            if (city)
            {
                string p = (string)n["path"];
                bool solid = p == "City/1/0" || p == "City/1/1" || p == "City/1/2" || p == "City/1/3"
                    || p == "City/1/9" || p.StartsWith("City/1/10/") || (bool)n["castShadow"];
                if (solid && (bool)n["visible"])
                {
                    var collider = go.AddComponent<MeshCollider>();
                    collider.sharedMesh = p == "City/1/1"
                        ? AssetDatabase.LoadAllAssetsAtPath(Source).OfType<Mesh>().First(m => m.name == geometry + "_Collision")
                        : meshes[geometry];
                }
                GameObjectUtility.SetStaticEditorFlags(go, StaticEditorFlags.BatchingStatic | StaticEditorFlags.OccluderStatic);
            }
        }
        return objects[0];
    }

    [MenuItem("Tools/Racing Clone/Build City Assets")]
    public static void Build()
    {
        Source = Root + "/Source/City.racingmesh";
        Directory.CreateDirectory(Root + "/Materials/Imported");
        Directory.CreateDirectory(Root + "/Prefabs/Vehicles");
        Directory.CreateDirectory(Root + "/Prefabs/Maps");
        AssetDatabase.Refresh();
        data = JObject.Parse(File.ReadAllText(Source));
        meshes = AssetDatabase.LoadAllAssetsAtPath(Source).OfType<Mesh>().Where(m => !m.name.EndsWith("_Collision")).ToDictionary(m => m.name);
        if (meshes.Count != ((JArray)data["geometries"]).Count) throw new Exception("Mesh import incomplete");
        textures = data["textures"].ToDictionary(t => (string)t["id"]);
        foreach (var t in data["textures"])
        {
            var importer = (TextureImporter)AssetImporter.GetAtPath((string)t["asset"]);
            importer.wrapModeU = (int)t["wrapS"] == 1000 ? TextureWrapMode.Repeat : TextureWrapMode.Clamp;
            importer.wrapModeV = (int)t["wrapT"] == 1000 ? TextureWrapMode.Repeat : TextureWrapMode.Clamp;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.maxTextureSize = 2048;
            importer.SaveAndReimport();
        }
        materials = data["materials"].ToDictionary(m => (string)m["id"], m => MakeMaterial(m));
        foreach (var skin in data["skins"])
        {
            var skinMaterials = new Dictionary<string, Material>(materials);
            foreach (var m in data["materials"].Where(m => !string.IsNullOrEmpty((string)m["role"])))
                skinMaterials[(string)m["id"]] = MakeMaterial(m, skin);
            var model = BuildHierarchy((JArray)data["vehicle"], skinMaterials, false);
            model.name = "Model";
            model.transform.SetPositionAndRotation(Vector3.zero, Quaternion.Euler(0, 180, 0));
            var vehicle = new GameObject("RacingVehicle_" + (string)skin["id"]);
            model.transform.SetParent(vehicle.transform, false);
            PrefabUtility.SaveAsPrefabAsset(vehicle, Root + "/Prefabs/Vehicles/" + vehicle.name + ".prefab");
            UnityEngine.Object.DestroyImmediate(vehicle);
        }
        var city = BuildHierarchy((JArray)data["city"], materials, true);
        city.name = "City11";
        var cityAsset = PrefabUtility.SaveAsPrefabAsset(city, Root + "/Prefabs/Maps/City11.prefab");
        UnityEngine.Object.DestroyImmediate(city);
        foreach (string old in new[] { "Bootstrap Ground", "City11", "Starting Grid", "Step3 Post Processing" })
        {
            var go = GameObject.Find(old);
            if (go != null) UnityEngine.Object.DestroyImmediate(go);
        }
        PrefabUtility.InstantiatePrefab(cityAsset);
        var grid = new GameObject("Starting Grid");
        foreach (var entry in data["grid"])
        {
            string path = Root + "/Prefabs/Vehicles/RacingVehicle_" + (string)entry["skin"]["id"] + ".prefab";
            var car = (GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>(path));
            car.name = "Grid " + (int)entry["slot"] + " " + (string)entry["skin"]["id"];
            car.transform.SetParent(grid.transform);
            car.transform.SetPositionAndRotation(Position(entry["position"]), Rotation(entry["quaternion"]) * Quaternion.Euler(0, 180, 0));
        }
        var camera = GameObject.Find("Bootstrap Camera").GetComponent<Camera>();
        camera.transform.SetPositionAndRotation(Position(data["camera"]["position"]), Rotation(data["camera"]["quaternion"]));
        camera.fieldOfView = (float)data["camera"]["fov"];
        camera.nearClipPlane = 0.1f;
        camera.farClipPlane = 5000;
        camera.clearFlags = CameraClearFlags.Skybox;
        camera.allowHDR = true;
        camera.depth = 100;
        var additional = camera.GetComponent<UniversalAdditionalCameraData>();
        if (additional == null) additional = camera.gameObject.AddComponent<UniversalAdditionalCameraData>();
        additional.renderPostProcessing = true;
        var world = GameObject.Find("DouyinWorldRoot").GetComponents<Component>().First(c => c.GetType().Name == "DouyinWorldRoot");
        world.GetType().GetField("EnableCustomCamera").SetValue(world, true);
        world.GetType().GetField("CustomCameraList").SetValue(world, new[] { camera });
        EditorUtility.SetDirty(world);
        var light = GameObject.Find("Directional Light").GetComponent<Light>();
        light.transform.rotation = Quaternion.LookRotation(-Position(data["sun"]));
        light.color = new Color(1, 0.957f, 0.863f);
        // Three.js legacy lighting multiplies the Lambert term by 1 / PI.
        light.intensity = 2.6f / Mathf.PI;
        light.shadows = LightShadows.Soft;
        RenderSettings.ambientMode = AmbientMode.Trilight;
        RenderSettings.ambientSkyColor = new Color(0.839f, 0.925f, 1);
        RenderSettings.ambientEquatorColor = new Color(0.65f, 0.72f, 0.7f);
        RenderSettings.ambientGroundColor = new Color(0.435f, 0.541f, 0.353f);
        RenderSettings.ambientIntensity = 1.1f;
        RenderSettings.fog = true;
        RenderSettings.fogMode = FogMode.Linear;
        RenderSettings.fogColor = new Color(0.812f, 0.902f, 0.984f);
        RenderSettings.fogStartDistance = 380;
        RenderSettings.fogEndDistance = 2300;
        string skyPath = Root + "/Materials/CitySky.mat";
        var sky = AssetDatabase.LoadAssetAtPath<Material>(skyPath);
        if (sky == null) { sky = new Material(Shader.Find("RacingClone/CitySky")); AssetDatabase.CreateAsset(sky, skyPath); }
        RenderSettings.skybox = sky;
        var post = new GameObject("Step3 Post Processing");
        var volume = post.AddComponent<Volume>();
        volume.isGlobal = true;
        string profilePath = Root + "/Materials/CityPostProcessing.asset";
        var profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(profilePath);
        if (profile == null)
        {
            profile = ScriptableObject.CreateInstance<VolumeProfile>();
            AssetDatabase.CreateAsset(profile, profilePath);
            var bloom = profile.Add<Bloom>(true);
            bloom.intensity.Override(0.55f);
            bloom.threshold.Override(1);
            AssetDatabase.AddObjectToAsset(bloom, profile);
        }
        volume.sharedProfile = profile;
        // Avatar spawns stay on the shoulder so they do not cover the reference camera.
        var spawns = UnityEngine.Object.FindObjectsOfType<Transform>().Where(t => t.name.Contains("Spawn")).ToArray();
        for (int i = 0; i < spawns.Length; i++) spawns[i].position = Position(data["player"]["position"]) + new Vector3(0, 2, 17 + i * 2);
        AssetDatabase.SaveAssets();
        EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());
        EditorSceneManager.SaveOpenScenes();
        Debug.Log("[RacingClone] Step3 city, 8 vehicle prefabs and 6 grid cars built.");
    }

    public static void BuildMapAssets(string id)
    {
        Source = Root + "/Source/" + char.ToUpperInvariant(id[0]) + id.Substring(1) + ".racingmesh";
        Directory.CreateDirectory(Root + "/Materials/Imported");
        Directory.CreateDirectory(Root + "/Prefabs/Maps");
        AssetDatabase.ImportAsset(Source, ImportAssetOptions.ForceUpdate);
        data = JObject.Parse(File.ReadAllText(Source));
        meshes = AssetDatabase.LoadAllAssetsAtPath(Source).OfType<Mesh>().Where(m => !m.name.EndsWith("_Collision")).ToDictionary(m => m.name);
        textures = data["textures"].ToDictionary(t => (string)t["id"]);
        foreach (var t in data["textures"])
        {
            var importer = (TextureImporter)AssetImporter.GetAtPath((string)t["asset"]);
            importer.wrapModeU = (int)t["wrapS"] == 1000 ? TextureWrapMode.Repeat : TextureWrapMode.Clamp;
            importer.wrapModeV = (int)t["wrapT"] == 1000 ? TextureWrapMode.Repeat : TextureWrapMode.Clamp;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.SaveAndReimport();
        }
        materials = data["materials"].ToDictionary(m => (string)m["id"], m => MakeMaterial(m));
        var map = BuildHierarchy((JArray)data["city"], materials, true);
        map.name = "Map_" + id;
        PrefabUtility.SaveAsPrefabAsset(map, Root + "/Prefabs/Maps/Map_" + id + ".prefab");
        UnityEngine.Object.DestroyImmediate(map);
        AssetDatabase.SaveAssets();
        Source = Root + "/Source/City.racingmesh";
        Debug.Log("[RacingClone] Map asset built: " + id);
    }

    public static void Screenshot(string path, int width = 1280, int height = 576)
    {
        var camera = GameObject.Find("Bootstrap Camera").GetComponent<Camera>();
        var previous = camera.targetTexture;
        var rt = RenderTexture.GetTemporary(width, height, 24, RenderTextureFormat.ARGB32);
        var active = RenderTexture.active;
        camera.targetTexture = rt;
        camera.Render();
        RenderTexture.active = rt;
        var image = new Texture2D(width, height, TextureFormat.RGB24, false);
        image.ReadPixels(new Rect(0, 0, width, height), 0, 0);
        image.Apply();
        File.WriteAllBytes(path, image.EncodeToPNG());
        camera.targetTexture = previous;
        RenderTexture.active = active;
        RenderTexture.ReleaseTemporary(rt);
        UnityEngine.Object.DestroyImmediate(image);
    }
}

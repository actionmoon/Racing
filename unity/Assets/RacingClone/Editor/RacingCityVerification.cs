using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

public static class RacingCityVerification
{
    public static string Verify(string output)
    {
        var data = JObject.Parse(File.ReadAllText("Assets/RacingClone/Source/City.racingmesh"));
        var a = data["track"]["arrays"];
        var road = GameObject.Find("road_3").GetComponent<MeshCollider>();
        var walls = GameObject.Find("Mesh_4").GetComponent<MeshCollider>();
        var vertices = road.sharedMesh.vertices;
        int count = (int)data["track"]["samples"];
        int misses = 0, wallMisses = 0, bridgeMisses = 0, bridgeSamples = 0;
        float heightError = 0, centerError = 0, widthError = 0;
        float minY = float.MaxValue, maxY = float.MinValue;
        Physics.SyncTransforms();
        Physics.queriesHitBackfaces = false;
        for (int i = 0; i < count; i++)
        {
            var left = road.transform.TransformPoint(vertices[i * 2]);
            var right = road.transform.TransformPoint(vertices[i * 2 + 1]);
            var center = (left + right) * 0.5f;
            var source = new Vector3((float)a["px"][i], (float)a["py"][i], -(float)a["pz"][i]);
            centerError = Mathf.Max(centerError, Vector3.Distance(center, source));
            var horizontal = right - left;
            horizontal.y = 0;
            widthError = Mathf.Max(widthError, Mathf.Abs(horizontal.magnitude - 26));
            minY = Mathf.Min(minY, center.y);
            maxY = Mathf.Max(maxY, center.y);
            foreach (float t in new[] { 0.04f, 0.5f, 0.96f })
            {
                var expected = Vector3.Lerp(left, right, t);
                RaycastHit hit;
                if (!road.Raycast(new Ray(expected + Vector3.up * 2, Vector3.down), out hit, 4)) misses++;
                else heightError = Mathf.Max(heightError, Mathf.Abs(hit.point.y - expected.y));
            }
            foreach (var edge in new[] { left, right })
            {
                var start = center + Vector3.up * 0.8f;
                var target = edge + Vector3.up * 0.8f;
                RaycastHit hit;
                if (!walls.Raycast(new Ray(start, target - start), out hit, Vector3.Distance(start, target) + 0.6f)) wallMisses++;
            }
            if ((float)a["bridge"][i] > 0.5f)
            {
                bridgeSamples++;
                RaycastHit hit;
                if (!Physics.Raycast(center + Vector3.up * 0.4f, Vector3.down, out hit, 0.8f)
                    || hit.collider != road || Mathf.Abs(hit.point.y - center.y) > 0.03f) bridgeMisses++;
            }
        }
        float seam = Mathf.Max(Vector3.Distance(vertices[0], vertices[count * 2]),
            Vector3.Distance(vertices[1], vertices[count * 2 + 1]));
        var report = new JObject {
            ["samples"] = count, ["length"] = data["track"]["length"],
            ["seamError"] = seam, ["centerMaxError"] = centerError, ["widthMaxError"] = widthError,
            ["centerMinHeight"] = minY, ["centerMaxHeight"] = maxY, ["rayHeightMaxError"] = heightError,
            ["roadRaycasts"] = count * 3, ["roadMisses"] = misses,
            ["wallRaycasts"] = count * 2, ["wallMisses"] = wallMisses,
            ["bridgeSamples"] = bridgeSamples, ["bridgeMisses"] = bridgeMisses,
            ["colliders"] = UnityEngine.Object.FindObjectsOfType<MeshCollider>().Length,
            ["vehiclePrefabs"] = Directory.GetFiles("Assets/RacingClone/Prefabs/Vehicles", "*.prefab").Length,
            ["textureFiles"] = Directory.GetFiles("Assets/RacingClone/Textures", "*.png").Length
        };
        report["passed"] = seam < 0.001f && centerError < 0.001f && widthError < 0.001f
            && heightError < 0.01f && misses == 0 && wallMisses == 0 && bridgeMisses == 0;
        File.WriteAllText(output, report.ToString());
        return report.ToString();
    }
}

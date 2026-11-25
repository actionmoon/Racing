using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEditor.AssetImporters;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>Imports captured buffers with reflected Z and reversed triangle winding.</summary>
[ScriptedImporter(4, "racingmesh")]
public class RacingMeshImporter : ScriptedImporter
{
    static float[] Floats(JToken value)
    {
        if (value == null || string.IsNullOrEmpty((string)value)) return Array.Empty<float>();
        var bytes = Convert.FromBase64String((string)value);
        var result = new float[bytes.Length / 4];
        Buffer.BlockCopy(bytes, 0, result, 0, bytes.Length);
        return result;
    }

    public override void OnImportAsset(AssetImportContext ctx)
    {
        var text = File.ReadAllText(ctx.assetPath);
        var data = JObject.Parse(text);
        var metadata = new TextAsset(text) { name = "SceneData" };
        ctx.AddObjectToAsset("metadata", metadata);
        ctx.SetMainObject(metadata);
        foreach (var geo in data["geometries"])
        {
            var p = Floats(geo["position"]);
            var n = Floats(geo["normal"]);
            var uv = Floats(geo["uv"]);
            var c = Floats(geo["color"]);
            var vertices = new Vector3[p.Length / 3];
            for (int i = 0; i < vertices.Length; i++)
                vertices[i] = new Vector3(p[i * 3], p[i * 3 + 1], -p[i * 3 + 2]);
            var mesh = new Mesh { name = (string)geo["id"], indexFormat = IndexFormat.UInt32 };
            mesh.vertices = vertices;
            if (n.Length == p.Length)
                mesh.normals = Enumerable.Range(0, vertices.Length)
                    .Select(i => new Vector3(n[i * 3], n[i * 3 + 1], -n[i * 3 + 2])).ToArray();
            if (uv.Length == vertices.Length * 2)
                mesh.uv = Enumerable.Range(0, vertices.Length)
                    .Select(i => new Vector2(uv[i * 2], uv[i * 2 + 1])).ToArray();
            int size = (int)geo["colorSize"];
            if (size >= 3 && c.Length == vertices.Length * size)
                mesh.colors = Enumerable.Range(0, vertices.Length)
                    .Select(i => new Color(c[i * size], c[i * size + 1], c[i * size + 2],
                        size == 4 ? c[i * size + 3] : 1)).ToArray();
            int[] indices;
            if (string.IsNullOrEmpty((string)geo["index"]))
                indices = Enumerable.Range(0, vertices.Length).ToArray();
            else
            {
                var bytes = Convert.FromBase64String((string)geo["index"]);
                indices = new int[bytes.Length / 4];
                Buffer.BlockCopy(bytes, 0, indices, 0, bytes.Length);
            }
            for (int i = 0; i < indices.Length; i += 3)
            {
                int swap = indices[i + 1];
                indices[i + 1] = indices[i + 2];
                indices[i + 2] = swap;
            }
            var groups = (JArray)geo["groups"];
            mesh.subMeshCount = groups.Count == 0 ? 1 : groups.Max(g => (int)g["material"]) + 1;
            if (groups.Count == 0) mesh.SetTriangles(indices, 0);
            else
                for (int sub = 0; sub < mesh.subMeshCount; sub++)
                    mesh.SetTriangles(groups.Where(g => (int)g["material"] == sub)
                        .SelectMany(g => indices.Skip((int)g["start"]).Take((int)g["count"])).ToArray(), sub);
            if (n.Length == 0) mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            ctx.AddObjectToAsset(mesh.name, mesh);
            if (data["city"].Any(node => (string)node["path"] == "City/1/1" && (string)node["geometry"] == (string)geo["id"]))
            {
                // Source guardrail planes face outward. Collisions must also face the lane.
                var collision = UnityEngine.Object.Instantiate(mesh);
                collision.name = mesh.name + "_Collision";
                var reverse = (int[])indices.Clone();
                for (int i = 0; i < reverse.Length; i += 3)
                {
                    int swap = reverse[i + 1];
                    reverse[i + 1] = reverse[i + 2];
                    reverse[i + 2] = swap;
                }
                collision.subMeshCount = 1;
                collision.SetTriangles(indices.Concat(reverse).ToArray(), 0);
                ctx.AddObjectToAsset(collision.name, collision);
            }
        }
    }
}

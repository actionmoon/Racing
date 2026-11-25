using MCPForUnity.Editor.Services.Transport.Transports;
using UnityEditor;
using UnityEngine;

/// <summary>Starts the installed Unity MCP bridge for local editor automation.</summary>
[InitializeOnLoad]
public static class RacingMcpBridge
{
    static RacingMcpBridge()
    {
        EditorApplication.delayCall += Start;
    }

    [MenuItem("Tools/Racing Clone/Start MCP Bridge")]
    public static void Start()
    {
        StdioBridgeHost.Start();
        Debug.Log("[RacingClone] Unity MCP bridge requested.");
    }
}

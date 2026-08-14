using UnityEngine;
using System;
using System.IO;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEditor;
using System.Collections.Generic;

namespace Rosie
{
    public static class PrefabHydrator
    {
        private static readonly Dictionary<string, PrefabInfo> referenceIdToPrefabInfo = new();
        private static readonly Dictionary<string, UnityEngine.GameObject> prefabRootsBeingEdited = new();

        private class PrefabInfo
        {
            public string prefabPath;
            public List<int> hierarchyPathIndices;
            public bool isComponent;

            public UnityEngine.Object FindInPrefab(GameObject prefabRoot)
            {
                var gameObject = prefabRoot;
                for (var i = 0; i < hierarchyPathIndices.Count - 1; i++)
                {
                    gameObject = gameObject.transform.GetChild(hierarchyPathIndices[i]).gameObject;
                }
                if (isComponent)
                {
                    return gameObject.GetComponents<Component>()[hierarchyPathIndices[hierarchyPathIndices.Count - 1]];
                }
                else
                {
                    return gameObject.transform.GetChild(hierarchyPathIndices[hierarchyPathIndices.Count - 1]).gameObject;
                }
            }
        }

        public static SerializedGameObject SerializePrefab(string prefabPath)
        {
            GameObject prefabRoot = PrefabUtility.LoadPrefabContents(prefabPath);
            SerializedGameObject serializedPrefab = null;
            if (prefabRoot != null)
            {
                try
                {
                    serializedPrefab = new SerializedGameObject(prefabRoot);
                    var cacheQueue = new Queue<Tuple<SerializedGameObject, List<int>>>();
                    cacheQueue.Enqueue(new Tuple<SerializedGameObject, List<int>>(serializedPrefab, new List<int>()));
                    while (cacheQueue.Count > 0)
                    {
                        var tuple = cacheQueue.Dequeue();
                        var serializedGameObject = tuple.Item1;
                        var hierarchyPathIndices = tuple.Item2;
                        referenceIdToPrefabInfo[serializedGameObject.referenceId] = new PrefabInfo {
                            prefabPath = prefabPath,
                            hierarchyPathIndices = new List<int>(hierarchyPathIndices),
                            isComponent = false
                        };
                        for (var i = 0; i < serializedGameObject.children.Length; i++)
                        {
                            var child = serializedGameObject.children[i];
                            var newHierarchyPathIndices = new List<int>(hierarchyPathIndices);
                            newHierarchyPathIndices.Add(i);
                            cacheQueue.Enqueue(new Tuple<SerializedGameObject, List<int>>(child, newHierarchyPathIndices));
                        }
                        for (var i = 0; i < serializedGameObject.components.Length; i++)
                        {
                            var component = serializedGameObject.components[i];
                            var newHierarchyPathIndices = new List<int>(hierarchyPathIndices);
                            newHierarchyPathIndices.Add(i);
                            referenceIdToPrefabInfo[component.referenceId] = new PrefabInfo {
                                prefabPath = prefabPath,
                                hierarchyPathIndices = newHierarchyPathIndices,
                                isComponent = true
                            };
                        }
                    }
                }
                catch (Exception e)
                {
                    Debug.LogError("Error serializing prefab: " + prefabPath + ": " + e.Message);
                }
                finally
                {
                    PrefabUtility.UnloadPrefabContents(prefabRoot);
                }
            }
            return serializedPrefab;
        }

        public static bool TryGet(string referenceId, out UnityEngine.Object obj)
        {
            if (referenceIdToPrefabInfo.TryGetValue(referenceId, out var prefabInfo))
            {
                if (!prefabRootsBeingEdited.TryGetValue(prefabInfo.prefabPath, out var prefabRoot))
                {
                    prefabRoot = PrefabUtility.LoadPrefabContents(prefabInfo.prefabPath);
                    prefabRootsBeingEdited[prefabInfo.prefabPath] = prefabRoot;
                }
                obj = prefabInfo.FindInPrefab(prefabRoot);
                return true;
            }
            obj = null;
            return false;
        }

        public static void EndEdits()
        {
            foreach (var prefabPath in prefabRootsBeingEdited.Keys)
            {
                PrefabUtility.SaveAsPrefabAsset(prefabRootsBeingEdited[prefabPath], prefabPath);
                PrefabUtility.UnloadPrefabContents(prefabRootsBeingEdited[prefabPath]);
            }
            prefabRootsBeingEdited.Clear();
        }
    }
}
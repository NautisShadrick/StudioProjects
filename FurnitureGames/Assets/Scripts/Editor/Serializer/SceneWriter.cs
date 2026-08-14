using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;
using System;
using System.Reflection;

namespace Rosie
{
    public static class SceneWriter
    {
        private const string RUNNING_PREF_KEY = "Highrise.SceneWriter.Running";
        private static readonly string WRITE_DIRECTORY = 
            System.IO.Path.Combine(System.IO.Path.GetFullPath("Temp"), "Highrise", "Serializer");
        
        private static bool running = false;
        private static readonly Dictionary<UnityEngine.Object, string> objectToId = new();
        private static readonly Dictionary<string, UnityEngine.Object> idToObject = new();
        private static int shouldSerializeInNFrames = -1;
        private static float nextReadEditTime = -1f;
        private static bool initialized = false;

        [InitializeOnLoadMethod]
        private static void OnEditorLoad()
        {
            // Unsubscribe from events if already initialized (handles editor reloads)
            if (initialized)
            {
                EditorSceneManager.sceneSaved -= MarkShouldSerialize;
                EditorSceneManager.sceneOpened -= MarkShouldSerialize;
                EditorApplication.update -= OnUpdate;
                EditorApplication.playModeStateChanged -= OnPlayModeStateChanged;
            }

            if (!System.IO.Directory.Exists(WRITE_DIRECTORY))
            {
                System.IO.Directory.CreateDirectory(WRITE_DIRECTORY);
            }
            
            running = EditorPrefs.GetBool(RUNNING_PREF_KEY, true);
            if (running)
            {
                shouldSerializeInNFrames = 2;
            }
            
            EditorSceneManager.sceneSaved += MarkShouldSerialize;
            EditorSceneManager.sceneOpened += MarkShouldSerialize;
            EditorApplication.update += OnUpdate;
            EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
            
            initialized = true;
        }

        [MenuItem("Highrise/Studio/Serialize to JSON", false)]
        private static void ToggleSerialize()
        {
            bool currentRunning = EditorPrefs.GetBool(RUNNING_PREF_KEY, true);
            bool newRunning = !currentRunning;
            
            running = newRunning;
            EditorPrefs.SetBool(RUNNING_PREF_KEY, newRunning);
            if (newRunning)
            {
                shouldSerializeInNFrames = 2;
            }
            
            Menu.SetChecked("Highrise/Studio/Serialize to JSON", newRunning);
        }

        [MenuItem("Highrise/Studio/Serialize to JSON", true)]
        private static bool ToggleSerializeValidate()
        {
            bool running = EditorPrefs.GetBool(RUNNING_PREF_KEY, true);
            Menu.SetChecked("Highrise/Studio/Serialize to JSON", running);
            return true;
        }

        private static void OnUpdate()
        {
            if (!running) return;
            if (shouldSerializeInNFrames > 0)
            {
                shouldSerializeInNFrames--;
                if (shouldSerializeInNFrames == 0)
                {
                    SerializeScene(EditorSceneManager.GetActiveScene());
                }
            }
            if (nextReadEditTime > 0f && Time.realtimeSinceStartup >= nextReadEditTime)
            {
                nextReadEditTime = Time.realtimeSinceStartup + 0.5f;
                ReadEdits();
            }
        }

        private static void ReadEdits()
        {
            string filePath = System.IO.Path.Combine(WRITE_DIRECTORY, "edit.json");
            if (!System.IO.File.Exists(filePath))
                return;

            var editData = System.IO.File.ReadAllText(filePath);
            var edits = JsonConvert.DeserializeObject<List<ObjectEditor.ObjectEdit>>(editData);
            System.IO.File.Delete(filePath);
            foreach (var edit in edits)
            {
                ObjectEditor.ReadEdit(edit);
            }
            PrefabHydrator.EndEdits();
            shouldSerializeInNFrames = 2;
        }

        private static void MarkShouldSerialize(UnityEngine.SceneManagement.Scene scene)
        {
            shouldSerializeInNFrames = 2;
        }

        private static void MarkShouldSerialize(UnityEngine.SceneManagement.Scene scene, OpenSceneMode mode)
        {
            shouldSerializeInNFrames = 2;
        }

        private static void OnPlayModeStateChanged(PlayModeStateChange state)
        {
            if (state == PlayModeStateChange.EnteredEditMode)
            {
                shouldSerializeInNFrames = 2;
            }
        }

        private static void SerializeScene(UnityEngine.SceneManagement.Scene scene)
        {
            string filePath = System.IO.Path.Combine(WRITE_DIRECTORY, "active_scene.json");
            System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(filePath));
            if (System.IO.File.Exists(filePath))
                System.IO.File.Delete(filePath);
            var rootObject = new SerializedGameObject(scene.GetRootGameObjects().Select(go => new SerializedGameObject(go)).ToArray());
            System.IO.File.WriteAllText(filePath, rootObject.ToString());
            nextReadEditTime = Time.realtimeSinceStartup + 0.5f;

            // write all of the addable component types to a file
            var allComponentTypes = GetAllAddableComponentTypes();
            var allComponentTypesFilePath = System.IO.Path.Combine(WRITE_DIRECTORY, "all_component_types.json");
            System.IO.File.WriteAllText(allComponentTypesFilePath, JsonConvert.SerializeObject(allComponentTypes, Formatting.Indented));

            // write all of the prefabs in the Assets directory to their own files
            string[] prefabPaths = AssetDatabase.FindAssets("t:Prefab", new[] { "Assets" }).Select(AssetDatabase.GUIDToAssetPath).ToArray();
            foreach (var prefabPath in prefabPaths)
            {
                var serializedPrefab = PrefabHydrator.SerializePrefab(prefabPath);
                var serializedPrefabPath = System.IO.Path.Combine(WRITE_DIRECTORY, prefabPath + ".json");
                var serializedPrefabDirectory = System.IO.Path.GetDirectoryName(serializedPrefabPath);
                if (!System.IO.Directory.Exists(serializedPrefabDirectory))
                {
                    System.IO.Directory.CreateDirectory(serializedPrefabDirectory);
                }
                System.IO.File.WriteAllText(serializedPrefabPath, serializedPrefab.ToString());
            }
        }

        public static string GetId(UnityEngine.Object obj)
        {
            if (!objectToId.TryGetValue(obj, out var id))
            {
                id = System.Guid.NewGuid().ToString();
                AssignId(obj, id);
            }
            return id;
        }

        public static UnityEngine.Object GetObject(string id)
        {
            if (idToObject.TryGetValue(id, out var obj))
            {
                if (PrefabHydrator.TryGet(id, out var prefabObj))
                {
                    return prefabObj;
                }
                return obj;
            }
            throw new System.Exception("Object with id " + id + " not found");
        }

        public static void AssignId(UnityEngine.Object obj, string id)
        {
            if (objectToId.ContainsKey(obj))
            {
                throw new System.Exception("Object already has an id: " + obj.name);
            }
            if (idToObject.ContainsKey(id))
            {
                throw new System.Exception("Id already exists: " + id);
            }
            objectToId[obj] = id;
            idToObject[id] = obj;
        }

        [Serializable]
        private class AddableComponentType
        {
            [Serializable]
            public class AddableComponentTypeProperty
            {
                public string propertyName;
                public string type;
            }
            public string fullName;
            public Dictionary<string, AddableComponentTypeProperty> properties;

            public AddableComponentType(Type type)
            {
                fullName = type.FullName;
                properties = SerializedComponent.GetPropertyList(type, null).Select(p => p()).ToDictionary(p => p.propertyName, p => new AddableComponentTypeProperty {
                    propertyName = p.propertyName,
                    type = p.type,
                });
            }
        }

        private static List<AddableComponentType> GetAllAddableComponentTypes()
        {
            var componentTypes = new List<AddableComponentType>();
            
            // Use Unity's TypeCache API for efficient type discovery
            var types = TypeCache.GetTypesDerivedFrom<Component>();
            
            foreach (var type in types)
            {
                if (type.IsAbstract || type.IsGenericType || type.IsInterface || !type.IsSubclassOf(typeof(MonoBehaviour)) || type.FullName.StartsWith("TMPro.") || type.FullName.StartsWith("UnityEngine.InputSystem.") || type.FullName.StartsWith("Spine.Unity."))
                    continue;
                
                try
                {  
                    componentTypes.Add(new AddableComponentType(type));
                }
                catch (Exception)
                {
                    continue;
                }
            }
            
            // Sort by full name for easier browsing
            componentTypes.Sort((a, b) => string.Compare(a.fullName, b.fullName, StringComparison.Ordinal));
            
            return componentTypes;
        }
    }
}
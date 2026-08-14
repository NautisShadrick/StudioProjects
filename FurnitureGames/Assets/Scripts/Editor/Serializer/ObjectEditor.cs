using UnityEditor;
using UnityEngine;
using System;
using System.Linq;
using System.IO;
using System.Collections.Generic;
using UnityEditorInternal;

namespace Rosie
{
    public static class ObjectEditor
    {
        public class ObjectEdit
        {
            public string editType;

            // delete
            public string referenceIdToDelete;

            // setProperty
            public string referenceIdOfObjectWithPropertyToSet;
            public string nameOfPropertyToSet;
            public object newPropertyValue;

            // createGameObject
            public string referenceIdOfParentGameObject;
            public string nameOfGameObjectToCreate;
            public string referenceIdOfGameObjectToCreate;
            public string prefabPathForGameObjectToCreate;

            // addComponent
            public string referenceIdOfGameObjectToAddComponent;
            public string componentTypeToAdd;
            public string referenceIdOfComponentToAdd;

            // saveObjectAsPrefab
            public string referenceIdOfObjectToSaveAsPrefab;
            public string pathToSavePrefabAs;

            public override string ToString()
            {
                switch (editType)
                {
                    case "delete":
                        return $"delete: {referenceIdToDelete}";
                    case "setProperty":
                        return $"setProperty: {referenceIdOfObjectWithPropertyToSet}, {nameOfPropertyToSet}, {newPropertyValue}";
                    case "createGameObject":
                        return $"createGameObject: {referenceIdOfParentGameObject}, {nameOfGameObjectToCreate}, {referenceIdOfGameObjectToCreate}, {prefabPathForGameObjectToCreate}";
                    case "addComponent":
                        return $"addComponent: {referenceIdOfGameObjectToAddComponent}, {componentTypeToAdd}, {referenceIdOfComponentToAdd}";
                    case "saveObjectAsPrefab":
                        return $"saveObjectAsPrefab: {referenceIdOfObjectToSaveAsPrefab}, {pathToSavePrefabAs}";
                    default:
                        return $"unknown: {editType}";
                }
            }
        }

        private static void DeleteObject(string referenceIdToDelete)
        {
            Undo.DestroyObjectImmediate(SceneWriter.GetObject(referenceIdToDelete));
        }

        private static void SetProperty(string referenceIdOfObjectWithPropertyToSet, string nameOfPropertyToSet, object newPropertyValue)
        {
            var obj = SceneWriter.GetObject(referenceIdOfObjectWithPropertyToSet);
            Undo.RecordObject(obj, "Set Property " + nameOfPropertyToSet);
            Transform transform = null;
            if (obj is GameObject gameObject)
            {
                switch (nameOfPropertyToSet)
                {
                    case "activeSelf":
                        gameObject.SetActive((bool)newPropertyValue);
                        return;
                    case "tag":
                        if (!InternalEditorUtility.tags.Contains((string)newPropertyValue))
                            InternalEditorUtility.AddTag((string)newPropertyValue);
                        gameObject.tag = (string)newPropertyValue;
                        return;
                    case "parentGameObject":
                        gameObject.transform.SetParent(newPropertyValue == null || (string)newPropertyValue == "SceneRoot" ? null : ((GameObject)SceneWriter.GetObject((string)newPropertyValue)).transform);
                        return;
                }
                gameObject.TryGetComponent(out transform);
            }
            var field = obj.GetType().GetField(nameOfPropertyToSet, System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance) ??
                        obj.GetType().GetField(nameOfPropertyToSet, System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            var property = obj.GetType().GetProperty(nameOfPropertyToSet, System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance) ??
                        obj.GetType().GetProperty(nameOfPropertyToSet, System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            var propertyType = property?.PropertyType ?? field?.FieldType ?? null;
            if (propertyType != null)
            {
                try
                {
                    var newValue = ValueSerializer.FromSerializable(newPropertyValue, propertyType);
                    if (property != null)
                    {
                        property.SetValue(obj, newValue);
                    }
                    else if (field != null)
                    {
                        field.SetValue(obj, newValue);
                    }
                }
                catch (NotImplementedException e)
                {
                    Debug.LogError("Could not set property or field: " + nameOfPropertyToSet +": " + e.Message);
                }
            }
            else if (transform != null)
            {
                ReadEdit(new ObjectEdit {
                    editType = "setProperty",
                    referenceIdOfObjectWithPropertyToSet = SceneWriter.GetId(transform),
                    nameOfPropertyToSet = nameOfPropertyToSet,
                    newPropertyValue = newPropertyValue,
                });
            }
            else 
            {
                Debug.LogError("Could not find property or field to edit: " + nameOfPropertyToSet);
            }
        }

        private static void CreateGameObject(string referenceIdOfParentGameObject, string nameOfGameObjectToCreate, string referenceIdOfGameObjectToCreate, string prefabPathForGameObjectToCreate)
        {
            GameObject gameObject;
            if (prefabPathForGameObjectToCreate != null)
            {
                gameObject = PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>(prefabPathForGameObjectToCreate)) as GameObject;
                gameObject.name = nameOfGameObjectToCreate;
            }
            else
            {
                gameObject = new GameObject(nameOfGameObjectToCreate);
            }
            SceneWriter.AssignId(gameObject, referenceIdOfGameObjectToCreate);
            if (referenceIdOfParentGameObject != null && referenceIdOfParentGameObject != "SceneRoot")
            {
                gameObject.transform.SetParent(((GameObject)SceneWriter.GetObject(referenceIdOfParentGameObject)).transform);
            }
            Undo.RegisterCreatedObjectUndo(gameObject, "Create Game Object");
        }

        private static void AddComponent(string referenceIdOfGameObjectToAddComponent, string componentTypeToAdd, string referenceIdOfComponentToAdd)
        {
            var gameObject = SceneWriter.GetObject(referenceIdOfGameObjectToAddComponent);
            Type componentType = ((Type.GetType(componentTypeToAdd) ?? Type.GetType("UnityEngine." + componentTypeToAdd + ", UnityEngine.CoreModule")) ?? AppDomain.CurrentDomain.GetAssemblies()
                .SelectMany(assembly => {
                    try
                    {
                        return assembly.GetTypes();
                    }
                    catch (System.Reflection.ReflectionTypeLoadException ex)
                    {
                        // Return only successfully loaded types, filtering out null entries
                        return ex.Types.Where(t => t != null);
                    }
                })
                .FirstOrDefault(type => (type.Name == componentTypeToAdd || type.FullName == componentTypeToAdd) && type.IsSubclassOf(typeof(Component))));
            if (componentType == null)
            {
                Debug.LogError("Could not find component type: " + componentTypeToAdd);
                return;
            }
            SceneWriter.AssignId(Undo.AddComponent((GameObject)gameObject, componentType), referenceIdOfComponentToAdd);
        }

        private static void SaveObjectAsPrefab(string referenceIdOfObjectToSaveAsPrefab, string pathToSavePrefabAs)
        {
            var obj = SceneWriter.GetObject(referenceIdOfObjectToSaveAsPrefab);
            if (!System.IO.Directory.Exists(System.IO.Path.GetDirectoryName(pathToSavePrefabAs)))
                System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(pathToSavePrefabAs));
            PrefabUtility.SaveAsPrefabAssetAndConnect(obj as GameObject, pathToSavePrefabAs, InteractionMode.AutomatedAction);
        }
        
        public static void ReadEdit(ObjectEdit edit)
        {
            try {
                switch (edit.editType)
                {
                    case "delete":
                        DeleteObject(edit.referenceIdToDelete);
                        break;
                    case "setProperty":
                        SetProperty(edit.referenceIdOfObjectWithPropertyToSet, edit.nameOfPropertyToSet, edit.newPropertyValue);
                        break;
                    case "createGameObject":
                        CreateGameObject(edit.referenceIdOfParentGameObject, edit.nameOfGameObjectToCreate, edit.referenceIdOfGameObjectToCreate, edit.prefabPathForGameObjectToCreate);
                        break;
                    case "addComponent":
                        AddComponent(edit.referenceIdOfGameObjectToAddComponent, edit.componentTypeToAdd, edit.referenceIdOfComponentToAdd);
                        break;
                    case "saveObjectAsPrefab":
                        SaveObjectAsPrefab(edit.referenceIdOfObjectToSaveAsPrefab, edit.pathToSavePrefabAs);
                        break;
                    default:
                        Debug.LogError("Unknown edit type: " + edit.editType);
                        break;
                }
            }
            catch (Exception e)
            {
                Debug.LogError("Error reading edit " + edit + ": " + e.Message);
            }
        }
    }
}
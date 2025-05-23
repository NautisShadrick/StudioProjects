/*

    Copyright (c) 2025 Pocketz World. All rights reserved.

    This is a generated file, do not edit!

    Generated by com.pz.studio
*/

#if UNITY_EDITOR

using System;
using System.Linq;
using UnityEngine;
using Highrise.Client;
using Highrise.Studio;
using Highrise.Lua;
using UnityEditor;

namespace Highrise.Lua.Generated
{
    [AddComponentMenu("Lua/GameManager")]
    [LuaRegisterType(0x64f367123469100e, typeof(LuaBehaviour))]
    public class GameManager : LuaBehaviourThunk
    {
        private const string s_scriptGUID = "f3bd7b9868e247c44b2954b0a437ae13";
        public override string ScriptGUID => s_scriptGUID;

        [LuaScriptPropertyAttribute("23cd905668bc38c409bff901e234a5e8")]
        [SerializeField] public System.Collections.Generic.List<UnityEngine.Object> m_LootTables = default;

        protected override SerializedPropertyValue[] SerializeProperties()
        {
            if (_script == null)
                return Array.Empty<SerializedPropertyValue>();

            return new SerializedPropertyValue[]
            {
                CreateSerializedProperty(_script.GetPropertyAt(0), m_LootTables),
            };
        }
        
#if HR_STUDIO
        [MenuItem("CONTEXT/GameManager/Edit Script")]
        private static void EditScript()
        {
            VisualStudioCodeOpener.OpenPath(AssetDatabase.GUIDToAssetPath(s_scriptGUID));
        }
#endif
    }
}

#endif

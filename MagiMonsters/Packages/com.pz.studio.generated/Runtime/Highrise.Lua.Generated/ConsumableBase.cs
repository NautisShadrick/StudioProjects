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
    [CreateAssetMenu(menuName = "Highrise/ScriptableObjects/ConsumableBase")]
    [LuaRegisterType(0x757374bd8b81562f, typeof(LuaScriptableObject))]
    public class ConsumableBase : LuaScriptableObjectThunk
    {
        private const string s_scriptGUID = "36cff7809ecd4cb4fadbd08fcdf6c9af";
        public override string ScriptGUID => s_scriptGUID;

        [SerializeField] public System.String m_id = "";
        [SerializeField] public System.String m_displayName = "";
        [SerializeField] public UnityEngine.Texture m_sprite = default;
        [SerializeField] public System.String m_description = "";
        [SerializeField] public System.String m_element = "";
        [SerializeField] public System.Double m_rarity = 0;
        [SerializeField] public System.Double m_value = 0;
        [SerializeField] public System.String m_effect = "";
        [SerializeField] public System.Double m_strength = 0;
        [SerializeField] public System.Collections.Generic.List<System.String> m_recipeMaterialIDs = default;
        [SerializeField] public System.Collections.Generic.List<System.Double> m_recipeMaterialAmounts = default;

        protected override SerializedPropertyValue[] SerializeProperties()
        {
            if (_script == null)
                return Array.Empty<SerializedPropertyValue>();

            return new SerializedPropertyValue[]
            {
                CreateSerializedProperty(_script.GetPropertyAt(0), m_id),
                CreateSerializedProperty(_script.GetPropertyAt(1), m_displayName),
                CreateSerializedProperty(_script.GetPropertyAt(2), m_sprite),
                CreateSerializedProperty(_script.GetPropertyAt(3), m_description),
                CreateSerializedProperty(_script.GetPropertyAt(4), m_element),
                CreateSerializedProperty(_script.GetPropertyAt(5), m_rarity),
                CreateSerializedProperty(_script.GetPropertyAt(6), m_value),
                CreateSerializedProperty(_script.GetPropertyAt(7), m_effect),
                CreateSerializedProperty(_script.GetPropertyAt(8), m_strength),
                CreateSerializedProperty(_script.GetPropertyAt(9), m_recipeMaterialIDs),
                CreateSerializedProperty(_script.GetPropertyAt(10), m_recipeMaterialAmounts),
            };
        }
        
#if HR_STUDIO
        [MenuItem("CONTEXT/ConsumableBase/Edit Script")]
        private static void EditScript()
        {
            VisualStudioCodeOpener.OpenPath(AssetDatabase.GUIDToAssetPath(s_scriptGUID));
        }
#endif
    }
}

#endif

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

namespace Highrise.Lua.Generated
{
    [AddComponentMenu("Lua/WanderingNPCSpawner")]
    [LuaRegisterType(0x8347c13fbd86c2d9, typeof(LuaBehaviour))]
    public class WanderingNPCSpawner : LuaBehaviourThunk
    {
        private const string s_scriptGUID = "49dd10206965be440affecde393283f8";
        public override string ScriptGUID => s_scriptGUID;

        [SerializeField] public UnityEngine.GameObject m_WanderingNPCPrefab = default;

        protected override SerializedPropertyValue[] SerializeProperties()
        {
            if (_script == null)
                return Array.Empty<SerializedPropertyValue>();

            return new SerializedPropertyValue[]
            {
                CreateSerializedProperty(_script.GetPropertyAt(0), m_WanderingNPCPrefab),
            };
        }
    }
}

#endif

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
    [AddComponentMenu("Lua/AudioManager")]
    [LuaRegisterType(0x54ef1694c40a5ef8, typeof(LuaBehaviour))]
    public class AudioManager : LuaBehaviourThunk
    {
        private const string s_scriptGUID = "ee709a0a5b42eef4fb1b8016d07ad53b";
        public override string ScriptGUID => s_scriptGUID;

        [SerializeField] public Highrise.AudioShader m_bgm = default;
        [SerializeField] public System.Collections.Generic.List<Highrise.AudioShader> m_sounds = default;

        protected override SerializedPropertyValue[] SerializeProperties()
        {
            if (_script == null)
                return Array.Empty<SerializedPropertyValue>();

            return new SerializedPropertyValue[]
            {
                CreateSerializedProperty(_script.GetPropertyAt(0), m_bgm),
                CreateSerializedProperty(_script.GetPropertyAt(1), m_sounds),
            };
        }
    }
}

#endif

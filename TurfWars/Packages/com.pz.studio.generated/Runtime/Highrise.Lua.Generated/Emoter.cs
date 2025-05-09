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
    [AddComponentMenu("Lua/Emoter")]
    [LuaRegisterType(0x4be7262d95848bc3, typeof(LuaBehaviour))]
    public class Emoter : LuaBehaviourThunk
    {
        private const string s_scriptGUID = "d544fc5a32d4c034ca32772bfe68b019";
        public override string ScriptGUID => s_scriptGUID;

        [SerializeField] public System.String m_emote = "";

        protected override SerializedPropertyValue[] SerializeProperties()
        {
            if (_script == null)
                return Array.Empty<SerializedPropertyValue>();

            return new SerializedPropertyValue[]
            {
                CreateSerializedProperty(_script.GetPropertyAt(0), m_emote),
            };
        }
    }
}

#endif

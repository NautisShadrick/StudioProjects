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
    [AddComponentMenu("Lua/UiManager")]
    [LuaRegisterType(0x5728af4363cec11a, typeof(LuaBehaviour))]
    public class UiManager : LuaBehaviourThunk
    {
        private const string s_scriptGUID = "8648913d581abe5458641a3c27e269d2";
        public override string ScriptGUID => s_scriptGUID;

        [SerializeField] public UnityEngine.GameObject m_CreateQuestionOBJ = default;
        [SerializeField] public UnityEngine.GameObject m_AnswersOBJ = default;
        [SerializeField] public UnityEngine.GameObject m_hudButtonsOBJ = default;
        [SerializeField] public UnityEngine.GameObject m_resultsOBJ = default;

        protected override SerializedPropertyValue[] SerializeProperties()
        {
            if (_script == null)
                return Array.Empty<SerializedPropertyValue>();

            return new SerializedPropertyValue[]
            {
                CreateSerializedProperty(_script.GetPropertyAt(0), m_CreateQuestionOBJ),
                CreateSerializedProperty(_script.GetPropertyAt(1), m_AnswersOBJ),
                CreateSerializedProperty(_script.GetPropertyAt(2), m_hudButtonsOBJ),
                CreateSerializedProperty(_script.GetPropertyAt(3), m_resultsOBJ),
            };
        }
    }
}

#endif

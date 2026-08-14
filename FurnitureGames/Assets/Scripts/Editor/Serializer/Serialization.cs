using System;
using System.Linq;
using UnityEngine;
using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEditor;

namespace Rosie
{
    [Serializable]
    public class SerializedGameObject
    {
        public string referenceId;
        public Dictionary<string, object> objectProperties;
        public SerializedComponent[] components;
        public SerializedGameObject[] children;
        public SerializedGameObject(GameObject go)
        {
            referenceId = SceneWriter.GetId(go);
            objectProperties = new Dictionary<string, object> {
                { "name", go.name },
                { "activeSelf", go.activeSelf },
                { "tag", go.tag },
                { "parentGameObject", go.transform.parent != null ? SceneWriter.GetId(go.transform.parent.gameObject) : null },
                { "prefabPath", PrefabUtility.IsPartOfPrefabInstance(go) ? AssetDatabase.GetAssetPath(PrefabUtility.GetCorrespondingObjectFromSource(go)) : null }
            };
            components = go.GetComponents<Component>().Select(c => new SerializedComponent(c)).ToArray();
            children = go.transform.Cast<Transform>().Select(child => new SerializedGameObject(child.gameObject)).ToArray();
        }

        public SerializedGameObject(SerializedGameObject[] serializedObjects)
        {
            referenceId = "SceneRoot";
            objectProperties = new Dictionary<string, object> {
                { "name", "SceneRoot" },
                { "activeSelf", true },
                { "tag", "Untagged" },
                { "parentGameObject", null },
                { "prefabPath", null }
            };
            components = new SerializedComponent[0];
            children = serializedObjects;
        }

        public override string ToString()
        {
            return JsonConvert.SerializeObject(this, Formatting.Indented);
        }
    }

    [Serializable]
    public class SerializedComponent
    {
        public string componentType;
        public string referenceId;
        public Dictionary<string, SerializedProperty> properties;

        public SerializedComponent(Component component)
        {
            referenceId = SceneWriter.GetId(component);
            var scriptType = component.GetType();
            componentType = scriptType.FullName;
            properties = GetPropertyList(scriptType, component).Select(f => f()).Where(p => p != null && p.type != null).ToDictionary(p => p.propertyName, p => p);
        }

        public static List<Func<SerializedProperty>> GetPropertyList(Type scriptType, Component component)
        {
            var propertyList = new List<Func<SerializedProperty>>();

            var fields = scriptType.GetFields(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Where(f => fieldInclusionRules.All(rule => rule(component, f)));
            foreach (var field in fields)
            {
                propertyList.Add(() => new SerializedProperty(field.Name, field.FieldType, component != null ? field.GetValue(component) : null));
            }
            var props = scriptType.GetProperties(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance)
                    .Where(p => propertyInclusionRules.All(rule => rule(component, p)));
            foreach (var property in props)
            {
                propertyList.Add(() => new SerializedProperty(property.Name, property.PropertyType, component != null ? property.GetValue(component) : null));
            }
            return propertyList;
        }

        public override string ToString()
        {
            return JsonConvert.SerializeObject(this);
        }


        // All of these must be satisfied for a field to be serialized.
        private static readonly List<Func<Component, System.Reflection.FieldInfo, bool>> fieldInclusionRules = new() {
            (c, f) => f.IsPublic || f.GetCustomAttributes(typeof(SerializeField), true).Length > 0,
            (c, f) => f.GetCustomAttributes(typeof(ObsoleteAttribute), true).Length == 0,
            (c, f) => c?.GetType().Namespace?.StartsWith("Highrise.Lua.Generated") != true || !f.Name.StartsWith("_") || (f.FieldType.Name == "LuaScript" && f.Name == "_script") || f.Name == "_uiOutput",
            (c, f) => ValueSerializer.IsSupportedType(f.FieldType),
        };

        // All of these must be satisfied for a property to be serialized.
        private static readonly List<Func<Component, System.Reflection.PropertyInfo, bool>> propertyInclusionRules = new() {
            (c, p) => p.CanRead && p.CanWrite,
            (c, p) => p.GetCustomAttributes(typeof(SerializeField), true).Length > 0 ||
                    p.GetCustomAttributes(typeof(SerializeReference), true).Length > 0 ||
                    c?.GetType().Namespace?.StartsWith("UnityEngine") == true ||
                    c?.GetType().Namespace?.StartsWith("TMPro") == true,
            (c, p) => p.GetCustomAttributes(typeof(HideInInspector), true).Length == 0,
            (c, p) => p.GetCustomAttributes(typeof(ObsoleteAttribute), true).Length == 0,
            (c, p) => ValueSerializer.IsSupportedType(p.PropertyType),
        };
    }

    [Serializable]
    public class SerializedProperty
    {
        public string propertyName;
        public string type;
        public object value;

        public SerializedProperty(string name, Type type, object value)
        {
            this.propertyName = name;
            this.type = type != null ? (type.IsEnum ? type.FullName + " (" + string.Join(", ", Enum.GetValues(type).Cast<object>().Select(v => v.ToString())) + ")" : ValueSerializer.GetFriendlyTypeName(type)) : null;
            try
            {
                this.value = ValueSerializer.ToSerializable(value);
            }
            catch (NotImplementedException)
            {
                // No appropriate parser was found, signal that the property should not be serialized.
                this.type = null;
            }
        }
    }
    
    public static class ValueSerializer
    {
        private static bool CompareTypes(Type type, Type unsupportedType)
        {
            return type == unsupportedType || type.IsSubclassOf(unsupportedType) || type.GetInterfaces().Contains(unsupportedType);
        }
        public static bool IsSupportedType(Type type)
        {
            return unsupportedTypes.All(
                (ut) => {
                    if (CompareTypes(type, ut))
                    {
                        return false;
                    }
                    if (type.IsArray && CompareTypes(type.GetElementType(), ut))
                    {
                        return false;
                    }
                    if (type.IsGenericType && type.GetGenericTypeDefinition() == typeof(List<>) && CompareTypes(type.GetGenericArguments()[0], ut))
                    {
                        return false;
                    }
                    return true;
                }
            );
        }
        public static string GetFriendlyTypeName(Type type)
        {
            if (type.IsGenericType)
            {
                var genericArgs = string.Join(", ", type.GetGenericArguments().Select(GetFriendlyTypeName));
                return $"{type.Name.Split('`')[0]}<{genericArgs}>";
            }
            return type.FullName;
        }

        public static object ToSerializable(object value)
        {
            if (value == null)
            {
                return null;
            }
            var parser = GetParser(value, value.GetType());
            if (parser != null)
            {
                return parser.ToSerializable(value);
            }
            throw new NotImplementedException($"No appropriate parser was found for type {GetFriendlyTypeName(value.GetType())}");
        }

        public static object FromSerializable(object serializable, Type vType)
        {
            if (serializable == null)
            {
                return null;
            }
            var parser = GetParser(vType);
            if (parser != null)
            {
                return parser.FromSerializable(serializable);
            }
            throw new NotImplementedException($"No appropriate parser was found for type {GetFriendlyTypeName(vType)}");
        }
        
        private interface IValueParser
        {
            Type ParsedType { get; }
            object ToSerializable(object value);
            object FromSerializable(object serializable);
        }
        private static readonly List<IValueParser> parsers = new() {
            new Vector2Parser(),
            new Vector3Parser(),
            new Vector4Parser(),
            new QuaternionParser(),
            new BoundsParser(),
            new ColorParser(),
            new Matrix4x4Parser(),
            new RectParser(),
            new GameObjectParser(),
            new ComponentParser(),
            new LuaScriptParser(),
        };

        private static readonly List<Type> unsupportedTypes = new() {
            typeof(Material),
            typeof(Mesh),
            typeof(UnityEngine.AI.NavMeshData),
        };

        private static IValueParser GetParser(object value, Type vType)
        {
            var parser = GetParser(vType);
            if (parser != null)
            {
                return parser;
            }
            try
            {
                JsonConvert.SerializeObject(value);
                parser = new PassThroughParser(vType);
                parsers.Add(parser);
                return parser;
            }
            catch
            {
                return null;
            }
        }

        private static IValueParser GetParser(Type vType)
        {
            IValueParser bestParser = null;
            bool isBestParserSubclass = false;
            foreach (var parser in parsers)
            {
                if (vType == parser.ParsedType)
                {
                    // exact match, return immediately
                    return parser;
                }
                else if (vType.IsSubclassOf(parser.ParsedType) && (!isBestParserSubclass || parser.ParsedType.IsSubclassOf(bestParser.ParsedType)))
                {
                    bestParser = parser;
                    isBestParserSubclass = true;
                }
                else if (vType.GetInterfaces().Contains(parser.ParsedType) && !isBestParserSubclass)
                {
                    bestParser = parser;
                    isBestParserSubclass = false;
                }
            }
            if (bestParser != null)
            {
                return bestParser;
            }
            if (vType.IsArray)
            {
                var parser = new ArrayParser(vType.GetElementType());
                parsers.Add(parser);
                return parser;
            }
            if (vType.IsGenericType && vType.GetGenericTypeDefinition() == typeof(List<>))
            {
                var parser = new ListParser(vType.GetGenericArguments()[0]);
                parsers.Add(parser);
                return parser;
            }
            if (vType.IsEnum)
            {
                var parser = new EnumParser(vType);
                parsers.Add(parser);
                return parser;
            }
            return null;
        }

        // Special parsers
        private class ListParser : IValueParser
        {
            private readonly Type elementType;
            public ListParser(Type elementType)
            {
                this.elementType = elementType;
            }
            public Type ParsedType => typeof(List<>).MakeGenericType(elementType);
            public object ToSerializable(object value) {
                return ((System.Collections.IEnumerable)value).Cast<object>().Select(ValueSerializer.ToSerializable).ToList();
            }
            public object FromSerializable(object serializable) {
                return ((System.Collections.IEnumerable)serializable).Cast<object>().Select(s => ValueSerializer.FromSerializable(s, elementType)).ToList();
            }
        }

        private class ArrayParser : IValueParser
        {
            private readonly Type elementType;
            public ArrayParser(Type elementType)
            {
                this.elementType = elementType;
            }
            public Type ParsedType => typeof(Array);
            public object ToSerializable(object value) {
                return ((Array)value).Cast<object>().Select(ValueSerializer.ToSerializable).ToArray();
            }
            public object FromSerializable(object serializable) {
                return ((Array)serializable).Cast<object>().Select(s => ValueSerializer.FromSerializable(s, elementType)).ToArray();
            }
        }

        private class PassThroughParser : IValueParser
        {
            private readonly Type parsedType;
            public PassThroughParser(Type parsedType)
            {
                this.parsedType = parsedType;
            }
            public Type ParsedType => parsedType;
            public object ToSerializable(object value) => value;
            public object FromSerializable(object serializable) => Convert.ChangeType(serializable, parsedType);
        }
        
        private class EnumParser : IValueParser
        {
            private readonly Type enumType;
            public EnumParser(Type enumType)
            {
                this.enumType = enumType;
            }
            public Type ParsedType => enumType;
            public object ToSerializable(object value) => ((Enum)value).ToString();
            public object FromSerializable(object serializable) => Enum.Parse(enumType, (string)serializable);
        }

        // Unity parsers

        private class Vector2Parser : IValueParser
        {
            public Type ParsedType => typeof(Vector2);
            public object ToSerializable(object value) => new { x = ((Vector2)value).x, y = ((Vector2)value).y };
            public object FromSerializable(object serializable) => new Vector2(((JObject)serializable)["x"].Value<float>(), ((JObject)serializable)["y"].Value<float>());
        }

        private class Vector3Parser : IValueParser
        {
            public Type ParsedType => typeof(Vector3);
            public object ToSerializable(object value) => new { x = ((Vector3)value).x, y = ((Vector3)value).y, z = ((Vector3)value).z };
            public object FromSerializable(object serializable) => new Vector3(((JObject)serializable)["x"].Value<float>(), ((JObject)serializable)["y"].Value<float>(), ((JObject)serializable)["z"].Value<float>());
        }

        private class Vector4Parser : IValueParser
        {
            public Type ParsedType => typeof(Vector4);
            public object ToSerializable(object value) => new { x = ((Vector4)value).x, y = ((Vector4)value).y, z = ((Vector4)value).z, w = ((Vector4)value).w };
            public object FromSerializable(object serializable) => new Vector4(((JObject)serializable)["x"].Value<float>(), ((JObject)serializable)["y"].Value<float>(), ((JObject)serializable)["z"].Value<float>(), ((JObject)serializable)["w"].Value<float>());
        }

        private class QuaternionParser : IValueParser
        {
            public Type ParsedType => typeof(Quaternion);
            public object ToSerializable(object value) => new { x = ((Quaternion)value).x, y = ((Quaternion)value).y, z = ((Quaternion)value).z, w = ((Quaternion)value).w };
            public object FromSerializable(object serializable) => new Quaternion(((JObject)serializable)["x"].Value<float>(), ((JObject)serializable)["y"].Value<float>(), ((JObject)serializable)["z"].Value<float>(), ((JObject)serializable)["w"].Value<float>());
        }

        private class BoundsParser : IValueParser
        {
            public Type ParsedType => typeof(Bounds);
            public object ToSerializable(object value) => new { center = new { x = ((Bounds)value).center.x, y = ((Bounds)value).center.y, z = ((Bounds)value).center.z }, size = new { x = ((Bounds)value).size.x, y = ((Bounds)value).size.y, z = ((Bounds)value).size.z } };
            public object FromSerializable(object serializable) => new Bounds(
                new Vector3(((JObject)serializable)["center"]["x"].Value<float>(), ((JObject)serializable)["center"]["y"].Value<float>(), ((JObject)serializable)["center"]["z"].Value<float>()),
                new Vector3(((JObject)serializable)["size"]["x"].Value<float>(), ((JObject)serializable)["size"]["y"].Value<float>(), ((JObject)serializable)["size"]["z"].Value<float>())
            );
        }

        private class ColorParser : IValueParser
        {
            public Type ParsedType => typeof(Color);
            public object ToSerializable(object value) => new { r = ((Color)value).r, g = ((Color)value).g, b = ((Color)value).b, a = ((Color)value).a };
            public object FromSerializable(object serializable) => new Color(((JObject)serializable)["r"].Value<float>(), ((JObject)serializable)["g"].Value<float>(), ((JObject)serializable)["b"].Value<float>(), ((JObject)serializable)["a"].Value<float>());
        }

        private class Matrix4x4Parser : IValueParser
        {
            public Type ParsedType => typeof(Matrix4x4);
            public object ToSerializable(object value) => new { m00 = ((Matrix4x4)value).m00, m01 = ((Matrix4x4)value).m01, m02 = ((Matrix4x4)value).m02, m03 = ((Matrix4x4)value).m03, m10 = ((Matrix4x4)value).m10, m11 = ((Matrix4x4)value).m11, m12 = ((Matrix4x4)value).m12, m13 = ((Matrix4x4)value).m13, m20 = ((Matrix4x4)value).m20, m21 = ((Matrix4x4)value).m21, m22 = ((Matrix4x4)value).m22, m23 = ((Matrix4x4)value).m23, m30 = ((Matrix4x4)value).m30, m31 = ((Matrix4x4)value).m31, m32 = ((Matrix4x4)value).m32, m33 = ((Matrix4x4)value).m33 };
            public object FromSerializable(object serializable) {
                return new Matrix4x4(
                    new Vector4(((JObject)serializable)["m00"].Value<float>(), ((JObject)serializable)["m01"].Value<float>(), ((JObject)serializable)["m02"].Value<float>(), ((JObject)serializable)["m03"].Value<float>()),
                    new Vector4(((JObject)serializable)["m10"].Value<float>(), ((JObject)serializable)["m11"].Value<float>(), ((JObject)serializable)["m12"].Value<float>(), ((JObject)serializable)["m13"].Value<float>()),
                    new Vector4(((JObject)serializable)["m20"].Value<float>(), ((JObject)serializable)["m21"].Value<float>(), ((JObject)serializable)["m22"].Value<float>(), ((JObject)serializable)["m23"].Value<float>()),
                    new Vector4(((JObject)serializable)["m30"].Value<float>(), ((JObject)serializable)["m31"].Value<float>(), ((JObject)serializable)["m32"].Value<float>(), ((JObject)serializable)["m33"].Value<float>())
                );
            }
        }

        private class RectParser : IValueParser
        {
            public Type ParsedType => typeof(Rect);
            public object ToSerializable(object value) => new { x = ((Rect)value).x, y = ((Rect)value).y, width = ((Rect)value).width, height = ((Rect)value).height };
            public object FromSerializable(object serializable) => new Rect(((JObject)serializable)["x"].Value<float>(), ((JObject)serializable)["y"].Value<float>(), ((JObject)serializable)["width"].Value<float>(), ((JObject)serializable)["height"].Value<float>());
        }

        private class GameObjectParser : IValueParser
        {
            public Type ParsedType => typeof(GameObject);
            public object ToSerializable(object value) => SceneWriter.GetId((GameObject)value);
            public object FromSerializable(object serializable) => SceneWriter.GetObject((string)serializable);
        }

        private class ComponentParser : IValueParser
        {
            public Type ParsedType => typeof(Component);
            public object ToSerializable(object value) => SceneWriter.GetId((Component)value);
            public object FromSerializable(object serializable) => SceneWriter.GetObject((string)serializable);
        }

        private class LuaScriptParser : IValueParser
        {
            public Type ParsedType => typeof(Highrise.Lua.LuaScript);
            public object ToSerializable(object value) => new {
                scriptName = ((Highrise.Lua.LuaScript)value).name,
                path = ((Highrise.Lua.LuaScript)value).FullName,
                runsOn = ((Highrise.Lua.LuaScript)value).RunsOnClientAndServer ? "ClientAndServer" : ((Highrise.Lua.LuaScript)value).RunsOnClient ? "Client" : ((Highrise.Lua.LuaScript)value).RunsOnServer ? "Server" : "None",
            };
            public object FromSerializable(object serializable) => throw new NotImplementedException();
        }
    }
}
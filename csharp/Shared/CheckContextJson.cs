using System.Collections.Generic;
using System.Text.Json;

namespace TaleScript.Tools
{
    /// Builds a check context from the JSON format the conformance suite
    /// uses (see conformance/README.md). Shared by the conformance runner
    /// and the command-line checker.
    internal static class CheckContextJson
    {
        public static List<string> Strings(JsonElement element)
        {
            var list = new List<string>();
            if (element.ValueKind == JsonValueKind.Array)
                foreach (var item in element.EnumerateArray()) list.Add(item.GetString());
            return list;
        }

        public static bool TryGet(JsonElement? settings, string key, out JsonElement value)
        {
            value = default(JsonElement);
            return settings.HasValue && settings.Value.TryGetProperty(key, out value);
        }

        public static TaleCheckContext ContextFor(JsonElement? settings, string taleName)
        {
            var context = new TaleCheckContext();
            JsonElement value;
            context.TaleName = TryGet(settings, "tale_name", out value) ? value.GetString() : taleName;
            if (TryGet(settings, "actions", out value))
            {
                foreach (var action in value.EnumerateObject())
                {
                    JsonElement p, r;
                    var parameters = action.Value.TryGetProperty("params", out p) ? Strings(p) : new List<string>();
                    int required = action.Value.TryGetProperty("required", out r) ? r.GetInt32() : 0;
                    context.AddAction(action.Name, parameters, required);
                }
            }
            if (TryGet(settings, "actions_unchecked", out value))
                foreach (string action in Strings(value)) context.AddActionUnchecked(action);
            if (TryGet(settings, "cast", out value))
            {
                foreach (var entry in value.EnumerateObject())
                {
                    if (entry.Value.ValueKind == JsonValueKind.Object)
                    {
                        JsonElement m, f;
                        context.AddCast(entry.Name,
                            entry.Value.TryGetProperty("moods", out m) ? Strings(m) : null,
                            entry.Value.TryGetProperty("fields", out f) ? Strings(f) : null);
                    }
                    else
                    {
                        context.AddCast(entry.Name, Strings(entry.Value));
                    }
                }
            }
            if (TryGet(settings, "exposed", out value))
                foreach (string name in Strings(value)) context.AddExposed(name);
            if (TryGet(settings, "tales", out value))
            {
                foreach (var other in value.EnumerateObject())
                {
                    JsonElement b, v;
                    context.AddTale(other.Name,
                        other.Value.TryGetProperty("beats", out b) ? Strings(b) : new List<string>(),
                        other.Value.TryGetProperty("vars", out v) ? Strings(v) : new List<string>());
                }
            }
            return context;
        }
    }
}

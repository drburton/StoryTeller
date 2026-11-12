using System;
using System.Collections.Generic;
using System.Text;

namespace TaleScript
{
    /// <summary>One string players see: its translation key, its source text, and a note for translators.</summary>
    public class TaleStringEntry
    {
        public string Key = "";
        public string Text = "";
        public string Context = "";
    }

    /// <summary>
    /// The strings CSV of decision 0011, the same file the Godot plugin's Export Strings writes:
    /// a <c>keys</c> column, one column per language (the source language first), and
    /// <c>_context</c> and <c>_status</c> columns for translators. Lines and choice options are
    /// keyed "tale:line-id"; names, titles, and menu text are keyed by their source text.
    /// </summary>
    public class TaleStrings
    {
        public const string ContextColumn = "_context";
        public const string StatusColumn = "_status";
        public const string StatusUnused = "unused";
        public const string StatusChanged = "source changed";

        /// <summary>The language columns, in file order.</summary>
        public readonly List<string> Languages = new List<string>();
        /// <summary>The keys, in file order.</summary>
        public readonly List<string> Order = new List<string>();
        /// <summary>Key to its row: column name to text.</summary>
        public readonly Dictionary<string, Dictionary<string, string>> Rows = new Dictionary<string, Dictionary<string, string>>();

        /// <summary>Reads a strings CSV. Empty or missing text gives an empty table.</summary>
        public static TaleStrings Parse(string csv)
        {
            var table = new TaleStrings();
            if (string.IsNullOrEmpty(csv)) return table;
            List<List<string>> records = ParseCsv(csv);
            if (records.Count == 0) return table;
            List<string> header = records[0];
            for (int i = 1; i < header.Count; i++)
                if (!header[i].StartsWith("_", StringComparison.Ordinal)) table.Languages.Add(header[i]);
            for (int r = 1; r < records.Count; r++)
            {
                List<string> line = records[r];
                if (line.Count < 2 || line[0].Length == 0) continue;
                var row = new Dictionary<string, string>();
                for (int i = 1; i < Math.Min(line.Count, header.Count); i++) row[header[i]] = line[i];
                if (!table.Rows.ContainsKey(line[0])) table.Order.Add(line[0]);
                table.Rows[line[0]] = row;
            }
            return table;
        }

        /// <summary>
        /// The translation of a key in a language, or the key when there is none. In the source
        /// language, lines ("tale:id") give back the key, so the tale's own text is shown.
        /// </summary>
        public string Translate(string key, string language)
        {
            Dictionary<string, string> row;
            string text;
            if (key == null || language == null || !Rows.TryGetValue(key, out row)) return key;
            return row.TryGetValue(language, out text) && !string.IsNullOrEmpty(text) ? text : key;
        }

        /// <summary>
        /// Writes entries as a strings CSV, merging with an existing file: translations are kept,
        /// new keys are added, keys no longer used are marked "unused", and keys whose source text
        /// changed while they have translations are marked "source changed".
        /// </summary>
        public static string Write(string existingCsv, IEnumerable<TaleStringEntry> entries, string sourceLanguage, IEnumerable<string> languages)
        {
            TaleStrings existing = Parse(existingCsv);
            var columns = new List<string> { sourceLanguage };
            foreach (string language in existing.Languages)
                if (!columns.Contains(language)) columns.Add(language);
            if (languages != null)
                foreach (string language in languages)
                    if (!string.IsNullOrEmpty(language) && !columns.Contains(language)) columns.Add(language);
            var keys = new List<string>();
            var used = new HashSet<string>();
            foreach (var entry in entries)
            {
                if (entry == null || string.IsNullOrEmpty(entry.Key) || !used.Add(entry.Key)) continue;
                keys.Add(entry.Key);
                Dictionary<string, string> row;
                if (!existing.Rows.TryGetValue(entry.Key, out row))
                {
                    row = new Dictionary<string, string>();
                    existing.Rows[entry.Key] = row;
                }
                string status = "";
                string old;
                if (row.TryGetValue(sourceLanguage, out old) && old != entry.Text && HasTranslation(row, columns, sourceLanguage))
                    status = StatusChanged;
                row[sourceLanguage] = entry.Text;
                row[ContextColumn] = entry.Context;
                row[StatusColumn] = status;
            }
            foreach (string key in existing.Order)
            {
                if (used.Contains(key)) continue;
                existing.Rows[key][StatusColumn] = StatusUnused;
                keys.Add(key);
                used.Add(key);
            }
            var output = new StringBuilder();
            var header = new List<string> { "keys" };
            header.AddRange(columns);
            header.Add(ContextColumn);
            header.Add(StatusColumn);
            WriteLine(output, header);
            foreach (string key in keys)
            {
                Dictionary<string, string> row = existing.Rows[key];
                var line = new List<string> { key };
                foreach (string column in columns) line.Add(Get(row, column));
                line.Add(Get(row, ContextColumn));
                line.Add(Get(row, StatusColumn));
                WriteLine(output, line);
            }
            return output.ToString();
        }

        /// <summary>
        /// The strings of tales: titles, beat headings, every line and choice option, names given
        /// during play (<c>mira.display_name = "..."</c>), and <c>tr("...")</c> texts. Tales are
        /// taken in name order, as the Godot plugin takes its files.
        /// </summary>
        public static List<TaleStringEntry> Collect(IEnumerable<Tale> tales)
        {
            var entries = new List<TaleStringEntry>();
            var seen = new HashSet<string>();
            var sorted = new List<Tale>();
            foreach (var tale in tales)
                if (tale != null) sorted.Add(tale);
            sorted.Sort((a, b) => string.CompareOrdinal(a.TaleName, b.TaleName));
            foreach (var tale in sorted)
            {
                string file = tale.TaleName + ".tale";
                if (tale.Title.Length > 0) Add(entries, seen, tale.Title, tale.Title, "title of " + file);
                foreach (string beat in tale.Headings.Keys)
                    Add(entries, seen, tale.Headings[beat], tale.Headings[beat], "heading of beat '" + beat + "' in " + file);
                foreach (var instruction in tale.Instructions) CollectInstruction(entries, seen, tale, file, instruction);
            }
            return entries;
        }

        /// <summary>Adds an entry keyed by its own text, unless that key is already in the list.</summary>
        public static void AddText(List<TaleStringEntry> entries, string text, string context)
        {
            if (string.IsNullOrEmpty(text)) return;
            foreach (var entry in entries)
                if (entry.Key == text) return;
            entries.Add(new TaleStringEntry { Key = text, Text = text, Context = context });
        }

        private static void CollectInstruction(List<TaleStringEntry> entries, HashSet<string> seen, Tale tale, string file, TaleInstruction instruction)
        {
            string where = file + ":" + instruction.Line;
            switch (instruction.Op)
            {
                case TaleOp.Say:
                {
                    string text;
                    tale.Texts.TryGetValue(instruction.Id, out text);
                    Add(entries, seen, tale.TranslationKey(instruction.Id), text ?? "",
                        where + (instruction.Speaker.Length > 0 ? " (" + instruction.Speaker + ")" : ""));
                    break;
                }
                case TaleOp.Choose:
                    foreach (var option in instruction.Options)
                    {
                        string text;
                        tale.Texts.TryGetValue(option.Id, out text);
                        Add(entries, seen, tale.TranslationKey(option.Id), text ?? "", file + ":" + option.Line + " (choice)");
                    }
                    break;
                case TaleOp.Set:
                {
                    TaleExpr place = instruction.Place;
                    TaleExpr value = instruction.Value;
                    var name = value != null && value.Kind == TaleExprKind.Literal ? value.Value as string : null;
                    if (place != null && place.Kind == TaleExprKind.Attribute && place.Name == "display_name"
                        && place.Operands.Count > 0 && place.Operands[0].Kind == TaleExprKind.Identifier && name != null)
                        Add(entries, seen, name, name, where + " (name of " + place.Operands[0].Name + ")");
                    break;
                }
            }
            foreach (TaleExpr expr in Expressions(instruction)) CollectTr(entries, seen, expr, where);
        }

        private static IEnumerable<TaleExpr> Expressions(TaleInstruction instruction)
        {
            var found = new List<TaleExpr> { instruction.Expr, instruction.Place, instruction.Value, instruction.Cond, instruction.Iterable, instruction.Subject };
            foreach (object part in instruction.Text)
                found.Add(part as TaleExpr);
            foreach (string key in instruction.Args.Keys) found.Add(instruction.Args[key]);
            foreach (var option in instruction.Options)
            {
                found.Add(option.Cond);
                foreach (object part in option.Text) found.Add(part as TaleExpr);
            }
            foreach (var branch in instruction.Branches)
            {
                found.Add(branch.Guard);
                found.AddRange(branch.Patterns);
            }
            return found;
        }

        private static void CollectTr(List<TaleStringEntry> entries, HashSet<string> seen, TaleExpr expr, string where)
        {
            if (expr == null) return;
            if (expr.Kind == TaleExprKind.Call && expr.Operands.Count > 0 && expr.Operands[0].Kind == TaleExprKind.Identifier
                && expr.Operands[0].Name == "tr" && expr.Args.Count == 1 && expr.Args[0].Kind == TaleExprKind.Literal)
            {
                var text = expr.Args[0].Value as string;
                if (text != null) Add(entries, seen, text, text, where + " (tr)");
            }
            foreach (var operand in expr.Operands) CollectTr(entries, seen, operand, where);
            foreach (var argument in expr.Args) CollectTr(entries, seen, argument, where);
            foreach (string key in expr.NamedArgs.Keys) CollectTr(entries, seen, expr.NamedArgs[key], where);
        }

        private static void Add(List<TaleStringEntry> entries, HashSet<string> seen, string key, string text, string context)
        {
            if (string.IsNullOrEmpty(key) || !seen.Add(key)) return;
            entries.Add(new TaleStringEntry { Key = key, Text = text, Context = context });
        }

        private static bool HasTranslation(Dictionary<string, string> row, List<string> columns, string sourceLanguage)
        {
            foreach (string column in columns)
            {
                string text;
                if (column != sourceLanguage && row.TryGetValue(column, out text) && !string.IsNullOrEmpty(text)) return true;
            }
            return false;
        }

        private static string Get(Dictionary<string, string> row, string column)
        {
            string text;
            return row.TryGetValue(column, out text) && text != null ? text : "";
        }

        // --- CSV: comma separated, fields with a comma, quote, or line break are quoted, and
        // quotes inside them are doubled, as Godot's store_csv_line writes them.

        private static void WriteLine(StringBuilder output, List<string> fields)
        {
            for (int i = 0; i < fields.Count; i++)
            {
                if (i > 0) output.Append(',');
                string field = fields[i] ?? "";
                if (field.IndexOfAny(new[] { ',', '"', '\n', '\r' }) >= 0)
                    output.Append('"').Append(field.Replace("\"", "\"\"")).Append('"');
                else
                    output.Append(field);
            }
            output.Append('\n');
        }

        private static List<List<string>> ParseCsv(string text)
        {
            var records = new List<List<string>>();
            var record = new List<string>();
            var field = new StringBuilder();
            bool quoted = false;
            bool fieldStarted = false;
            int i = 0;
            if (text.Length > 0 && text[0] == '﻿') i = 1;
            for (; i < text.Length; i++)
            {
                char c = text[i];
                if (quoted)
                {
                    if (c == '"')
                    {
                        if (i + 1 < text.Length && text[i + 1] == '"')
                        {
                            field.Append('"');
                            i++;
                        }
                        else
                        {
                            quoted = false;
                        }
                    }
                    else
                    {
                        field.Append(c);
                    }
                    continue;
                }
                if (c == '"' && field.Length == 0)
                {
                    quoted = true;
                    fieldStarted = true;
                }
                else if (c == ',')
                {
                    record.Add(field.ToString());
                    field.Length = 0;
                    fieldStarted = true;
                }
                else if (c == '\n' || c == '\r')
                {
                    if (c == '\r' && i + 1 < text.Length && text[i + 1] == '\n') i++;
                    if (fieldStarted || field.Length > 0 || record.Count > 0)
                    {
                        record.Add(field.ToString());
                        records.Add(record);
                    }
                    record = new List<string>();
                    field.Length = 0;
                    fieldStarted = false;
                }
                else
                {
                    field.Append(c);
                    fieldStarted = true;
                }
            }
            if (fieldStarted || field.Length > 0 || record.Count > 0)
            {
                record.Add(field.ToString());
                records.Add(record);
            }
            return records;
        }
    }
}

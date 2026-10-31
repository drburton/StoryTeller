using System.Globalization;

namespace TaleScript
{
    public enum TaleSeverity { Error, Warning }

    /// <summary>An error or warning found in a tale, with its location.</summary>
    public class TaleDiagnostic
    {
        public TaleSeverity Severity;
        public string Message;
        /// <summary>1-based line number.</summary>
        public int Line;
        /// <summary>1-based column number, counted in characters.</summary>
        public int Column;

        public TaleDiagnostic(TaleSeverity severity, string message, int line, int column)
        {
            Severity = severity;
            Message = message;
            Line = line;
            Column = column;
        }


        public bool IsError()
        {
            return Severity == TaleSeverity.Error;
        }

        public override string ToString()
        {
            string label = IsError() ? "error" : "warning";
            return string.Format(CultureInfo.InvariantCulture, "{0}:{1}: {2}: {3}", Line, Column, label, Message);
        }
    }
}

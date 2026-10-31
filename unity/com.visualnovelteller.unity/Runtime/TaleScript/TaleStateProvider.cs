namespace TaleScript
{
    /// <summary>
    /// Host state that saves and rewinds with the story, such as a stage, audio, or shots.
    /// Register one with <see cref="TaleDirector.AddStateProvider"/>. The director stores
    /// what <see cref="Capture"/> returns under <see cref="Name"/> and hands it back to
    /// <see cref="Restore"/>.
    /// </summary>
    public interface ITaleStateProvider
    {
        /// <summary>Key of this provider's data in the save.</summary>
        string Name { get; }

        /// <summary>Returns plain data: <c>OrderedMap&lt;object&gt;</c>, <c>List&lt;object&gt;</c>, string, long, double, bool, or null.</summary>
        object Capture();

        /// <summary>Applies data from <see cref="Capture"/>. After a JSON round trip it holds the same plain types.</summary>
        void Restore(object data);
    }
}

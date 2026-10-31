using System.Collections.Generic;
using System.Threading.Tasks;

namespace TaleScript
{
    /// <summary>
    /// Shows lines and choices to the player. The director awaits these methods.
    /// Extend it and set <see cref="TaleDirector.Presenter"/>.
    /// </summary>
    public abstract class TalePresenter
    {
        /// <summary>
        /// Shows one line and completes when the player continues. The line has the keys
        /// speaker_id, speaker_name, speaker_color, mood, text, id, voice, tale, beat,
        /// source_line (long), and read (bool).
        /// </summary>
        public abstract Task ShowLine(OrderedMap<object> line);

        /// <summary>
        /// Shows choices and completes with the index of the chosen option, or -1 when the
        /// timeout expires. Each option has the keys text, id, enabled (bool), and picture.
        /// The settings hold the choose arguments, such as timeout.
        /// </summary>
        public abstract Task<int> Choose(List<OrderedMap<object>> options, OrderedMap<object> settings);

        /// <summary>Called when the story stops while the presenter may be waiting for the player.</summary>
        public virtual void Cancel()
        {
        }
    }
}

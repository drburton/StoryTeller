using System;
using System.Threading.Tasks;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// The parts of Steam that <see cref="SteamStoreBackend"/> needs. The Steamworks.NET support
    /// in this package implements it; tests use a stand-in.
    /// </summary>
    public interface ISteamStoreApi
    {
        /// <summary>True when the reader's Steam account owns the DLC with this app id.</summary>
        bool OwnsDlc(uint appId);

        /// <summary>True when the Steam overlay can open in the game.</summary>
        bool OverlayEnabled { get; }

        /// <summary>Opens the DLC's store page in the Steam overlay, with the DLC in the cart.</summary>
        void OpenStoreOverlay(uint appId);

        /// <summary>Raised when a DLC is installed, for example right after the reader buys it.</summary>
        event Action<uint> DlcInstalled;

        /// <summary>Raised when the Steam overlay opens (true) or closes (false).</summary>
        event Action<bool> OverlayActivated;
    }

    /// <summary>
    /// Sells DLC on Steam. Each <see cref="StoryProduct"/> needs its steamAppId, the DLC's app id
    /// in Steamworks. Steam keeps ownership with the reader's account, so there is nothing to
    /// restore, and it doesn't tell games prices, so the purchase screen shows none: the Steam
    /// overlay shows the price when the reader presses Buy.
    /// </summary>
    public class SteamStoreBackend : StoreBackend
    {
        private readonly ISteamStoreApi _api;
        private TaskCompletionSource<bool> _overlayClosed;
        private uint _buying;

        public SteamStoreBackend(ISteamStoreApi api)
        {
            _api = api;
        }

        public override string StoreName { get { return "steam"; } }

        public override Task Start()
        {
            if (_api != null)
            {
                _api.DlcInstalled += OnDlcInstalled;
                _api.OverlayActivated += OnOverlayActivated;
            }
            return Task.CompletedTask;
        }

        public override bool IsReady { get { return _api != null; } }

        public override bool Owns(string id)
        {
            uint appId = AppId(id);
            return appId != 0 && _api != null && _api.OwnsDlc(appId);
        }

        /// <summary>
        /// Opens the DLC in the Steam overlay and waits for the reader to close it. Bought when
        /// they own it then, cancelled otherwise. Without the overlay, Steam can't sell inside the
        /// game, so the purchase fails with a warning.
        /// </summary>
        public override async Task<PurchaseResult> Purchase(string id)
        {
            uint appId = AppId(id);
            if (appId == 0 || _api == null)
            {
                Debug.LogWarning("StoryStore: product '" + id + "' has no Steam app id, so it can't be sold on Steam.");
                return PurchaseResult.Failed;
            }
            if (_api.OwnsDlc(appId)) return PurchaseResult.Bought;
            if (!_api.OverlayEnabled)
            {
                Debug.LogWarning("StoryStore: the Steam overlay is off, so the DLC can't be bought in the game. Turn on the overlay in Steam's settings.");
                return PurchaseResult.Failed;
            }
            if (_overlayClosed != null) return PurchaseResult.Failed;
            _overlayClosed = new TaskCompletionSource<bool>();
            _buying = appId;
            _api.OpenStoreOverlay(appId);
            await _overlayClosed.Task;
            _overlayClosed = null;
            _buying = 0;
            return _api.OwnsDlc(appId) ? PurchaseResult.Bought : PurchaseResult.Cancelled;
        }

        private uint AppId(string id)
        {
            StoryProduct product = FindProduct(id);
            return product != null && product.steamAppId > 0 && product.steamAppId <= uint.MaxValue ? (uint)product.steamAppId : 0;
        }

        private void OnDlcInstalled(uint appId)
        {
            RaiseChanged();
            // Steam sometimes reports the purchase before the overlay closes.
            if (appId == _buying && _overlayClosed != null) _overlayClosed.TrySetResult(true);
        }

        private void OnOverlayActivated(bool active)
        {
            if (!active && _overlayClosed != null) _overlayClosed.TrySetResult(true);
        }
    }
}

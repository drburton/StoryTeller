using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Purchasing;

namespace VisualNovelTeller
{
    /// <summary>
    /// Sells through the platform's store with Unity In-App Purchasing 5: the Apple App Store
    /// on iOS and macOS, and Google Play on Android. This assembly only compiles when the
    /// project has the com.unity.purchasing package (5.0 or newer), and then it becomes
    /// <see cref="StoryStore.PlatformBackend"/>, which <see cref="StoreMode.Auto"/> uses in builds.
    /// Each <see cref="StoryProduct"/> is a non-consumable, sold under its appleId or
    /// googlePlayId (or its id when that is empty).
    /// </summary>
    public class UnityIapStoreBackend : StoreBackend
    {
        private readonly HashSet<string> _owned = new HashSet<string>();
        private readonly Dictionary<string, string> _prices = new Dictionary<string, string>();
        private StoreController _controller;
        private bool _ready;
        private TaskCompletionSource<bool> _productsFetched;
        private TaskCompletionSource<bool> _purchasesFetched;
        private TaskCompletionSource<PurchaseResult> _purchase;
        private string _purchaseId;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void Register()
        {
            if (StoryStore.PlatformBackend == null) StoryStore.PlatformBackend = () => new UnityIapStoreBackend();
        }

        public override string StoreName { get { return "unity-iap"; } }

        public override bool IsReady { get { return _ready; } }

        public override async Task Start()
        {
            _controller = UnityIAPServices.StoreController();
            _controller.OnProductsFetched += OnProductsFetched;
            _controller.OnProductsFetchFailed += OnProductsFetchFailed;
            _controller.OnPurchasesFetched += OnPurchasesFetched;
            _controller.OnPurchasesFetchFailed += OnPurchasesFetchFailed;
            _controller.OnPurchasePending += OnPurchasePending;
            _controller.OnPurchaseConfirmed += OnPurchaseConfirmed;
            _controller.OnPurchaseFailed += OnPurchaseFailed;
            _controller.OnPurchaseDeferred += OnPurchaseDeferred;
            try
            {
                await _controller.Connect();
            }
            catch (Exception e)
            {
                Debug.LogWarning("StoryStore: could not connect to the store. " + e.Message);
                return;
            }
            var definitions = new List<ProductDefinition>();
            foreach (var product in Products)
                if (product != null && !string.IsNullOrEmpty(product.id))
                    definitions.Add(new ProductDefinition(product.id, StoreId(product), ProductType.NonConsumable));
            _productsFetched = new TaskCompletionSource<bool>();
            _controller.FetchProducts(definitions);
            await _productsFetched.Task;
            await FetchPurchases();
        }

        public override bool Owns(string id)
        {
            return _owned.Contains(id);
        }

        public override string GetPrice(string id)
        {
            string price;
            return _prices.TryGetValue(id, out price) ? price : "";
        }

        public override Task<PurchaseResult> Purchase(string id)
        {
            Product product = _controller != null ? _controller.GetProductById(id) : null;
            if (product == null || _purchase != null) return Task.FromResult(PurchaseResult.Failed);
            _purchase = new TaskCompletionSource<PurchaseResult>();
            _purchaseId = id;
            _controller.PurchaseProduct(product);
            return _purchase.Task;
        }

        public override bool CanRestore { get { return _controller != null; } }

        /// <summary>Asks the store for every purchase. On Apple this asks the reader to sign in, so call it only from Restore purchases.</summary>
        public override async Task Restore()
        {
            if (_controller == null) return;
            var restored = new TaskCompletionSource<bool>();
            _controller.RestoreTransactions(delegate (bool success, string error)
            {
                if (!success) Debug.LogWarning("StoryStore: restoring purchases failed. " + error);
                restored.TrySetResult(success);
            });
            await restored.Task;
            await FetchPurchases();
        }

        /// <summary>The id the store sells a product under: appleId on Apple platforms, googlePlayId on Android, or the id.</summary>
        public static string StoreId(StoryProduct product)
        {
            string id = "";
            switch (Application.platform)
            {
                case RuntimePlatform.IPhonePlayer:
                case RuntimePlatform.OSXPlayer:
                    id = product.appleId;
                    break;
                case RuntimePlatform.Android:
                    id = product.googlePlayId;
                    break;
            }
            return string.IsNullOrEmpty(id) ? product.id : id;
        }

        private async Task FetchPurchases()
        {
            _purchasesFetched = new TaskCompletionSource<bool>();
            _controller.FetchPurchases();
            await _purchasesFetched.Task;
        }

        private void OnProductsFetched(List<Product> products)
        {
            foreach (var product in products)
                if (product != null && product.metadata != null)
                    _prices[product.definition.id] = product.metadata.localizedPriceString ?? "";
            if (_productsFetched != null) _productsFetched.TrySetResult(true);
        }

        private void OnProductsFetchFailed(ProductFetchFailed failure)
        {
            Debug.LogWarning("StoryStore: the store could not find some products. " + failure.FailureReason);
            if (_productsFetched != null) _productsFetched.TrySetResult(false);
        }

        // Purchases the store reports as owned, at launch and after restoring. A refunded
        // purchase is no longer among them, so ownership is rebuilt from scratch.
        private void OnPurchasesFetched(Orders orders)
        {
            _owned.Clear();
            foreach (var order in orders.ConfirmedOrders) AddOwned(order);
            foreach (var order in orders.PendingOrders)
            {
                AddOwned(order);
                _controller.ConfirmPurchase(order);
            }
            _ready = true;
            if (_purchasesFetched != null) _purchasesFetched.TrySetResult(true);
            RaiseChanged();
        }

        private void OnPurchasesFetchFailed(PurchasesFetchFailureDescription failure)
        {
            Debug.LogWarning("StoryStore: could not ask the store what the reader owns. " + failure.failureReason + " " + failure.message);
            if (_purchasesFetched != null) _purchasesFetched.TrySetResult(false);
        }

        // The store took the payment. The content unlocks now, then the purchase is confirmed.
        private void OnPurchasePending(PendingOrder order)
        {
            AddOwned(order);
            _controller.ConfirmPurchase(order);
            FinishPurchase(order, PurchaseResult.Bought);
            RaiseChanged();
        }

        private void OnPurchaseConfirmed(Order order)
        {
            var failed = order as FailedOrder;
            if (failed != null)
            {
                Debug.LogWarning("StoryStore: confirming a purchase failed. " + failed.FailureReason + " " + failed.Details);
                return;
            }
            if (AddOwned(order)) RaiseChanged();
        }

        private void OnPurchaseFailed(FailedOrder order)
        {
            bool cancelled = order.FailureReason == PurchaseFailureReason.UserCancelled;
            if (!cancelled) Debug.LogWarning("StoryStore: a purchase failed. " + order.FailureReason + " " + order.Details);
            FinishPurchase(order, cancelled ? PurchaseResult.Cancelled : PurchaseResult.Failed);
        }

        // Ask to Buy and other purchases that wait for someone's approval. When it goes
        // through, OnPurchasePending unlocks the content.
        private void OnPurchaseDeferred(DeferredOrder order)
        {
            FinishPurchase(order, PurchaseResult.Pending);
        }

        private bool AddOwned(Order order)
        {
            bool added = false;
            foreach (var item in order.CartOrdered.Items())
                if (item != null && item.Product != null && _owned.Add(item.Product.definition.id)) added = true;
            return added;
        }

        private void FinishPurchase(Order order, PurchaseResult result)
        {
            if (_purchase == null) return;
            foreach (var item in order.CartOrdered.Items())
            {
                if (item == null || item.Product == null || item.Product.definition.id != _purchaseId) continue;
                TaskCompletionSource<PurchaseResult> purchase = _purchase;
                _purchase = null;
                _purchaseId = null;
                purchase.TrySetResult(result);
                return;
            }
        }
    }
}

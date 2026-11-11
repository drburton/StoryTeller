using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Threading.Tasks;
using TaleScript;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// Something a reader can buy inside the game, such as the full story or an extra chapter
    /// (decision 0029). Bought once and owned for good. Tales use its id in <c>owns("id")</c>,
    /// <c>await offer("id")</c>, and <c>@needs("id")</c>. List products in the Story Config.
    /// </summary>
    [Serializable]
    public class StoryProduct
    {
        /// <summary>The name tales use, such as full_story.</summary>
        public string id = "";
        /// <summary>The name the purchase screen shows.</summary>
        public string title = "";
        /// <summary>What the reader gets, shown on the purchase screen.</summary>
        [TextArea] public string description = "";
        /// <summary>Optional picture for the purchase screen.</summary>
        public Sprite picture;
        [Tooltip("The product id in App Store Connect. Empty uses the id.")]
        public string appleId = "";
        [Tooltip("The product id in the Google Play Console. Empty uses the id.")]
        public string googlePlayId = "";
        [Tooltip("The DLC's app id on Steam.")]
        public long steamAppId;
        [Tooltip("The price the test store shows.")]
        public string testPrice = "$4.99";

        /// <summary>The title, or the id when there is none.</summary>
        public string DisplayTitle { get { return string.IsNullOrEmpty(title) ? id : title; } }
    }

    /// <summary>Which store a game sells through. See <see cref="StoryStore.MakeBackend"/>.</summary>
    public enum StoreMode
    {
        /// <summary>The test store in the editor, the platform's store in a build when Unity In-App Purchasing is installed, and no store otherwise.</summary>
        Auto,
        /// <summary>Always the test store.</summary>
        Test,
        /// <summary>Sells nothing; the reader owns nothing.</summary>
        None
    }

    /// <summary>What a purchase gives back.</summary>
    public enum PurchaseResult
    {
        /// <summary>The reader owns the product now.</summary>
        Bought,
        /// <summary>The reader closed the store without buying.</summary>
        Cancelled,
        /// <summary>The store is still confirming it, such as an Ask to Buy request. <see cref="StoreBackend.Changed"/> tells when it goes through.</summary>
        Pending,
        /// <summary>Something went wrong, such as no connection.</summary>
        Failed
    }

    /// <summary>
    /// Connects <see cref="StoryStore"/> to one store. This base class sells nothing and owns
    /// nothing, which is what a game without a store gets. A backend for another storefront or
    /// a game's own key system extends it and is passed to <see cref="StoryStore.SetBackend"/>.
    /// </summary>
    public class StoreBackend
    {
        /// <summary>Raised when what the reader owns may have changed: a purchase, a refund, a restore.</summary>
        public event Action Changed;

        /// <summary>The products on sale, set by <see cref="StoryStore"/> before <see cref="Start"/>.</summary>
        public IReadOnlyList<StoryProduct> Products { get; internal set; } = new List<StoryProduct>();

        /// <summary>The name the store shows in logs.</summary>
        public virtual string StoreName { get { return "none"; } }

        /// <summary>Connects to the store.</summary>
        public virtual Task Start()
        {
            return Task.CompletedTask;
        }

        /// <summary>True when the store has answered, so <see cref="Owns"/> can be trusted. Until then, <see cref="StoryStore"/> uses what the reader owned last time.</summary>
        public virtual bool IsReady { get { return true; } }

        /// <summary>True when the reader owns the product with this id.</summary>
        public virtual bool Owns(string id)
        {
            return false;
        }

        /// <summary>The store's price for the product, ready to show, or "".</summary>
        public virtual string GetPrice(string id)
        {
            return "";
        }

        /// <summary>Asks the store to sell the product.</summary>
        public virtual Task<PurchaseResult> Purchase(string id)
        {
            return Task.FromResult(PurchaseResult.Failed);
        }

        /// <summary>True when the store can restore purchases made on another device or before a reinstall. Apple requires a button for it.</summary>
        public virtual bool CanRestore { get { return false; } }

        /// <summary>Asks the store for everything the reader bought.</summary>
        public virtual Task Restore()
        {
            return Task.CompletedTask;
        }

        /// <summary>The product with this id, or null.</summary>
        protected StoryProduct FindProduct(string id)
        {
            foreach (var product in Products)
                if (product != null && product.id == id) return product;
            return null;
        }

        /// <summary>Raises <see cref="Changed"/>.</summary>
        protected void RaiseChanged()
        {
            if (Changed != null) Changed();
        }
    }

    /// <summary>
    /// A pretend store for making and testing a game without a store account. Buying always
    /// works unless <see cref="NextResult"/> says otherwise. What the reader owns is kept in
    /// <see cref="FilePath"/>, so it survives restarting the game.
    /// </summary>
    public class TestStoreBackend : StoreBackend
    {
        private readonly HashSet<string> _owned = new HashSet<string>();

        /// <summary>The file that keeps what the reader owns, or "" to keep it in memory only.</summary>
        public string FilePath = "";
        /// <summary>What the next purchase gives, to try a cancelled, pending, or failed purchase.</summary>
        public PurchaseResult NextResult = PurchaseResult.Bought;

        public override string StoreName { get { return "test"; } }

        public override Task Start()
        {
            _owned.Clear();
            foreach (string id in StoryStore.ReadIds(FilePath, "owned")) _owned.Add(id);
            return Task.CompletedTask;
        }

        public override bool Owns(string id)
        {
            return _owned.Contains(id);
        }

        public override string GetPrice(string id)
        {
            StoryProduct product = FindProduct(id);
            return product != null ? product.testPrice ?? "" : "";
        }

        public override Task<PurchaseResult> Purchase(string id)
        {
            PurchaseResult result = NextResult;
            NextResult = PurchaseResult.Bought;
            if (result == PurchaseResult.Bought) SetOwned(id, true);
            return Task.FromResult(result);
        }

        public override bool CanRestore { get { return true; } }

        public override Task Restore()
        {
            RaiseChanged();
            return Task.CompletedTask;
        }

        /// <summary>Gives or takes away a product, as a purchase or a refund would.</summary>
        public void SetOwned(string id, bool owned)
        {
            if (owned == _owned.Contains(id)) return;
            if (owned) _owned.Add(id);
            else _owned.Remove(id);
            StoryStore.WriteIds(FilePath, "owned", _owned);
            RaiseChanged();
        }

        /// <summary>Takes away everything, as on a new account.</summary>
        public void ResetAll()
        {
            _owned.Clear();
            StoryStore.WriteIds(FilePath, "owned", _owned);
            RaiseChanged();
        }
    }

    /// <summary>
    /// What the reader owns, and buying more (decision 0029). Paid content ships in the game,
    /// locked until the reader buys its <see cref="StoryProduct"/>. <see cref="Story"/> makes one
    /// from the Story Config and answers <c>owns()</c>, <c>offer()</c>, and <c>@needs</c> with it.
    /// The store decides what the reader owns; the last answer is kept in a file, so the game
    /// still works offline.
    /// </summary>
    public class StoryStore
    {
        /// <summary>
        /// Makes the backend for the platform's store. The Unity In-App Purchasing support in
        /// this package sets it when that package is installed; a game may set its own.
        /// </summary>
        public static Func<StoreBackend> PlatformBackend;

        private readonly Dictionary<string, StoryProduct> _products = new Dictionary<string, StoryProduct>();
        private readonly List<StoryProduct> _ordered = new List<StoryProduct>();
        private readonly HashSet<string> _owned = new HashSet<string>();
        private readonly string _cachePath;

        /// <summary>Raised when what the reader owns changes.</summary>
        public event Action OwnershipChanged;

        /// <summary>The store this game sells through.</summary>
        public StoreBackend Backend { get; private set; }

        /// <summary>
        /// Shows the purchase screen for a product and gives true when the reader owns it
        /// afterwards. <see cref="StoryMenus"/> sets it. Without it, <see cref="Offer"/> buys
        /// straight away.
        /// </summary>
        public Func<StoryProduct, Task<bool>> OfferScreen;

        /// <summary>Makes a store for these products. cachePath is the file that keeps what the reader owned last time, or "" for none.</summary>
        public StoryStore(IEnumerable<StoryProduct> products, string cachePath = "")
        {
            if (products != null)
            {
                foreach (var product in products)
                {
                    if (product == null || string.IsNullOrEmpty(product.id) || _products.ContainsKey(product.id)) continue;
                    _products[product.id] = product;
                    _ordered.Add(product);
                }
            }
            _cachePath = cachePath ?? "";
            foreach (string id in ReadIds(_cachePath, "owned")) _owned.Add(id);
            Backend = new StoreBackend();
        }

        /// <summary>The products on sale, in the order the Story Config lists them.</summary>
        public IReadOnlyList<StoryProduct> Products { get { return _ordered; } }

        /// <summary>
        /// The backend a mode asks for. Auto uses the test store in the editor, the
        /// <see cref="PlatformBackend"/> in a build, and no store otherwise.
        /// </summary>
        public static StoreBackend MakeBackend(StoreMode mode, string testStorePath = "")
        {
            switch (mode)
            {
                case StoreMode.Test:
                    return new TestStoreBackend { FilePath = testStorePath };
                case StoreMode.None:
                    return new StoreBackend();
            }
            if (Application.isEditor) return new TestStoreBackend { FilePath = testStorePath };
            StoreBackend platform = PlatformBackend != null ? PlatformBackend() : null;
            return platform ?? new StoreBackend();
        }

        /// <summary>Switches to a backend and asks it what the reader owns.</summary>
        public async Task SetBackend(StoreBackend backend)
        {
            if (Backend != null) Backend.Changed -= Refresh;
            Backend = backend ?? new StoreBackend();
            Backend.Products = _ordered;
            Backend.Changed += Refresh;
            try
            {
                await Backend.Start();
            }
            catch (Exception e)
            {
                Debug.LogError("StoryStore: the " + Backend.StoreName + " store did not start. " + e.Message);
            }
            Refresh();
        }

        /// <summary>Asks the backend again what the reader owns.</summary>
        public void Refresh()
        {
            if (Backend == null || !Backend.IsReady) return;
            var owned = new HashSet<string>();
            foreach (var product in _ordered)
                if (Backend.Owns(product.id)) owned.Add(product.id);
            if (owned.SetEquals(_owned)) return;
            _owned.Clear();
            _owned.UnionWith(owned);
            WriteIds(_cachePath, "owned", _owned);
            if (OwnershipChanged != null) OwnershipChanged();
        }

        /// <summary>True when the reader owns the product.</summary>
        public bool Owns(string id)
        {
            return _owned.Contains(id);
        }

        /// <summary>
        /// Offers a product on the purchase screen and gives true when the reader owns it
        /// afterwards. Gives true at once when they already do.
        /// </summary>
        public async Task<bool> Offer(string id)
        {
            if (Owns(id)) return true;
            StoryProduct product = GetProduct(id);
            if (product == null)
            {
                Debug.LogError("StoryStore: there is no product '" + id + "' in the Story Config.");
                return false;
            }
            if (OfferScreen != null) await OfferScreen(product);
            else await Purchase(id);
            return Owns(id);
        }

        /// <summary>Buys a product through the backend.</summary>
        public async Task<PurchaseResult> Purchase(string id)
        {
            if (Backend == null || !HasProduct(id)) return PurchaseResult.Failed;
            PurchaseResult result;
            try
            {
                result = await Backend.Purchase(id);
            }
            catch (Exception e)
            {
                Debug.LogError("StoryStore: buying '" + id + "' failed. " + e.Message);
                result = PurchaseResult.Failed;
            }
            Refresh();
            return result;
        }

        /// <summary>True when the menus show Restore purchases: the game has products and the store can restore.</summary>
        public bool CanRestore { get { return Backend != null && Backend.CanRestore && _ordered.Count > 0; } }

        /// <summary>Asks the store for everything the reader bought.</summary>
        public async Task Restore()
        {
            if (Backend == null) return;
            await Backend.Restore();
            Refresh();
        }

        /// <summary>The store's price for a product, ready to show, or "".</summary>
        public string GetPrice(string id)
        {
            return Backend != null ? Backend.GetPrice(id) ?? "" : "";
        }

        public bool HasProduct(string id)
        {
            return id != null && _products.ContainsKey(id);
        }

        /// <summary>The product with this id, or null.</summary>
        public StoryProduct GetProduct(string id)
        {
            StoryProduct product;
            return id != null && _products.TryGetValue(id, out product) ? product : null;
        }

        /// <summary>The products in a list that the reader doesn't own.</summary>
        public List<string> Missing(IEnumerable<string> ids)
        {
            var missing = new List<string>();
            if (ids == null) return missing;
            foreach (string id in ids)
                if (!Owns(id)) missing.Add(id);
            return missing;
        }

        internal static List<string> ReadIds(string path, string key)
        {
            var ids = new List<string>();
            if (string.IsNullOrEmpty(path)) return ids;
            try
            {
                if (!File.Exists(path)) return ids;
                var data = GdJson.Parse(File.ReadAllText(path, Encoding.UTF8)) as OrderedMap<object>;
                object value;
                if (data == null || !data.TryGetValue(key, out value)) return ids;
                var list = value as List<object>;
                if (list == null) return ids;
                foreach (object item in list)
                    if (item != null) ids.Add(GdValue.Str(item));
            }
            catch (Exception e)
            {
                Debug.LogWarning("StoryStore: could not read " + path + ". " + e.Message);
            }
            return ids;
        }

        internal static void WriteIds(string path, string key, IEnumerable<string> ids)
        {
            if (string.IsNullOrEmpty(path)) return;
            try
            {
                string folder = Path.GetDirectoryName(path);
                if (!string.IsNullOrEmpty(folder)) Directory.CreateDirectory(folder);
                var sorted = new List<string>(ids);
                sorted.Sort(string.CompareOrdinal);
                var data = new OrderedMap<object>();
                data[key] = sorted.ConvertAll(id => (object)id);
                File.WriteAllText(path, GdJson.Stringify(data), new UTF8Encoding(false));
            }
            catch (Exception e)
            {
                Debug.LogWarning("StoryStore: could not write " + path + ". " + e.Message);
            }
        }
    }
}

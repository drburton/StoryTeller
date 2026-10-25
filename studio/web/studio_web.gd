class_name StudioWeb
extends RefCounted
## What the Studio needs from a web browser when it runs as a web page
## (decisions 0021 and 0024): choosing a file to upload, saving a file as a
## download, asking the browser to keep the Studio's storage, and reading
## the page's address. Everything here does nothing outside a browser.

# The JavaScript callback for the file being picked. It must stay
# referenced until the browser calls it.
static var _picked_callback: JavaScriptObject
static var _on_picked := Callable()


static func is_web() -> bool:
	return OS.has_feature("web")


## The value of [param name] in the page address's query, as in
## [code]index.html?check=make[/code], or "".
static func query(name: String) -> String:
	if not is_web():
		return ""
	var value = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get(%s) || ''" % JSON.stringify(name), true)
	return str(value) if value != null else ""


## True when the browser keeps the Studio's stories between visits. A
## browser may still clear a site's storage, for example Safari after seven
## days without a visit, unless the Studio is added to the home screen.
static func storage_is_kept() -> bool:
	return not is_web() or OS.is_userfs_persistent()


## Asks the browser to keep the Studio's storage instead of clearing it
## when space runs low. Browsers decide for themselves; an installed web
## app is usually kept.
static func keep_storage() -> void:
	if is_web():
		JavaScriptBridge.eval("navigator.storage && navigator.storage.persist && navigator.storage.persist().catch(function () {})", true)


## Saves [param bytes] as a download called [param file_name]. On an iPad
## the browser asks first, then puts it in Files.
static func save_file(bytes: PackedByteArray, file_name: String, mime := "application/octet-stream") -> void:
	if is_web():
		JavaScriptBridge.download_buffer(bytes, file_name, mime)


## Asks the student to choose a file, with [param accept] naming the kinds
## the picker offers (as in "image/*" or ".zip"), and calls
## [param on_picked] with its bytes and name. Nothing is called when the
## student closes the picker.
static func pick_file(accept: String, on_picked: Callable) -> void:
	if not is_web():
		return
	_on_picked = on_picked
	_picked_callback = JavaScriptBridge.create_callback(_received)
	var window = JavaScriptBridge.get_interface("window")
	window.studioPicked = _picked_callback
	JavaScriptBridge.eval("""
(function () {
	var input = document.createElement('input');
	input.type = 'file';
	input.accept = %s;
	input.style.display = 'none';
	input.onchange = function () {
		var file = input.files && input.files[0];
		input.remove();
		if (!file) { return; }
		var reader = new FileReader();
		reader.onload = function () {
			var bytes = new Uint8Array(reader.result);
			var text = '';
			for (var i = 0; i < bytes.length; i += 0x8000) {
				text += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
			}
			window.studioPicked(btoa(text), file.name);
		};
		reader.readAsArrayBuffer(file);
	};
	document.body.appendChild(input);
	input.click();
})();
""" % JSON.stringify(accept), true)


static func _received(args: Array) -> void:
	if args.size() < 2 or not _on_picked.is_valid():
		return
	var bytes := Marshalls.base64_to_raw(str(args[0]))
	var callback := _on_picked
	_on_picked = Callable()
	callback.call(bytes, str(args[1]))

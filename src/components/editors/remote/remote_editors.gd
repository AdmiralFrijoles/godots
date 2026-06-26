class_name RemoteEditorsControl
extends Control

signal installed(name: String, abs_path: String)

const MIRROR_GITHUB_ID = 0
const MIRROR_DEFAULT = MIRROR_GITHUB_ID

const uuid = preload("res://addons/uuid.gd")

@export var _editor_download_scene : PackedScene
@export var _editor_install_scene : PackedScene
@export var _remote_editor_direct_link_scene : PackedScene

@onready var _open_downloads_button: Button = %OpenDownloadsButton
@onready var _direct_link_button: Button = %DirectLinkButton
@onready var _refresh_button: Button = %RefreshButton
@onready var _remote_editors_tree := %RemoteEditorsTree as RemoteEditorsTreeControl
@onready var _tree_mirror_button: = %TreeMirrorButton as OptionButton

var _editor_downloads: DownloadsContainer
var _tree_mirrors: Dictionary[int, RemoteEditorsTreeDataSource.I] = {}
var _active_mirror_cache := Cache.smart_value(
	self, "active_mirror", true
).map_return_value(func(v: Variant) -> Variant:
	if not v in _tree_mirrors:
		return MIRROR_DEFAULT
	else:
		return v
)


func init(editor_downloads: DownloadsContainer) -> void:
	_editor_downloads = editor_downloads


func _ready() -> void:
	_tree_mirrors[MIRROR_GITHUB_ID] = RemoteEditorsTreeDataSourceGithub.Self.new(
		RemoteEditorsTreeDataSource.RemoteAssetsCallable.new(download_zip)
	)
	
	_tree_mirror_button.add_item("GitHub", MIRROR_GITHUB_ID)
	_tree_mirror_button.selected = _tree_mirror_button.get_item_index(
		_active_mirror_cache.ret(MIRROR_DEFAULT) as int
	)
	_tree_mirror_button.item_selected.connect(func(item_idx: int) -> void:
		var item_id := _tree_mirror_button.get_item_id(item_idx)
		if item_id in _tree_mirrors:
			_remote_editors_tree.set_data_source(_tree_mirrors[item_id])
			_active_mirror_cache.put(item_id)
	)
	
	_open_downloads_button.pressed.connect(func() -> void:
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(Config.DOWNLOADS_PATH.ret() as String))
	)
	_open_downloads_button.icon = get_theme_icon("Load", "EditorIcons")
	_open_downloads_button.tooltip_text = tr("Open Downloads Dir")
	
	_direct_link_button.icon = get_theme_icon("AssetLib", "EditorIcons")
	_direct_link_button.pressed.connect(func() -> void:
		var link_dialog: RemoteEditorDirectLinkControl = _remote_editor_direct_link_scene.instantiate()
		add_child(link_dialog)
		link_dialog.popup_centered()
		link_dialog.link_confirmed.connect(func(link: String) -> void:
			download_zip(link, "custom_editor.zip")
		)
	)
	
	_refresh_button.icon = get_theme_icon("Reload", "EditorIcons")
	_refresh_button.tooltip_text = tr("Refresh")
	#_refresh_button.self_modulate = Color(1, 1, 1, 0.6)
	_remote_editors_tree.post_ready(_refresh_button)
	var cached_mirror_id := _active_mirror_cache.ret(MIRROR_DEFAULT) as int
	_remote_editors_tree.set_data_source(_tree_mirrors[cached_mirror_id])


func download_zip(url: String, file_name: String, on_install:Variant=null) -> void:
	var editor_download: AssetDownload = _editor_download_scene.instantiate()
	_editor_downloads.add_download_item(editor_download)
	editor_download.start(
		url, (Config.DOWNLOADS_PATH.ret() as String) + "/", file_name
	)
	editor_download.download_failed.connect(func(response_code: int) -> void:
		Output.push(
			"Failed to download editor: %s" % response_code
		)
	)
	editor_download.downloaded.connect(func(abs_path: String) -> void:
		install_zip(
			abs_path,
			file_name.replace(".zip", "").replace(".", "_"),
			utils.guess_editor_name(file_name.replace(".zip", "")),
			func(installed_path: String) -> void:
				editor_download.queue_free()
				if on_install:
					(on_install as Callable).call(installed_path)
		)
	)


## on_install: Optional[Callbale]
func install_zip(zip_abs_path: String, root_unzip_folder_name: String, possible_editor_name: String, on_install:Variant=null) -> void:
	var zip_content_dir := _unzip_downloaded(zip_abs_path, root_unzip_folder_name)
	if not DirAccess.dir_exists_absolute(zip_content_dir):
		var accept_dialog := AcceptDialog.new()
		accept_dialog.visibility_changed.connect(func() -> void:
			if not accept_dialog.visible:
				accept_dialog.queue_free()
		)
		accept_dialog.dialog_text = tr("Error extracting archive.")
		add_child(accept_dialog)
		accept_dialog.popup_centered()
	else:
		var editor_install: RemoteEditorInstallControl = _editor_install_scene.instantiate()
		add_child(editor_install)
		editor_install.init(possible_editor_name, zip_content_dir)
		editor_install.installed.connect(func(p_name: String, exec_path: String) -> void:
			var globalized := ProjectSettings.globalize_path(exec_path)
			installed.emit(p_name, globalized)
			if on_install:
				(on_install as Callable).call(globalized)
		)
		editor_install.popup_centered()


func async_auto_install(version_hint: String, on_done: Callable) -> void:
	var parsed := VersionHint.parse(version_hint)
	if not parsed.is_valid:
		Output.push("Cannot resolve version hint for auto install: %s" % version_hint)
		on_done.call("")
		return

	var source := RemoteEditorsTreeDataSourceGithub.GithubAssetSourceDefault.new()
	var assets := await source.async_load(parsed.version, parsed.stage)

	var suffixes := RemoteEditorsTreeDataSourceGithub.Self.get_host_suffixes()
	var re_mono := RegEx.new()
	re_mono.compile(r"(?:^|[-_.])mono(?:$|[-_.])")

	var candidate: RemoteEditorsTreeDataSourceGithub.GodotAsset = null
	for asset: RemoteEditorsTreeDataSourceGithub.GodotAsset in assets:
		if not asset.is_zip:
			continue
		var asset_is_mono := re_mono.search(asset.name.to_lower()) != null
		if asset_is_mono != parsed.is_mono:
			continue
		if not suffixes.any(func(s: String) -> bool: return asset.name.ends_with(s)):
			continue
		candidate = asset
		break

	if candidate == null:
		Output.push("No matching editor download found for: %s" % version_hint)
		on_done.call("")
		return

	download_zip(candidate.browser_download_url, candidate.file_name, on_done)


func _unzip_downloaded(downloaded_abs_path: String, root_unzip_folder_name: String) -> String:
	var zip_content_dir := "%s/%s" % [Config.VERSIONS_PATH.ret(), root_unzip_folder_name]
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(zip_content_dir)):
		zip_content_dir += "-%s" % uuid.v4().substr(0, 8)
	zip_content_dir += "/"
	zip.unzip(downloaded_abs_path, zip_content_dir)
	return zip_content_dir

class_name RemoteAutoInstaller
extends RefCounted

var _remote_editors: RemoteEditorsControl


func _init(remote_editors: RemoteEditorsControl) -> void:
	_remote_editors = remote_editors


func async_install(version_hint: String, on_done: Callable) -> void:
	_remote_editors.async_auto_install(version_hint, on_done)

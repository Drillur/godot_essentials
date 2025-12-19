extends Node


const ARROW_THICK_RIGHT: StringName = &"arrow_thick_right"

var resource_paths: Dictionary[StringName, String]
var audio_paths: Dictionary[StringName, String]
var dialogue_paths: Dictionary[StringName, String]
var json_paths: Dictionary[StringName, String]
var texture_paths: Dictionary[StringName, String]
var script_paths: Dictionary[StringName, String]
var done := LoudBool.new(false)


#region Init


func _ready():
	dev__report_duration_of_ready_func()
	store_all_resources()
	done.set_true()


func dev__report_duration_of_ready_func() -> void:
	if not Utility.DEV_MODE:
		return
	
	var start_time: int = Time.get_ticks_msec()
	await done.became_true
	Log.pr("ResourceBag cached in", int(Time.get_ticks_msec() - start_time), "ms")


func store_all_resources() -> void:
	dir_contents("res://groups/")


func dir_contents(path: String) -> void:
	var directory := DirAccess.open(path)
	if not directory:
		Log.warn(dir_contents, "DirAccess failed to open '%s' -" % path, error_string(DirAccess.get_open_error()))
		return
	
	directory.list_dir_begin()
	var filename: String = directory.get_next()
	
	while not filename.is_empty():
		if directory.current_is_dir():
			if not folder_is_invalid(filename):
				dir_contents(path.path_join(filename))
		else:
			var _name: String = filename.split(".")[0]
			var extension: String = filename
			extension = extension.replace(".remap", "")
			extension = extension.replace(".import", "")
			extension = extension.get_extension()
			if extension_is_invalid(extension):
				filename = directory.get_next()
				continue
			
			var _path: String = "%s/%s.%s" % [path, _name, extension]
			
			match extension:
				"json":
					json_paths[_name] = _path
				"dialogue":
					dialogue_paths[_name] = _path
				"wav", "mp3":
					audio_paths[_name] = _path
				"gd":
					script_paths[_name] = _path
				"png", "svg":
					texture_paths[_name] = _path
				_:
					resource_paths[_name] = _path
		
		filename = directory.get_next()


func folder_is_invalid(filename: StringName) -> bool:
	const INVALID_FOLDER: String = "no_cache"
	return filename == INVALID_FOLDER


func extension_is_invalid(extension: StringName) -> bool:
	const VALID_EXTENSIONS: Array[String] = [
		"png", "jpg", "svg", # Image
		"wav", "mp3", # Audio
		"import", "remap", # Export
		"tscn", "tres", "gd", "json", # Native?
		"dialogue", # Addons
	]
	return not VALID_EXTENSIONS.has(extension)


#endregion


func get_resource(_name: StringName, _default: Variant = null) -> Resource:
	return ResourceLoader.load(resource_paths[_name], "", ResourceLoader.CACHE_MODE_REUSE)


func get_icon(_name: StringName) -> Texture2D:
	return ResourceLoader.load(get_texture_path(_name), "", ResourceLoader.CACHE_MODE_REUSE)


## Returns path of the image or icon.svg (if no _name exists)
func get_texture_path(_name: StringName) -> String:
	return texture_paths.get(_name, "uid://gcyoj5pt5j87") # icon.svg


func get_scene(_name: StringName) -> PackedScene:
	return get_resource(_name)


func instantiate(_name: StringName) -> Node:
	return get_scene(_name).instantiate()


func get_theme(_name: StringName) -> Theme:
	return get_resource(_name)


func get_dialogue(_key: StringName) -> DialogueResource:
	if dialogue_paths.has(_key):
		return ResourceLoader.load(dialogue_paths[_key], "", ResourceLoader.CACHE_MODE_REUSE)
	return null


func get_icon_text(_name: StringName, _color := Color.WHITE) -> String:
	if _color == Color.WHITE:
		return "[img=<16>]%s[/img]" % get_texture_path(_name)
	return "[img=<16> color=#%s]%s[/img]" % [
			_color.to_html(),
			get_texture_path(_name)]


func get_icon_text_from_icon(icon: Texture2D) -> String:
	return "[img=<16>]%s[/img]" % icon.get_path()


func get_json_category(_category: StringName) -> Dictionary:
	for _name: StringName in json_paths.keys():
		var file := FileAccess.open(json_paths[_name], FileAccess.READ)
		var text := file.get_as_text()
		var json := JSON.new()
		json.parse(text)
		if json.data.has(_category):
			var result: Dictionary = json.data.get(_category)
			result.erase("")
			return result
	return {}


func get_all_dialogues() -> Array:
	var result: Array = []
	for key: String in dialogue_paths.keys():
		result.append(get_dialogue(key))
	return result


func get_audio(_key: StringName) -> AudioStream:
	return ResourceLoader.load(audio_paths[_key], "", ResourceLoader.CACHE_MODE_REUSE)

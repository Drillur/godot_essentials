extends Node


const ARROW_THICK_RIGHT: StringName = &"arrow_thick_right"

var done := LoudBool.new()

var resource_paths: Dictionary[StringName, String]
var audio_paths: Dictionary[StringName, String]
var dialogue_paths: Dictionary[StringName, String]
var json_paths: Dictionary[StringName, String]
var texture_paths: Dictionary[StringName, String]
var script_paths: Dictionary[StringName, String]

## All parsed data from [code]all_data.json[/code] and JSON files from mods
var data: Dictionary[StringName, Dictionary] = {
		&"Achievements": {}, &"Currencies": {}, &"Emotes": {}, &"Hands": {}, &"Help": {},
		&"Jobs": {}, &"LOREDs": {}, &"Stages": {}, &"Upgrades": {}, &"UpgradeTrees": {},
		&"DiscordUsernames": {}, }

## The key should be the name of the JSON file. The value will be an array of
## any categories you want to skip during [method init_data].
## In this example, the game will not have any of the default Currencies or
## LOREDs:[code]
## skipped_data[&"all_data"] = [&"Currencies", &"LOREDs"][/code]
var skipped_data: Dictionary[StringName, Array] = {}


#region Init


func _ready():
	var start_time: int = Time.get_ticks_msec()
	store_all_resources()
	init_data()
	if Utility.dev_mode:
		Log.pr("Cached icons and nodes in", int(Time.get_ticks_msec() - start_time), "ms")
	#else:
		#print("Cached icons and nodes in %s ms" % int(Time.get_ticks_msec() - start_time))
	done.set_true()


#region Store All Resources


func store_all_resources() -> void:
	dir_contents("res://groups/")
	dir_contents__mods_unpacked()


func dir_contents__mods_unpacked() -> void:
	var path: String = "res://mods-unpacked/"
	var directory := DirAccess.open(path)
	if not directory:
		push_warning("DirAccess failed to open '%s' -" % path, error_string(DirAccess.get_open_error()))
		return
	
	directory.list_dir_begin()
	var filename: String = directory.get_next()
	
	var statement: String = "Loading mods..."
	var cached_at_least_one_mod: bool = false
	
	while not filename.is_empty():
		var ok: bool = (
				Utility.is_mod_active(filename)
				and not filename == "manifest.json")
		if ok:
			dir_contents(path.path_join(filename))
			statement += "\n - %s loaded" % filename
		else:
			statement += "\n - %s is not enabled. Skipping loading" % filename
		filename = directory.get_next()
		
		cached_at_least_one_mod = true
	
	if cached_at_least_one_mod:
		print(statement)


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
			if invalid_filename(filename):
				filename = directory.get_next()
				continue
			
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


func invalid_filename(filename: StringName) -> bool:
	const INVALID_FILENAMES: Array[String] = [&"manifest.json"]
	return INVALID_FILENAMES.has(filename)


func extension_is_invalid(extension: StringName) -> bool:
	const VALID_EXTENSIONS: Array[String] = [
		# Image
		"png", "jpg", "svg",
		
		# Audio
		"wav", "mp3",
		
		# Export
		"import", "remap",
		
		# Native
		"tscn", "tres", "gd", "json",
		
		# Addons
		"dialogue",
	]
	return not VALID_EXTENSIONS.has(extension)


#endregion


## Populates [code]data[/code] with all of the information in all of the JSON
## files in the base game and mods. By extending this method, you can make any
## change to the data you want.
func init_data() -> void:
	for filename: StringName in json_paths.keys():
		var file := FileAccess.open(json_paths[filename], FileAccess.READ)
		var text: String = file.get_as_text()
		var json: JSON = JSON.new()
		json.parse(text)
		for category: StringName in json.data:
			if skipped_data.has(filename) and skipped_data[filename].has(category):
				continue
			data.get_or_add(category, {}).merge(json.data[category])
			data[category].erase("")
			data[category].erase("0")


#endregion


#region Helper Methods


## Easy way to ensure the game is scrubbed of any vanilla objects
func skip_base_data() -> void:
	skipped_data[&"all_data"] = [&"Currencies", &"Emotes", &"Hands", &"Help",
			&"Jobs", &"LOREDs", &"Stages", &"Upgrades", &"UpgradeTrees"]


#endregion


#region Get


func get_resource(_name: StringName, _default: Variant = null) -> Resource:
	return ResourceLoader.load(
			resource_paths[_name], "", ResourceLoader.CACHE_MODE_REUSE)


#region Get Icon


func get_icon(_name: StringName) -> Texture2D:
	return ResourceLoader.load(
			get_texture_path(_name), "", ResourceLoader.CACHE_MODE_REUSE)


## Returns path of the image or icon.svg (if no _name exists)
func get_texture_path(_name: StringName) -> String:
	const DEFAULT: String = "uid://gcyoj5pt5j87" ## icon.svg
	return texture_paths.get(_name, DEFAULT)


#endregion


func instantiate(_name: StringName) -> Node:
	return get_resource(_name).instantiate()


func get_theme(_name: StringName) -> Theme:
	return get_resource(_name)


func get_dialogue(_key: StringName) -> DialogueResource:
	if dialogue_paths.has(_key):
		return ResourceLoader.load(
				dialogue_paths[_key], "", ResourceLoader.CACHE_MODE_REUSE)
	return null


func get_icon_text(_name: StringName, _color := Color.WHITE) -> String:
	if _color == Color.WHITE:
		return "[img=<16>]%s[/img]" % get_texture_path(_name)
	return "[img=<16> color=#%s]%s[/img]" % [
			_color.to_html(),
			get_texture_path(_name)]


func get_data(category: StringName) -> Dictionary:
	return data[category]


func get_all_dialogues() -> Array:
	var result: Array = []
	for key: String in dialogue_paths.keys():
		result.append(get_dialogue(key))
	return result


func get_audio(_key: StringName) -> AudioStream:
	return ResourceLoader.load(
			audio_paths[_key], "", ResourceLoader.CACHE_MODE_REUSE)


#endregion

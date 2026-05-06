# class_name Utility
extends Node


signal application_focus_in(time_away: float)
signal one_second
signal physics_frame(delta: float)
signal process_frame(delta: float)

enum AudioLayer { MASTER, UI, MUSIC }
enum Platform { PC, BROWSER }

const PLATFORM: Platform = Platform.PC

@export var current_clock: float = Time.get_unix_time_from_system()

var dev_mode: bool = true
var scroll_speed: int = 25 

var class_data: Dictionary[String, String]
var tree: SceneTree
var viewport: Viewport
var window: Window
var game_version: Dictionary[StringName, int] = {}: get = _get_game_version
var rng := RandomNumberGenerator.new()


#region Ready


func _ready() -> void:
	print("Version " + Utility.get_readable_game_version())
	
	tree = get_tree()
	viewport = get_viewport()
	window = viewport.get_window()
	
	cache_class_paths()
	_tick_seconds()


func cache_class_paths() -> void:
	for x: Dictionary in ProjectSettings.get_global_class_list():
		if class_data.has(x["class"]):
			continue
		class_data[x["class"]] = x["path"]


#endregion


#region Getters


func _get_game_version() -> Dictionary[StringName, int]:
	if game_version.is_empty():
		var version: String = ProjectSettings.get("application/config/version")
		var version_split: Array = version.split(".")
		game_version = {
				&"major": int(version_split[0]),
				&"minor": int(version_split[1]),
				&"revision": int(version_split[2])}
	return game_version


#endregion


#region Signals


var time_left_game: float
var game_has_focus := LoudBool.new(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		time_left_game = Time.get_unix_time_from_system()
		game_has_focus.set_false()
	
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		var current_time: float = Time.get_unix_time_from_system()
		var time_away: float = current_time - current_clock
		if time_away > 1:
			application_focus_in.emit(time_away)
		game_has_focus.set_true()


func _process(delta: float) -> void:
	process_frame.emit(delta)


func _physics_process(delta: float) -> void:
	physics_frame.emit(delta)


#endregion


#region Private


func _tick_seconds() -> void:
	await timer(1.0)
	while true:
		await timer(1.0)
		one_second.emit()
		current_clock = Time.get_unix_time_from_system()


#endregion


#region Await


func timer(_duration: float) -> void:
	_duration = maxf(_duration, 0.05)
	await tree.create_timer(_duration).timeout


## Awaits [b]n[/b] physics frames
func physics(_n: int = 1) -> void:
	assert(_n >= 1, "_n should be at least 1")
	for __ in _n:
		await physics_frame


## Awaits [b]n[/b] process frames
func process(_n: int = 1) -> void:
	assert(_n >= 1, "_n should be at least 1")
	for __ in _n:
		await process_frame


## Awaits [b]n[/b] seconds
func second(_n: int = 1) -> void:
	assert(_n >= 1, "_n should be at least 1")
	for __ in _n:
		await one_second


#endregion


#region Control


func set_input_as_handled() -> void:
	viewport.set_input_as_handled()


func kill_tween(tween: Tween) -> void:
	if tween:
		tween.kill()


#region Audio


var audio_stream_players_in_use: int = 0
var available_audio_stream_players: Array[AudioStreamPlayer]


func play_audio(audio: AudioStream, layer: AudioLayer) -> void:
	if audio_stream_players_in_use >= 32:
		return

	if audio == null:
		return
	
	var player: AudioStreamPlayer = _get_audio_player()
	player.stream = audio
	player.pitch_scale = randf_range(0.9, 1.1)
	player.bus = AudioLayer.keys()[layer].capitalize()
	player.volume_db = AudioServer.get_bus_volume_db(layer)
	player.play()


func _get_audio_player() -> AudioStreamPlayer:
	audio_stream_players_in_use += 1

	if available_audio_stream_players.is_empty():
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		player.finished.connect(_free_audio_stream_player.bind(player))
		return player
	
	return available_audio_stream_players.pop_back()


func _free_audio_stream_player(player: AudioStreamPlayer) -> void:
	available_audio_stream_players.append(player)
	audio_stream_players_in_use -= 1


#endregion


#region Game Control


func restart_game() -> void:
	create_new_game_instance()
	quit_game()


func create_new_game_instance() -> void:
	var executable_path: String = OS.get_executable_path()
	OS.create_process(executable_path, [])


func quit_game() -> void:
	tree.quit()


#endregion


#endregion


#region Get


#region Mod


## The mod (according to [param mod_id]) is loaded and active
func is_mod_active(mod_id: String) -> bool:
	return ModLoaderMod.is_mod_active(mod_id)


func create_mod_profile(profile_name: String) -> bool:
	var success: bool = ModLoaderUserProfile.create_profile(profile_name)
	if success:
		var profile := ModLoaderUserProfile.get_profile(profile_name)
		for mod_id: String in profile.mod_list:
			profile.mod_list[mod_id]["is_active"] = false
	return success


func are_any_mods_loaded() -> bool:
	return not ModLoaderStore.mod_data.is_empty()


func mod_profile_exists(profile_name: String) -> bool:
	return ModLoaderStore.user_profiles.has(profile_name)


func is_mod_installed(mod_id: String) -> bool:
	return ModLoaderStore.mod_data.has(mod_id)


#endregion


func get_parsed_json_data(json_path: String) -> Dictionary:
	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		print("FileAccess.open failed")
		return {}
	var json_text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(json_text)
	
	if not parse_error == OK:
		Log.prn(json.data)
		assert(parse_error == OK,
				"The JSON failed to parse. %s" % error_string(parse_error))
	
	return json.data


func get_readable_game_version(version: Dictionary = game_version) -> String:
	return "%s.%s.%s" % [
			int(version.major), int(version.minor), int(version.revision)]


func comes_after(a: String, b: String) -> bool:
	return a.naturalnocasecmp_to(b) < 0


func get_class_path(_class_name: String) -> String:
	return class_data.get(_class_name, "")


## Calculates the total price for [code]n[/code] levels starting from level
## [code]current_level[/code] given the [code]base[/code] price and the
## [code]increase[/code] multiplier
func get_price_of_n_purchases(
		current_level: int, n: int, base: Big, increase: float) -> Big:
	
	var base_price := Big.new(base)
	var multiplier := Big.new(increase)
	
	if multiplier.is_equal_to(Big.ONE):
		return base_price.times(n)
	
	# This is sum of geometric series:
	# 	base * multiplier^start * (multiplier^n - 1) / (multiplier - 1)
	
	var first_term: Big = base_price.times(Big.power(multiplier, current_level))
	var numerator: Big = Big.power(multiplier, n).minus(Big.ONE)
	var denominator: Big = multiplier.minus(Big.ONE)
	var series_sum: Big = numerator.divided_by(denominator)
	
	return Big.multiply(first_term, series_sum)


func get_random_point_in_rect(rect: Rect2) -> Vector2:
	return Vector2(
			rect.position.x + (randf() * rect.size.x),
			rect.position.y + (randf() * rect.size.y))


func get_red_to_green_fade(percent: float) -> Color:
	var r: float = minf(2 - (percent / 0.5), 1.0)
	var g: float = minf(percent / 0.5, 1.0)
	return Color(r, g, 0.0)


func running_above_minimum_fps() -> bool:
	const MINIMUM_FPS: int = 60
	return Engine.get_frames_per_second() >= MINIMUM_FPS


## Returns all vars and @onready vars in Script `script`.
func get_script_variables(script: Script) -> Array[String]:
	const ALLOWED_USAGES: Array[int] = [
		PROPERTY_USAGE_SCRIPT_VARIABLE,
		4102 # @export vars (there is no constant for this
	]
	var variable_names: Array[String] = []
	for property in script.get_script_property_list():
		if ALLOWED_USAGES.has(property.usage):
			variable_names.append(property.name)
	return variable_names


## Loads a resource to the ResourceLoader singleton. It can be fetched with:
## ResourceLoader.load_threaded_get(path)
func load_file_at_path(_path: String, _await: bool = true) -> ResourceLoader.ThreadLoadStatus:
	
	## Begin loading a resource with ResourceLoader.load_threaded_request().
	## You may also skip that step and call this function, it will do it.
	## If `_await` is true, this function will only return when the resource
	## is loaded.

	var load_status: ResourceLoader.ThreadLoadStatus = (
			ResourceLoader.load_threaded_get_status(_path))
	
	# If loading has not yet begun, start the loading now.
	if load_status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(
				_path, "", false, ResourceLoader.CACHE_MODE_REUSE)
	
	if _await:
		while load_status != ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			await Utility.process()
			load_status = ResourceLoader.load_threaded_get_status(_path)
			if load_status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
				printerr("ResourceLoader THREAD_LOAD_FAILED. Path: " + _path)
				return load_status
	
	return load_status


func strip_bbcode(text: String) -> String:
	while text.contains("["):
		var bbcode: String = "[%s]" % text.split("[")[1].split("]")[0]
		text = text.replace(bbcode, "")
	return text


func string_to_key_event(key_string: String) -> InputEventKey:
	const SHIFTED_SYMBOLS: Dictionary[String, Key] = {
		"!": KEY_1, "@": KEY_2, "#": KEY_3, "$": KEY_4,
		"%": KEY_5, "^": KEY_6, "&": KEY_7, "*": KEY_8,
		"(": KEY_9, ")": KEY_0
	}
	
	key_string = key_string.strip_edges()
	var event := InputEventKey.new()
	
	var keycode: Key
	if SHIFTED_SYMBOLS.has(key_string):
		event.shift_pressed = true
		keycode = SHIFTED_SYMBOLS[key_string]
	else:
		keycode = OS.find_keycode_from_string(key_string)
	
	event.physical_keycode = keycode
	return event


func dictionaries_share_keys(dict1: Dictionary, dict2: Dictionary) -> bool:
	if dict1.size() != dict2.size():
		return false
	var keys1: Array = dict1.keys()
	var keys2: Array = dict2.keys()
	return arrays_share_keys(keys1, keys2)


func arrays_share_keys(arr1: Array, arr2: Array) -> bool:
	if arr1.size() != arr2.size():
		return false
	var keys1: Array = arr1.duplicate()
	var keys2: Array = arr2.duplicate()
	keys1.sort()
	keys2.sort()
	return keys1 == keys2


#region Color


func get_color_from_string(x: String) -> Color:
	if x == "random":
		return Utility.get_random_bright_color()
	
	if x.count(", ") == 2:
		# "0.5, 1, 0"
		var color_data: Array = x.split(", ")
		return Color(float(color_data[0]), float(color_data[1]), float(color_data[2]))
	
	if x.begins_with("#"):
		return Color.html(x)
	
	return Color.NAVY_BLUE


func get_random_color() -> Color:
	return Color(randf(), randf(), randf(), 1.0)


func get_random_bright_color() -> Color:
	return validate_color_brightness(get_random_color())


func get_random_dark_color() -> Color:
	return validate_color_darkness(get_random_color())


func validate_color_brightness(color: Color, minimum := 1.0) -> Color:
	if color.r + color.g + color.b == LoudFloat.ZERO:
		color.r = minimum / 3 + 0.01
		color.r = minimum / 3 + 0.01
		color.r = minimum / 3 + 0.01
	while color.r + color.g + color.b < minimum:
		color.r *= 1.1
		color.g *= 1.1
		color.b *= 1.1
	return color


func validate_color_darkness(color: Color, limit := 1.0) -> Color:
	while color.r + color.g + color.b > limit:
		color.r /= 1.1
		color.g /= 1.1
		color.b /= 1.1
	return color


#endregion -


#endregion


#region Dev


func report(object: Object) -> void:
	if not Utility.dev_mode:
		return
	var _class_name: String = object.get_class()
	Log.prn("Report:", _class_name, object, _get_object_report_dictionary(object))


func _get_object_report_dictionary(object: Object) -> Dictionary:
	if object.get_script() == null:
		return {}
	
	var vars: Array[String] = get_script_variables(object.get_script())
	var dict: Dictionary = {}
	
	for var_name: String in vars:
		if var_name == "_class_name":
			continue
		
		var val: Variant = object.get(var_name)
		
		if val is LoudInt or val is LoudFloat:
			dict[var_name] = val.current
		elif val is LoudIntPair or val is LoudFloatPair:
			dict[var_name] = val.get_text()
		elif val is Big or val is BigFloat or val is BigFloatPair:
			dict[var_name] = val.get_text()
		else:
			dict[var_name] = val
	
	return dict


func print_when_changed(loud_var: LoudVar, var_name: String) -> void:
	if not loud_var.changed.is_connected(_print_when_changed):
		loud_var.changed.connect(_print_when_changed.bind(loud_var, var_name))
		_print_when_changed(loud_var, var_name)


func _print_when_changed(loud_var: LoudVar, var_name: String) -> void:
	if Utility.dev_mode:
		Log.pr(var_name, loud_var.get_text())
	else:
		printt(var_name, loud_var.get_text())


#endregion

extends RefCounted

const MODEL_CONFIG_FILENAME := "harness_config.json"

var _save_path: String
var _preference_path: String


func _init(
	save_path: String = "user://restaurant_save.json",
	preference_path: String = "user://workspace.json"
) -> void:
	_save_path = save_path
	_preference_path = preference_path


func load_progress() -> Dictionary:
	var data := _read_dictionary(_save_path)
	if data.has("restaurant") and not data["restaurant"] is String:
		data.erase("restaurant")
	for field: String in ["task_count", "energy"]:
		if not data.has(field):
			continue
		var value: Variant = data[field]
		if not (value is int or value is float) or not is_finite(float(value)):
			data.erase(field)
		else:
			data[field] = int(value)
	if data.has("game_started") and not data["game_started"] is bool:
		data.erase("game_started")
	return data


func save_progress(data: Dictionary) -> bool:
	return _write_dictionary(_save_path, data)


func replace_saved_workspace(folder: String) -> bool:
	if folder.strip_edges().is_empty():
		return false
	var data := load_progress()
	if data.is_empty():
		return false
	data["restaurant"] = folder
	return save_progress(data)


func load_preference() -> String:
	var data := _read_dictionary(_preference_path)
	var folder: Variant = data.get("folder", "")
	return folder if folder is String else ""


func save_preference(folder: String) -> bool:
	if folder.strip_edges().is_empty():
		return false
	return _write_dictionary(_preference_path, {"folder": folder})


func load_model_config(folder: String) -> Dictionary:
	if folder.strip_edges().is_empty():
		return {}
	var data := _read_dictionary(folder.path_join(MODEL_CONFIG_FILENAME))
	for field: String in ["model", "base_url", "api_key"]:
		if data.has(field) and not data[field] is String:
			data.erase(field)
	return data


func save_model_config(folder: String, config: Dictionary) -> bool:
	if folder.strip_edges().is_empty():
		return false
	return _write_dictionary(folder.path_join(MODEL_CONFIG_FILENAME), config)


func _read_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


func _write_dictionary(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK

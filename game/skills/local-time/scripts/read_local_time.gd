extends RefCounted
## Reads the user's device. Never contacts a server or uses the model's clock.

func execute() -> Dictionary:
	if OS.has_feature("web"):
		return _read_browser()
	var local := Time.get_datetime_dict_from_system(false)
	var zone := Time.get_time_zone_from_system()
	# Derive the current offset from simultaneous calendar readings, including DST.
	# Retrying if the wall clock ticks between reads avoids a one-second boundary error.
	var utc := Time.get_datetime_dict_from_system(true)
	for attempt in 3:
		if local.second == utc.second:
			break
		local = Time.get_datetime_dict_from_system(false)
		utc = Time.get_datetime_dict_from_system(true)
	var offset_seconds := Time.get_unix_time_from_datetime_dict(local) - Time.get_unix_time_from_datetime_dict(utc)
	var offset_minutes := int(round(float(offset_seconds) / 60.0))
	return _result(local, str(zone.get("name", "本地时区")), offset_minutes, "设备系统时钟")

func _read_browser() -> Dictionary:
	var encoded = JavaScriptBridge.eval("""
		(() => {
			const now = new Date();
			let timezone = "本地时区";
			try { timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || timezone; } catch (_) {}
			return JSON.stringify({
				year: now.getFullYear(), month: now.getMonth() + 1, day: now.getDate(),
				hour: now.getHours(), minute: now.getMinutes(), second: now.getSeconds(),
				timezone: timezone, utc_offset_minutes: -now.getTimezoneOffset()
			});
		})()
	""", true)
	if not encoded is String:
		return {"ok": false, "error": "无法读取浏览器的本地时间"}
	var json := JSON.new()
	if json.parse(encoded) != OK or not json.data is Dictionary:
		return {"ok": false, "error": "浏览器返回的时间格式无效"}
	var data: Dictionary = json.data
	for field in ["year", "month", "day", "hour", "minute", "second", "utc_offset_minutes"]:
		if not data.has(field) or not (data[field] is int or data[field] is float):
			return {"ok": false, "error": "浏览器返回的时间数据不完整"}
	return _result(data, str(data.get("timezone", "本地时区")), int(data.utc_offset_minutes), "浏览器本地时钟")

func _result(local: Dictionary, timezone: String, offset: int, source: String) -> Dictionary:
	return {"ok": true, "data": {
		"hour": int(local.hour), "minute": int(local.minute), "second": int(local.second),
		"date": "%04d-%02d-%02d" % [int(local.year), int(local.month), int(local.day)],
		"time": "%02d:%02d:%02d" % [int(local.hour), int(local.minute), int(local.second)],
		"timezone": timezone,
		"utc_offset_minutes": offset,
		"source": source,
	}}

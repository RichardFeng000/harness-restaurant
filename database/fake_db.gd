class_name FakeDatabase
extends RefCounted

const VERSION := 1
const CSV_HEADER := ["table", "id", "tenant_id", "data"]
const TABLES := [
	"tenants",
	"users",
	"members",
	"projects",
	"chats",
	"messages",
	"knowledge_bases",
	"documents",
	"memories",
	"agents",
	"runs",
	"events",
]

var _path: String
var _tables: Dictionary = {}
var _sequences: Dictionary = {}

func _init(path: String = "user://harness_v2.csv") -> void:
	_path = path
	reset()

func reset() -> void:
	_tables.clear()
	_sequences.clear()
	for table in TABLES:
		_tables[table] = []
		_sequences[table] = 0

func insert(table: String, values: Dictionary) -> Dictionary:
	if not _tables.has(table):
		return {}
	_sequences[table] = int(_sequences[table]) + 1
	var now := Time.get_unix_time_from_system()
	var record := values.duplicate(true)
	record["id"] = "%s_%04d" % [table.trim_suffix("s"), int(_sequences[table])]
	record["created_at"] = record.get("created_at", now)
	record["updated_at"] = now
	_tables[table].append(record)
	return record.duplicate(true)

func find_by_id(table: String, id: String, tenant_id: String = "") -> Dictionary:
	if not _tables.has(table):
		return {}
	for record in _tables[table]:
		if record["id"] != id:
			continue
		if not tenant_id.is_empty() and record.get("tenant_id", "") != tenant_id:
			return {}
		return record.duplicate(true)
	return {}

func find_many(table: String, filters: Dictionary = {}, tenant_id: String = "") -> Array:
	var results: Array = []
	if not _tables.has(table):
		return results
	for record in _tables[table]:
		if not tenant_id.is_empty() and record.get("tenant_id", "") != tenant_id:
			continue
		if _matches(record, filters):
			results.append(record.duplicate(true))
	return results

func update(table: String, id: String, changes: Dictionary, tenant_id: String = "") -> Dictionary:
	if not _tables.has(table):
		return {}
	for record in _tables[table]:
		if record["id"] != id:
			continue
		if not tenant_id.is_empty() and record.get("tenant_id", "") != tenant_id:
			return {}
		for key in changes:
			if key not in ["id", "tenant_id", "created_at"]:
				record[key] = changes[key]
		record["updated_at"] = Time.get_unix_time_from_system()
		return record.duplicate(true)
	return {}

func delete(table: String, id: String, tenant_id: String = "") -> bool:
	if not _tables.has(table):
		return false
	for index in range(_tables[table].size()):
		var record: Dictionary = _tables[table][index]
		if record["id"] == id and (tenant_id.is_empty() or record.get("tenant_id", "") == tenant_id):
			_tables[table].remove_at(index)
			return true
	return false

func count(table: String, filters: Dictionary = {}, tenant_id: String = "") -> int:
	return find_many(table, filters, tenant_id).size()

func save() -> bool:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_csv_line(PackedStringArray(CSV_HEADER))
	for table in TABLES:
		for record in _tables[table]:
			file.store_csv_line(PackedStringArray([
				table,
				str(record.get("id", "")),
				str(record.get("tenant_id", "")),
				JSON.stringify(record),
			]))
	return true

func load() -> bool:
	if not FileAccess.file_exists(_path):
		return false
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return false
	reset()
	if file.eof_reached():
		return false
	var header := file.get_csv_line()
	if Array(header) != CSV_HEADER:
		return false
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 4 or str(row[0]).is_empty():
			continue
		var table := str(row[0])
		if not _tables.has(table):
			continue
		var record = JSON.parse_string(str(row[3]))
		if not record is Dictionary:
			continue
		_tables[table].append(record)
		_sequences[table] = maxi(int(_sequences[table]), _sequence_from_id(str(record.get("id", ""))))
	return true

func export_data() -> Dictionary:
	return {
		"version": VERSION,
		"tables": _tables.duplicate(true),
		"sequences": _sequences.duplicate(true),
	}

func _sequence_from_id(id: String) -> int:
	var separator := id.rfind("_")
	if separator < 0:
		return 0
	return int(id.substr(separator + 1))

func _matches(record: Dictionary, filters: Dictionary) -> bool:
	for key in filters:
		if record.get(key) != filters[key]:
			return false
	return true

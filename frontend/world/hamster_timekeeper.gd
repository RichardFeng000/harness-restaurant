extends Node
## The hamster runs its assigned skill; only a successful sample moves the clock.

signal working_changed(working: bool)
const STAFF_ID := "hamster"
const SKILL_ID := "local-time"
var runtime: RefCounted
var clock: Node
var active := false
var _next_poll_msec := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func bind(skill_runtime: RefCounted, clock_view: Node) -> void:
	runtime = skill_runtime
	clock = clock_view
	runtime.skill_changed.connect(_skill_changed)
	runtime.execution_completed.connect(_execution_completed)

func set_active(value: bool) -> void:
	active = value
	working_changed.emit(is_working())
	if active:
		sync_now()

func is_working() -> bool:
	return active and runtime != null and runtime.is_enabled(STAFF_ID, SKILL_ID)

func sync_now() -> void:
	if not is_working():
		return
	_next_poll_msec = Time.get_ticks_msec() + 1000
	runtime.execute(STAFF_ID, SKILL_ID)

func _process(_delta: float) -> void:
	if is_working() and Time.get_ticks_msec() >= _next_poll_msec:
		sync_now()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		sync_now()

func _skill_changed(staff_id: String, skill_id: String) -> void:
	if staff_id != STAFF_ID or skill_id != SKILL_ID:
		return
	working_changed.emit(is_working())
	if is_working():
		sync_now()

func _execution_completed(staff_id: String, skill_id: String, result: Dictionary) -> void:
	if staff_id != STAFF_ID or skill_id != SKILL_ID or not active:
		return
	if bool(result.get("ok", false)) and is_working() and is_instance_valid(clock):
		clock.apply_time(result.data)

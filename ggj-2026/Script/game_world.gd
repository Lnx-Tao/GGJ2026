extends Node2D

## 人物在画面中的 X 位置（距左像素，400 = 中间偏左）
const CHARACTER_SCREEN_X := 400
## 睁眼 3 秒内若不在灯光区，怀疑值总共增加 30 格（均匀增加，3 秒内完成）
const SUSPICION_ADD_TOTAL: float = 0.1
const SUSPICION_EYE_DURATION: float = 3.0
## 每秒增加量 = 30格 / 3秒（速度均匀）
const SUSPICION_RATE_PER_SECOND: float = SUSPICION_ADD_TOTAL / SUSPICION_EYE_DURATION
## 进度条显示值追赶真实怀疑值的速度（越大动画越快）
const SUSPICION_BAR_LERP_SPEED: float = 6.0

@onready var camera: Camera2D = $Camera2D
@onready var character: CharacterBody2D = $Character
@onready var supervisor: Node2D = $Supervisor
@onready var suspicion_bar_bg: ColorRect = $SuspicionUI/BarContainer/BarBackground
@onready var suspicion_bar_fill: ColorRect = $SuspicionUI/BarContainer/BarFill
@onready var game_over_label: Label = $SuspicionUI/GameOverLabel

var dancer_mask: Node = null
var suspicion: float = 0.0
var displayed_suspicion: float = 0.0
var game_over: bool = false
## 当前戴上的面具："" | "guard" | "butler" | "dancer"（公主为被动，不在此）
var mask_active: String = ""
## 当前面具是否在警告时戴上（仅此时才具有规避监管效果）
var mask_effective: bool = false
## 主动面具数量（守卫+管家+舞者，总和最多 2）
var guard_count: int = 0
var butler_count: int = 0
var dancer_count: int = 0
## 公主面具数量（最多 1）
var princess_count: int = 0
## 公主面具被动：可自动抵挡一次监管，剩余次数（= princess_count，逻辑上用 princess_charge 表示“可用次数”）
var princess_charge: int = 0
## 上一帧监管者是否睁眼，用于检测闭眼后摘下面具
var _supervisor_was_eye_open: bool = false
## 本轮睁眼是否已触发舞者节奏游戏（只触发一次）
var _dancer_rhythm_triggered: bool = false
## 本轮睁眼是否已用过公主被动（只抵挡一次）
var _princess_used_this_eye: bool = false

func _ready() -> void:
	game_over_label.visible = false
	_update_suspicion_bar(0.0)
	var DancerMaskScript = load("res://Script/dancer_mask.gd") as GDScript
	dancer_mask = DancerMaskScript.new()
	add_child(dancer_mask)
	dancer_mask.rhythm_completed.connect(_on_dancer_mask_completed)

func _input(event: InputEvent) -> void:
	if game_over:
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	# 监管者睁眼时不可使用面具；其它时候均可使用；已戴面具时不再响应
	if supervisor.is_eye_open or mask_active != "":
		return
	match key_event.keycode:
		KEY_1, KEY_KP_1:
			if guard_count <= 0:
				print("没有守卫面具")
				return
			guard_count -= 1
			mask_active = "guard"
			mask_effective = supervisor.is_warning
			character.movement_locked = true
			print("戴上守卫面具（剩余 %d）%s" % [guard_count, "（警告时使用，生效）" if mask_effective else "（非警告时使用，本轮回避无效）"])
		KEY_2, KEY_KP_2:
			if butler_count <= 0:
				print("没有管家面具")
				return
			butler_count -= 1
			mask_active = "butler"
			mask_effective = supervisor.is_warning
			print("戴上管家面具（剩余 %d）%s" % [butler_count, "（警告时使用，生效）" if mask_effective else "（非警告时使用，本轮回避无效）"])
		KEY_4, KEY_KP_4:
			if dancer_count <= 0:
				print("没有舞者面具")
				return
			dancer_count -= 1
			mask_active = "dancer"
			mask_effective = supervisor.is_warning
			print("戴上舞者面具（剩余 %d）%s" % [dancer_count, "（警告时使用，生效）" if mask_effective else "（非警告时使用，本轮回避无效）"])

func _process(delta: float) -> void:
	if game_over:
		return
	if not is_instance_valid(character):
		return
	# 监管者从睁眼变为闭眼：摘下面具，恢复正常
	if _supervisor_was_eye_open and not supervisor.is_eye_open:
		_remove_mask()
		_princess_used_this_eye = false
	if not supervisor.is_eye_open:
		_dancer_rhythm_triggered = false
	_supervisor_was_eye_open = supervisor.is_eye_open

	# 相机跟随
	camera.global_position = character.global_position + Vector2(800 - CHARACTER_SCREEN_X, 0.0)

	# 监管者睁眼期间（3 秒）才计算怀疑值
	if supervisor.is_eye_open:
		var skip_suspicion := false
		if mask_active == "guard" or mask_active == "butler":
			skip_suspicion = mask_effective
		elif mask_active == "dancer":
			if mask_effective and not _dancer_rhythm_triggered and dancer_mask != null and not dancer_mask.is_active():
				dancer_mask.start_rhythm_game(4)
				_dancer_rhythm_triggered = true
			skip_suspicion = mask_effective  # 是否加怀疑由节奏判定回调决定（仅生效时）
		elif mask_active == "" and _princess_used_this_eye:
			# 本轮睁眼已用过公主被动，整轮 3 秒内都不增加怀疑值
			skip_suspicion = true
		elif mask_active == "" and princess_charge > 0 and not _princess_used_this_eye:
			# 公主被动：消耗一次公主面具抵挡本轮
			princess_charge -= 1
			_princess_used_this_eye = true
			skip_suspicion = true
			print("公主面具自动抵挡一次监管")
		if not skip_suspicion:
			if _is_character_in_light_zone():
				# 灯光下：3 秒内逐渐涨满，而不是瞬间满
				var light_rate: float = 1.0 / SUSPICION_EYE_DURATION
				suspicion = minf(1.0, suspicion + delta * light_rate)
			else:
				suspicion = minf(1.0, suspicion + delta * SUSPICION_RATE_PER_SECOND)

	# 进度条动画：显示值追赶真实怀疑值
	displayed_suspicion = lerpf(displayed_suspicion, suspicion, delta * SUSPICION_BAR_LERP_SPEED)
	# 后端已满时保证显示值到 1.0，避免 lerp 因浮点永远到不了 1.0 导致不触发
	if suspicion >= 1.0:
		displayed_suspicion = 1.0
	_update_suspicion_bar(displayed_suspicion)

	# 仅当进度条涨满时才显示游戏失败 UI
	if displayed_suspicion >= 1.0:
		_trigger_game_over()

func _is_character_in_light_zone() -> bool:
	var pos := character.global_position
	for node in get_tree().get_nodes_in_group("light"):
		if node.has_method("get_zone_rect"):
			if node.get_zone_rect().has_point(pos):
				return true
	return false

func _update_suspicion_bar(amount: float) -> void:
	var w: float = suspicion_bar_bg.size.x * clampf(amount, 0.0, 1.0)
	suspicion_bar_fill.offset_left = 0.0
	suspicion_bar_fill.offset_right = w
	suspicion_bar_fill.offset_top = 0.0
	suspicion_bar_fill.offset_bottom = suspicion_bar_bg.size.y

func _trigger_game_over() -> void:
	game_over = true
	game_over_label.visible = true
	get_tree().paused = true

func _remove_mask() -> void:
	if mask_active == "":
		return
	print("摘下面具")
	mask_active = ""
	mask_effective = false
	character.movement_locked = false
	_dancer_rhythm_triggered = false

## 当前主动面具总数是否已达上限（2）
func _active_mask_count() -> int:
	return guard_count + butler_count + dancer_count

## 刺杀后能否获得该类型面具（主动最多 2，公主最多 1）
func can_gain_mask_from_assassination(mask_type_name: String) -> bool:
	if mask_type_name == "princess":
		return princess_count < 1
	return _active_mask_count() < 2

## 刺杀成功：获得对应面具并增加 25% 怀疑值
func add_mask_from_assassination(mask_type_name: String) -> void:
	if mask_type_name == "princess":
		if princess_count >= 1:
			return
		princess_count += 1
		princess_charge += 1
		print("获得公主面具（被动）")
	else:
		if _active_mask_count() >= 2:
			return
		match mask_type_name:
			"guard":
				guard_count += 1
				print("获得守卫面具（%d/2）" % _active_mask_count())
			"butler":
				butler_count += 1
				print("获得管家面具（%d/2）" % _active_mask_count())
			"dancer":
				dancer_count += 1
				print("获得舞者面具（%d/2）" % _active_mask_count())
	suspicion = minf(1.0, suspicion + 0.1)
	print("刺杀行为，怀疑值+10%")

func _on_dancer_mask_completed(result: Dictionary) -> void:
	# 仅当本轮回避生效时（警告时戴上的舞者面具）才根据判定结果影响怀疑值
	if not mask_effective:
		return
	var success: bool = result.get("success", false)
	if success:
		print("舞者面具判定成功，怀疑值不增加")
	else:
		suspicion = minf(1.0, suspicion + 0.1)
		print("舞者面具判定失败，怀疑值+10%")

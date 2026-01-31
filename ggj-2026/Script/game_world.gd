extends Node2D

## 人物在画面中的 X 位置（距左像素，400 = 中间偏左）
const CHARACTER_SCREEN_X := 400

## 以下怀疑值参数可在检查器中直接编辑（选中 GameWorld 节点）
@export_group("怀疑值 - 睁眼时")
## 睁眼时长（秒），与监管者设置一致
@export var suspicion_eye_duration: float = 3.0
## 睁眼时「不在灯光区」：3 秒内总共增加的怀疑值（0.3 = 30%）
@export_range(0.0, 1.0, 0.01) var suspicion_add_outside_light: float = 0.3
## 睁眼时「在灯光下」：3 秒内涨满，此处为“满”的目标值（一般保持 1.0）
@export_range(0.0, 1.0, 0.01) var suspicion_light_full: float = 1.0

@export_group("怀疑值 - 其它")
## 每次刺杀成功增加的怀疑值（0.25 = 25%）
@export_range(0.0, 1.0, 0.01) var suspicion_add_assassination: float = 0.25
## 舞者面具节奏判定失败增加的怀疑值（0.3 = 30%）
@export_range(0.0, 1.0, 0.01) var suspicion_add_dancer_fail: float = 0.3

@export_group("怀疑值 - 进度条")
## 进度条显示值追赶真实怀疑值的速度（越大动画越快）
@export var suspicion_bar_lerp_speed: float = 6.0

@onready var camera: Camera2D = $Camera2D
@onready var character: CharacterBody2D = $Character
@onready var supervisor: Node2D = $Supervisor
@onready var suspicion_bar_bg: ColorRect = $SuspicionUI/BarContainer/BarBackground
@onready var suspicion_bar_fill: ColorRect = $SuspicionUI/BarContainer/BarFill
@onready var game_over_label: Label = $SuspicionUI/GameOverLabel
@onready var mask_slot_label_1: Label = $MaskSlotUI/Slot1Label
@onready var mask_slot_label_2: Label = $MaskSlotUI/Slot2Label
@onready var princess_label: Label = $MaskSlotUI/PrincessLabel

var dancer_mask: Node = null
var suspicion: float = 0.0
var displayed_suspicion: float = 0.0
var game_over: bool = false
## 当前戴上的面具："" | "guard" | "butler" | "dancer"（公主为被动，不在此）
var mask_active: String = ""
## 当前面具是否在警告时戴上（仅此时才具有规避监管效果）
var mask_effective: bool = false
## 主动面具槽位（"" | "guard" | "butler" | "dancer"），最多 2 个
var slot_1: String = ""
var slot_2: String = ""
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
	_update_mask_slot_ui()
	var DancerMaskScript = load("res://Script/dancer_mask.gd") as GDScript
	dancer_mask = DancerMaskScript.new()
	add_child(dancer_mask)
	dancer_mask.rhythm_completed.connect(_on_dancer_mask_completed)

func _input(event: InputEvent) -> void:
	if game_over:
		return
	# 监管者睁眼时不可使用面具；其它时候均可使用；已戴面具时不再响应
	if supervisor.is_eye_open or mask_active != "":
		return
	# 鼠标左键 = 使用槽位1，鼠标右键 = 使用槽位2
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_try_use_slot(1)
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_try_use_slot(2)
			return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	# 按键 1 = 槽位1，按键 2 = 槽位2
	match key_event.keycode:
		KEY_1, KEY_KP_1:
			_try_use_slot(1)
		KEY_2, KEY_KP_2:
			_try_use_slot(2)

func _try_use_slot(slot: int) -> void:
	var s: String = slot_1 if slot == 1 else slot_2
	if s.is_empty():
		print("槽位%d为空" % slot)
		return
	mask_active = s
	mask_effective = supervisor.is_warning
	if slot == 1:
		slot_1 = ""
	else:
		slot_2 = ""
	_update_mask_slot_ui()
	if mask_active == "guard":
		character.movement_locked = true
	print("戴上%s面具（槽位%d）%s" % [_mask_display_name(mask_active), slot, "（警告时使用，生效）" if mask_effective else "（非警告时使用，本轮回避无效）"])

func _mask_display_name(mask_type_name: String) -> String:
	match mask_type_name:
		"guard": return "守卫"
		"butler": return "管家"
		"dancer": return "舞者"
	return ""

func _update_mask_slot_ui() -> void:
	mask_slot_label_1.text = "槽位1：%s面具" % (_mask_display_name(slot_1) if slot_1 != "" else "空")
	mask_slot_label_2.text = "槽位2：%s面具" % (_mask_display_name(slot_2) if slot_2 != "" else "空")
	princess_label.visible = princess_count > 0

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
				# 灯光下：3 秒内逐渐涨到 suspicion_light_full
				var light_rate: float = suspicion_light_full / suspicion_eye_duration
				suspicion = minf(1.0, suspicion + delta * light_rate)
			else:
				var rate: float = suspicion_add_outside_light / suspicion_eye_duration
				suspicion = minf(1.0, suspicion + delta * rate)

	# 进度条动画：显示值追赶真实怀疑值
	displayed_suspicion = lerpf(displayed_suspicion, suspicion, delta * suspicion_bar_lerp_speed)
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

## 刺杀后能否获得该类型面具（主动最多 2，公主最多 1）
func can_gain_mask_from_assassination(mask_type_name: String) -> bool:
	if mask_type_name == "princess":
		return princess_count < 1
	return slot_1 == "" or slot_2 == ""

## 刺杀成功：获得对应面具并增加怀疑值；槽位1空则填槽位1，否则槽位2空则填槽位2
func add_mask_from_assassination(mask_type_name: String) -> void:
	if mask_type_name == "princess":
		if princess_count >= 1:
			return
		princess_count += 1
		princess_charge += 1
		print("获得公主面具（被动）")
		_update_mask_slot_ui()
	else:
		if slot_1 != "" and slot_2 != "":
			return
		if slot_1 == "":
			slot_1 = mask_type_name
			print("获得%s面具（槽位1）" % _mask_display_name(mask_type_name))
		else:
			slot_2 = mask_type_name
			print("获得%s面具（槽位2）" % _mask_display_name(mask_type_name))
		_update_mask_slot_ui()
	suspicion = minf(1.0, suspicion + suspicion_add_assassination)
	print("刺杀行为，怀疑值+%.0f%%" % (suspicion_add_assassination * 100))

func _on_dancer_mask_completed(result: Dictionary) -> void:
	# 仅当本轮回避生效时（警告时戴上的舞者面具）才根据判定结果影响怀疑值
	if not mask_effective:
		return
	var success: bool = result.get("success", false)
	if success:
		print("舞者面具判定成功，怀疑值不增加")
	else:
		suspicion = minf(1.0, suspicion + suspicion_add_dancer_fail)
		print("舞者面具判定失败，怀疑值+%.0f%%" % (suspicion_add_dancer_fail * 100))

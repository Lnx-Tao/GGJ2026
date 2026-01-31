extends Node2D

## 人物在画面中的 X 位置（距左像素，400 = 中间偏左）
const CHARACTER_SCREEN_X := 400
## 摄像机向右跟随的最大距离（像素），超过后相机固定、角色仍可移动
const CAMERA_TRAVEL_MAX := 3200.0

## 以下怀疑值参数可在检查器中直接编辑（选中 GameWorld 节点）
@export_group("怀疑值 - 睁眼时")
## 睁眼时长（秒），与监管者设置一致
@export var suspicion_eye_duration: float = 3.0
## 睁眼时「不在灯光区」：3 秒内总共增加的怀疑值（0.3 = 30%）
@export_range(0.0, 1.0, 0.01) var suspicion_add_outside_light: float = 0.3

@export_group("怀疑值 - 其它")
## 每次刺杀成功增加的怀疑值（0.25 = 25%）
@export_range(0.0, 1.0, 0.01) var suspicion_add_assassination: float = 0.25
## 舞者面具节奏判定失败增加的怀疑值（0.3 = 30%）
@export_range(0.0, 1.0, 0.01) var suspicion_add_dancer_fail: float = 0.3
## 公主面具被动触发一次后，后续所有怀疑值增长的倍率（1.2 = 涨 1.2 倍）
@export_range(0.1, 5.0, 0.05) var suspicion_princess_used_multiplier: float = 1.2

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
## 本轮睁眼期间玩家是否移动过（用于无面具时：移动则立即游戏失败，不移动则正常增长）
var _moved_during_eye_open: bool = false
## 本局是否已被动触发过公主面具（触发后后续怀疑值增长乘 suspicion_princess_used_multiplier）
var _princess_passive_ever_used: bool = false
## 上一帧怀疑值，用于检测变化并输出到控制台
var _last_suspicion: float = -1.0
## 相机起始世界 X（用于计算右移 3200 后固定），-inf 表示未初始化
var _camera_start_x: float = -INF

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
	var was_eye_open_last_frame: bool = _supervisor_was_eye_open
	# 监管者从睁眼变为闭眼：摘下面具，恢复正常
	if _supervisor_was_eye_open and not supervisor.is_eye_open:
		_remove_mask()
		_princess_used_this_eye = false
	if not supervisor.is_eye_open:
		_dancer_rhythm_triggered = false
		_moved_during_eye_open = false
	# 刚进入睁眼：重置“本轮是否移动”
	if supervisor.is_eye_open and not _supervisor_was_eye_open:
		_moved_during_eye_open = false
	# 睁眼期间：有位移或正在按移动键都记为“移动过”（避免 velocity 晚一帧导致漏判）
	if supervisor.is_eye_open:
		if abs(character.velocity.x) > 0.1 or Input.is_action_pressed("ui_select"):
			_moved_during_eye_open = true
	_supervisor_was_eye_open = supervisor.is_eye_open

	# 相机跟随（只跟随x，y固定为450）；右移 3200 像素后固定，角色仍可移动
	var desired_cam_x: float = character.global_position.x + (800 - CHARACTER_SCREEN_X)
	if _camera_start_x <= -INF:
		_camera_start_x = desired_cam_x
	var cam_x: float = minf(desired_cam_x, _camera_start_x + CAMERA_TRAVEL_MAX)
	camera.global_position = Vector2(cam_x, 450.0)

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
			# 公主被动：消耗一次公主面具抵挡本轮；之后所有怀疑值增长乘倍率
			princess_charge -= 1
			_princess_used_this_eye = true
			_princess_passive_ever_used = true
			skip_suspicion = true
			print("公主面具自动抵挡一次监管")
		if not skip_suspicion:
			if _is_character_in_light_zone():
				# 灯光下：直接游戏失败，进度条保持原状
				_trigger_game_over()
				return
			if _moved_during_eye_open:
				# 未戴面具且本轮移动过：直接游戏失败，进度条保持原状
				_trigger_game_over()
				return
			# 未戴面具且未移动：正常增长（仅从睁眼第二帧开始加，避免第一帧误判未移动导致先涨一点再触发“移动”失败）
			if was_eye_open_last_frame:
				var mult: float = _suspicion_growth_multiplier()
				var rate: float = suspicion_add_outside_light / suspicion_eye_duration
				suspicion = minf(1.0, suspicion + delta * rate * mult)

	# 进度条动画：显示值追赶真实怀疑值
	displayed_suspicion = lerpf(displayed_suspicion, suspicion, delta * suspicion_bar_lerp_speed)
	# 后端已满（或浮点接近满）时强制显示 1.0，避免浮点误差导致游戏失败 UI 不触发
	if suspicion >= 0.9999:
		suspicion = 1.0
		displayed_suspicion = 1.0
	_update_suspicion_bar(displayed_suspicion)

	# 仅当进度条涨满时才显示游戏失败 UI（用 epsilon 避免浮点误差漏判）
	if displayed_suspicion >= 0.9999:
		_trigger_game_over()

	# 怀疑值变化时输出到控制台（用 epsilon 避免浮点抖动刷屏）
	if _last_suspicion < 0.0:
		_last_suspicion = suspicion
	elif abs(suspicion - _last_suspicion) > 0.0001:
		print("怀疑值: %.2f (变化: %+.2f)" % [suspicion, suspicion - _last_suspicion])
		_last_suspicion = suspicion

func _suspicion_growth_multiplier() -> float:
	return suspicion_princess_used_multiplier if _princess_passive_ever_used else 1.0

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
	var add_val: float = suspicion_add_assassination * _suspicion_growth_multiplier()
	suspicion = minf(1.0, suspicion + add_val)
	print("刺杀行为，怀疑值+%.0f%%" % (add_val * 100))

func _on_dancer_mask_completed(result: Dictionary) -> void:
	# 仅当本轮回避生效时（警告时戴上的舞者面具）才根据判定结果影响怀疑值
	if not mask_effective:
		return
	var success: bool = result.get("success", false)
	if success:
		print("舞者面具判定成功，怀疑值不增加")
	else:
		var add_val: float = suspicion_add_dancer_fail * _suspicion_growth_multiplier()
		suspicion = minf(1.0, suspicion + add_val)
		print("舞者面具判定失败，怀疑值+%.0f%%" % (add_val * 100))

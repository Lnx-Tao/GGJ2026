extends Node2D

## 人物在画面中的 X 位置（距左像素，400 = 中间偏左）
const CHARACTER_SCREEN_X := 400
## 睁眼 3 秒内若不在灯光区，怀疑值总共增加 30 格（均匀增加，3 秒内完成）
const SUSPICION_ADD_TOTAL: float = 0.3
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

func _ready() -> void:
	game_over_label.visible = false
	_update_suspicion_bar(0.0)
	# 舞者面具：挂到场景上，按 D 键触发
	var DancerMaskScript = load("res://Script/dancer_mask.gd") as GDScript
	dancer_mask = DancerMaskScript.new()
	add_child(dancer_mask)
	dancer_mask.rhythm_completed.connect(_on_dancer_mask_completed)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_D:
			if game_over:
				return
			if dancer_mask != null and not dancer_mask.is_active():
				dancer_mask.start_rhythm_game(4)

func _process(delta: float) -> void:
	if game_over:
		return
	if not is_instance_valid(character):
		return
	# 相机跟随
	camera.global_position = character.global_position + Vector2(800 - CHARACTER_SCREEN_X, 0.0)

	# 监管者睁眼期间（3 秒）才计算怀疑值
	if supervisor.is_eye_open:
		if _is_character_in_light_zone():
			suspicion = 1.0
		else:
			suspicion = minf(1.0, suspicion + delta * SUSPICION_RATE_PER_SECOND)

	# 进度条动画：显示值平滑追赶真实怀疑值
	displayed_suspicion = lerpf(displayed_suspicion, suspicion, delta * SUSPICION_BAR_LERP_SPEED)
	_update_suspicion_bar(displayed_suspicion)

	if suspicion >= 1.0:
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

func _on_dancer_mask_completed(_result: Dictionary) -> void:
	# 舞者面具节奏游戏结束后的回调，可按需扩展（如加分、减怀疑值等）
	pass

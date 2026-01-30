extends Node2D

## 睁眼间隔：最小秒数
@export var eye_interval_min: float = 4.0
## 睁眼间隔：最大秒数
@export var eye_interval_max: float = 8.0
## 睁眼前提示时长（秒）
@export var warning_duration: float = 1.5
## 睁眼后眼睛左右看持续时间（秒）
@export var eye_look_duration: float = 3.0

@onready var warning_label: Label = $CanvasLayer/UIRoot/WarningLabel
@onready var eye_container: Control = $CanvasLayer/UIRoot/EyeContainer
@onready var eye_sprite: ColorRect = $CanvasLayer/UIRoot/EyeContainer/EyeSprite

var _state: String = "idle"  # idle | warning | eye_open
var _timer: float = 0.0
var _next_eye_in: float = 0.0
var _eye_look_t: float = 0.0
var _viewport_center: Vector2 = Vector2(800, 450)

func _ready() -> void:
	_center_ui()
	warning_label.visible = false
	eye_container.visible = false
	_schedule_next_eye()

func _center_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_viewport_center = viewport_size / 2.0

func _schedule_next_eye() -> void:
	_state = "idle"
	_next_eye_in = randf_range(eye_interval_min, eye_interval_max)
	_timer = 0.0

func _process(delta: float) -> void:
	_timer += delta

	match _state:
		"idle":
			if _timer >= _next_eye_in - warning_duration:
				_state = "warning"
				warning_label.visible = true
				_timer = 0.0
		"warning":
			if _timer >= warning_duration:
				warning_label.visible = false
				_state = "eye_open"
				eye_container.visible = true
				_eye_look_t = 0.0
				_timer = 0.0
		"eye_open":
			_eye_look_t += delta
			_update_eye_look()
			if _eye_look_t >= eye_look_duration:
				eye_container.visible = false
				_schedule_next_eye()

func _update_eye_look() -> void:
	# 3 秒内左右看：约 2 个来回（左→右→左→右）
	var cycle := 0.75
	var t := fmod(_eye_look_t, cycle) / cycle
	var x_offset: float
	if t < 0.5:
		x_offset = lerpf(-120.0, 120.0, t * 2.0)
	else:
		x_offset = lerpf(120.0, -120.0, (t - 0.5) * 2.0)
	eye_container.offset_left = -40.0 + x_offset
	eye_container.offset_right = 40.0 + x_offset

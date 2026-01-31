extends Enemy

## 以下参数可在检查器中直接编辑（选中管家 Butler 节点）
@export_group("巡逻")
## 巡逻移动速度（像素/秒），缓慢移动
@export_range(10.0, 150.0, 5.0) var move_speed: float = 40.0
## 巡逻范围（像素），以出生点为中点左右各移动该距离
@export_range(20.0, 200.0, 10.0) var patrol_range: float = 80.0

var _patrol_start_x: float = 0.0
var _patrol_direction: float = 1.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	mask_type = "butler"
	super._ready()
	_patrol_start_x = global_position.x

func _physics_process(delta: float) -> void:
	var dx: float = move_speed * _patrol_direction * delta
	global_position.x += dx
	if global_position.x >= _patrol_start_x + patrol_range:
		global_position.x = _patrol_start_x + patrol_range
		_patrol_direction = -1.0
		_sprite.flip_h = true
	elif global_position.x <= _patrol_start_x - patrol_range:
		global_position.x = _patrol_start_x - patrol_range
		_patrol_direction = 1.0
		_sprite.flip_h = false

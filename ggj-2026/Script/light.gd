extends Node2D

## 灯光区域大小（用于判断小木偶是否在灯光内）
@export var zone_size: Vector2 = Vector2(128, 128)

func _ready() -> void:
	add_to_group("light")

## 世界坐标下的灯光区域矩形（中心为节点位置）
func get_zone_rect() -> Rect2:
	var half := zone_size / 2.0
	return Rect2(global_position - half, zone_size)

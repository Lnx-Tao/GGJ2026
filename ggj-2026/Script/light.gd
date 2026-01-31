extends Node2D

## 灯光区域大小（用于判断小木偶是否在灯光内）；若为 (0,0) 则使用 Sprite2D 的实际区域
@export var zone_size: Vector2 = Vector2(0, 0)

func _ready() -> void:
	add_to_group("light")

## 世界坐标下的灯光区域矩形（与 Sprite2D 区域一致，用于与角色 BodyShape 重叠判定）
func get_zone_rect() -> Rect2:
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite != null:
		var r: Rect2 = sprite.get_rect()
		return Rect2(sprite.global_position + r.position * sprite.scale, r.size * sprite.scale)
	if zone_size.x > 0 and zone_size.y > 0:
		var half := zone_size / 2.0
		return Rect2(global_position - half, zone_size)
	return Rect2(global_position, Vector2(1, 1))

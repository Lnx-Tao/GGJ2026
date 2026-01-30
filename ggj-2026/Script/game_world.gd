extends Node2D

## 人物在画面中的 X 位置（距左像素，400 = 中间偏左）
const CHARACTER_SCREEN_X := 400

@onready var camera: Camera2D = $Camera2D
@onready var character: CharacterBody2D = $Character

func _process(_delta: float) -> void:
	if not is_instance_valid(character):
		return
	# 相机跟随：使人物始终在画面 x=CHARACTER_SCREEN_X 处（视口中心 800，故相机 = 人物 - 400）
	camera.global_position = character.global_position + Vector2(800 - CHARACTER_SCREEN_X, 0.0)

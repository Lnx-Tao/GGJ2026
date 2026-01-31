extends CharacterBody2D

## 以下参数可在检查器中直接编辑（选中玩家 Character 节点）
@export_group("移动")
## 移动速度（像素/秒），不戴面具时的速度
@export_range(50.0, 800.0, 10.0) var move_speed: float = 300.0
## 使用管家面具时的移动速度（像素/秒），可与不戴面具时不同
@export_range(50.0, 800.0, 10.0) var butler_mask_move_speed: float = 180.0
## 为 true 时无法移动（如戴上守卫面具时由 game_world 设置）
var movement_locked: bool = false

@onready var attack_shape: CollisionShape2D = $AttackShape
@onready var body_shape: CollisionShape2D = $BodyShape
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var disguise_container: Node2D = $DisguiseContainer
## SpriteFrames 动画名：移动=walk，刺杀=hit，使用面具=change
const ANIM_WALK: StringName = &"walk"
const ANIM_HIT: StringName = &"hit"
const ANIM_CHANGE: StringName = &"change"
## 静止时显示 walk 动画的第几帧（0 为第一帧，4 为第五帧）
const WALK_IDLE_FRAME: int = 4
## 刺杀检测距离（若形状重叠未检测到则用此距离找最近敌人）
const ASSASSINATION_DISTANCE: float = 120.0
## 刺杀形状检测的碰撞层（敌人在 layer 2）
const ASSASSINATION_COLLISION_MASK: int = 2
## 按下 E 后延迟多少秒才造成真实伤害（前这段时间只播 hit 动画）
const ASSASSINATION_DAMAGE_DELAY: float = 0.6
## 形象切换渐隐/渐显时长（秒）
const DISGUISE_FADE_DURATION: float = 0.35
## 各面具对应敌人场景路径（用于戴上面具时显示对应形象）
const DISGUISE_SCENES: Dictionary = {
	"guard": "res://Prefab/enemy_guard.tscn",
	"butler": "res://Prefab/enemy_butler.tscn",
	"dancer": "res://Prefab/enemy_dancer.tscn",
	"princess": "res://Prefab/enemy_princess.tscn"
}
## 各面具形象默认动画名（与敌人预制体一致）
const DISGUISE_ANIM: Dictionary = { "guard": &"idle", "butler": &"walk", "dancer": &"idle", "princess": &"idle" }
## 上一帧场景中的 mask_active，用于检测“刚使用面具”以播放 change
var _prev_mask_active: String = ""
## 当前显示的伪装形象类型（"" 表示未伪装）
var _current_disguise: String = ""
## 各面具类型的伪装精灵（AnimatedSprite2D），运行时从敌人场景提取
var _disguise_sprites: Dictionary = {}

func _ready() -> void:
	if not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)
	_setup_disguise_sprites()
	_show_walk_idle()

func _setup_disguise_sprites() -> void:
	for mask_type: String in DISGUISE_SCENES:
		var path: String = DISGUISE_SCENES[mask_type]
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			continue
		var root: Node = scene.instantiate()
		var spr: AnimatedSprite2D = root.get_node_or_null("AnimatedSprite2D")
		if spr == null:
			root.queue_free()
			continue
		root.remove_child(spr)
		root.queue_free()
		disguise_container.add_child(spr)
		spr.position = Vector2.ZERO
		spr.modulate.a = 0.0
		spr.visible = false
		spr.z_index = 1
		# 各伪装保持与对应敌人预制体一致的尺寸；仅管家放大到 0.8 并朝右
		match mask_type:
			"butler":
				spr.scale = Vector2(-0.8, 0.8)
			"guard":
				spr.scale = Vector2(0.47, 0.47)
			"dancer":
				spr.scale = Vector2(0.41, 0.41)
			"princess":
				spr.scale = Vector2(0.558, 0.558)
		_disguise_sprites[mask_type] = spr

func _show_walk_idle() -> void:
	## 静止：显示 walk 的第 5 帧，不播放动画
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(ANIM_WALK):
		return
	sprite.animation = ANIM_WALK
	var fc: int = sprite.sprite_frames.get_frame_count(ANIM_WALK)
	sprite.frame = clampi(WALK_IDLE_FRAME, 0, fc - 1) if fc > 0 else 0
	sprite.speed_scale = 0.0

func _transition_to_disguise(mask_type: String) -> void:
	if mask_type not in _disguise_sprites:
		_show_walk_idle()
		return
	var ds: AnimatedSprite2D = _disguise_sprites[mask_type]
	# 先隐藏其它伪装，只显示当前
	for k: String in _disguise_sprites:
		var s: AnimatedSprite2D = _disguise_sprites[k]
		s.visible = (k == mask_type)
		s.modulate.a = 0.0
	ds.visible = true
	var anim_name: StringName = DISGUISE_ANIM.get(mask_type, &"idle")
	if ds.sprite_frames != null and ds.sprite_frames.has_animation(anim_name):
		if mask_type == "butler":
			# 管家：初始静止，等 _update_disguise_animation 在移动时再播 walk
			ds.speed_scale = 0.0
			ds.animation = anim_name
			ds.frame = 0
		else:
			ds.speed_scale = 1.0
			ds.play(anim_name)
	_current_disguise = mask_type
	# 主精灵切到 walk 静止，否则 anim_locked 一直为 true（仍为 ANIM_CHANGE）导致无法移动
	_show_walk_idle()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, DISGUISE_FADE_DURATION)
	tween.tween_property(ds, "modulate:a", 1.0, DISGUISE_FADE_DURATION)

## 摘下面具时由 game_world 调用：伪装形象渐淡，原形象由虚变实
func unmask_visual() -> void:
	if _current_disguise.is_empty():
		return
	var ds: AnimatedSprite2D = _disguise_sprites.get(_current_disguise, null)
	if ds == null:
		_current_disguise = ""
		sprite.modulate.a = 1.0
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ds, "modulate:a", 0.0, DISGUISE_FADE_DURATION)
	tween.tween_property(sprite, "modulate:a", 1.0, DISGUISE_FADE_DURATION)
	tween.finished.connect(_on_unmask_tween_finished.bind(_current_disguise))
	_current_disguise = ""

func _on_unmask_tween_finished(mask_type: String) -> void:
	if mask_type in _disguise_sprites:
		_disguise_sprites[mask_type].visible = false
		_disguise_sprites[mask_type].modulate.a = 0.0
	sprite.modulate.a = 1.0
	_show_walk_idle()

func _update_disguise_animation() -> void:
	if _current_disguise.is_empty() or _current_disguise not in _disguise_sprites:
		return
	var ds: AnimatedSprite2D = _disguise_sprites[_current_disguise]
	var anim_name: StringName = DISGUISE_ANIM.get(_current_disguise, &"idle")
	if ds.sprite_frames == null or not ds.sprite_frames.has_animation(anim_name):
		return
	if _current_disguise == "butler":
		# 管家：移动时播 walk，静止时停在第 0 帧
		if abs(velocity.x) > 0.1:
			ds.speed_scale = 1.0
			ds.play(anim_name)
		else:
			ds.speed_scale = 0.0
			ds.animation = anim_name
			ds.frame = 0
	else:
		# 守卫/舞者/公主：保持 idle
		ds.speed_scale = 1.0
		if ds.animation != anim_name:
			ds.play(anim_name)

func _on_sprite_animation_finished() -> void:
	if sprite.animation == ANIM_HIT:
		_show_walk_idle()
		return
	if sprite.animation == ANIM_CHANGE:
		var gw = get_tree().current_scene
		# 警告时使用面具：切到对应形象（原形象渐淡，新形象由虚变实）
		if gw != null and "mask_effective" in gw and gw.mask_effective and "mask_active" in gw:
			var mt: String = gw.mask_active
			if mt in _disguise_sprites:
				_transition_to_disguise(mt)
				return
		# 非警告时使用面具：只播 change，不换形象，直接恢复原状
		_show_walk_idle()

func _process(_delta: float) -> void:
	var gw = get_tree().current_scene
	# 检测“刚使用面具”（鼠标左右键使用槽位）→ 播放 change
	if gw != null and "mask_active" in gw:
		if gw.mask_active != "" and _prev_mask_active == "":
			if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(ANIM_CHANGE):
				sprite.speed_scale = 1.0
				sprite.play(ANIM_CHANGE)
		_prev_mask_active = gw.mask_active
	else:
		_prev_mask_active = ""

func _physics_process(_delta: float) -> void:
	velocity.x = 0.0
	velocity.y = 0.0
	# 播放 hit 或 change 时无法移动
	var anim_locked: bool = sprite.sprite_frames != null and (sprite.animation == ANIM_HIT or sprite.animation == ANIM_CHANGE)
	if anim_locked:
		move_and_slide()
		return
	if not movement_locked and Input.is_action_pressed("ui_select"):  # 空格键
		var speed: float = _get_current_move_speed()
		velocity.x = speed
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(ANIM_WALK):
			sprite.speed_scale = 1.0
			sprite.play(ANIM_WALK)
	else:
		# 未移动且未在播 hit/change 时：静止为 walk 第 5 帧，不播放
		if sprite.animation == ANIM_WALK and sprite.speed_scale > 0.0:
			_show_walk_idle()
	move_and_slide()
	if not _current_disguise.is_empty():
		_update_disguise_animation()

func _get_current_move_speed() -> float:
	var gw = get_tree().current_scene
	if gw != null and "mask_active" in gw and gw.mask_active == "butler":
		return butler_mask_move_speed
	return move_speed

## 返回角色身体（BodyShape）在世界坐标下的矩形，用于灯光区域等重叠判定
func get_body_shape_global_rect() -> Rect2:
	if body_shape == null or body_shape.shape == null:
		return Rect2(global_position, Vector2.ZERO)
	var rect_shape := body_shape.shape as RectangleShape2D
	if rect_shape == null:
		return Rect2(body_shape.global_position, Vector2.ZERO)
	return Rect2(body_shape.global_position, rect_shape.size)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_E:
			try_assassinate()

func try_assassinate() -> void:
	var gw = get_tree().current_scene
	if gw == null or not gw.has_method("can_gain_mask_from_assassination") or not gw.has_method("add_mask_from_assassination"):
		return
	# 立刻播放刺杀动画 hit；真实伤害在 ASSASSINATION_DAMAGE_DELAY 秒后才判定
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(ANIM_HIT):
		sprite.speed_scale = 1.0
		sprite.play(ANIM_HIT)
	var t := get_tree().create_timer(ASSASSINATION_DAMAGE_DELAY)
	t.timeout.connect(_apply_assassination_damage)

## 返回与 AttackShape（CollisionShape2D）形状重叠的物理体（用于刺杀判定）
func _get_bodies_in_attack_shape() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if attack_shape == null or attack_shape.shape == null:
		return out
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return out
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = attack_shape.shape
	params.transform = attack_shape.global_transform
	params.collision_mask = ASSASSINATION_COLLISION_MASK
	params.exclude = [get_rid()]
	var results: Array[Dictionary] = space_state.intersect_shape(params)
	for result in results:
		var collider: Variant = result.get("collider", null)
		if collider is Node2D:
			out.append(collider as Node2D)
	return out

func _apply_assassination_damage() -> void:
	var gw = get_tree().current_scene
	if gw == null or not gw.has_method("can_gain_mask_from_assassination") or not gw.has_method("add_mask_from_assassination"):
		return
	# 用 AttackShape（CollisionShape2D）的形状做物理重叠检测
	var bodies: Array[Node2D] = _get_bodies_in_attack_shape()
	for body in bodies:
		if body == self:
			continue
		if not body.is_in_group("enemy"):
			continue
		if not body.has_method("take_assassination"):
			continue
		var mask_type_str: String = body.mask_type if "mask_type" in body else ""
		if mask_type_str.is_empty():
			continue
		if not gw.can_gain_mask_from_assassination(mask_type_str):
			continue
		var mt: String = body.take_assassination()
		gw.add_mask_from_assassination(mt)
		return
	# 若形状范围内没有重叠：用距离再找一次（防止碰撞未刷新）
	var char_pos := global_position
	var nearest: Node2D = null
	var nearest_d: float = ASSASSINATION_DISTANCE
	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node) or not node is Node2D:
			continue
		var n: Node2D = node as Node2D
		if not n.has_method("take_assassination"):
			continue
		var d: float = char_pos.distance_to(n.global_position)
		if d < nearest_d:
			var mt_str: String = n.mask_type if "mask_type" in n else ""
			if mt_str.is_empty():
				continue
			if not gw.can_gain_mask_from_assassination(mt_str):
				continue
			nearest_d = d
			nearest = n
	if nearest != null:
		var mt: String = nearest.take_assassination()
		gw.add_mask_from_assassination(mt)

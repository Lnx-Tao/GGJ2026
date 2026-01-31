extends Control

## 舞者面具UI控制器
## 负责显示节奏判定界面和处理玩家输入

signal rhythm_completed(result: Dictionary)

## UI节点引用
@onready var track_line: Line2D = $TrackLine
@onready var beat_nodes: Node2D = $BeatNodes
@onready var indicator: ColorRect = $Indicator
@onready var instruction_label: Label = $InstructionLabel
@onready var score_label: Label = $ScoreLabel

## 游戏参数
var beat_count: int = 4
var pointer_speed: float = 200.0  # 像素/秒
var tolerance: float = 30.0  # 判定容差（像素）

## 游戏状态
var is_active: bool = false
var pointer_moving: bool = false  # 指针是否开始移动
var pointer_position: float = 0.0
var track_length: float = 600.0
var beat_positions: Array[float] = []
var hit_beats: Array[bool] = []
var current_beat_index: int = 0

## 开始游戏
func start_game(beats: int, speed: float, tol: float) -> void:
	beat_count = beats
	pointer_speed = speed
	tolerance = tol
	
	# 重置状态
	is_active = true
	pointer_moving = false  # 等待空格键才开始移动
	pointer_position = 0.0
	current_beat_index = 0
	hit_beats.clear()
	hit_beats.resize(beat_count)
	for i in range(beat_count):
		hit_beats[i] = false
	
	# 计算节奏点位置（均匀分布）
	beat_positions.clear()
	var spacing = track_length / (beat_count + 1)
	for i in range(beat_count):
		beat_positions.append(spacing * (i + 1))
	
	# 创建节奏点
	_create_beat_nodes()
	
	# 更新UI
	_update_ui()
	
	# 更新指令文本
	if instruction_label != null:
		instruction_label.text = "按空格键开始，经过节奏点时按空格键判定"
	
	# 显示UI
	visible = true

## 创建节奏点节点
func _create_beat_nodes() -> void:
	# 清除旧的节点
	if beat_nodes != null:
		for child in beat_nodes.get_children():
			child.queue_free()
	
	# 创建新的节奏点（使用圆形，更符合需求）
	for i in range(beat_count):
		var beat = ColorRect.new()
		beat.size = Vector2(20, 20)
		beat.position = Vector2(beat_positions[i] - 10, -10)
		beat.color = Color(0.6, 0.2, 0.8, 1.0)  # 紫色
		# 可选：使用圆形纹理（如果有的话）
		beat_nodes.add_child(beat)

## 更新UI显示
func _update_ui() -> void:
	# 更新指针位置（相对于轨道起点，轨道在X=500处）
	if indicator != null:
		indicator.position.x = 500 + pointer_position - 2  # 500是轨道起点，-2是居中调整
	
	# 更新分数显示
	if score_label != null:
		var hit_count = 0
		for hit in hit_beats:
			if hit:
				hit_count += 1
		score_label.text = "舞姿正确: %d/%d" % [hit_count, beat_count]
	
	# 更新指令文本（只需要设置一次，但保留以防需要动态更新）
	if instruction_label != null and instruction_label.text.is_empty():
		instruction_label.text = "舞者应随着旋律舞动"

## 处理输入
func _input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# 处理空格键
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_SPACE and key_event.pressed:
			if not pointer_moving:
				# 第一次按空格，开始移动
				pointer_moving = true
				if instruction_label != null:
					instruction_label.text = "舞者应随着旋律舞动"
			else:
				# 移动中按空格，进行判定
				_check_hit()

## 检查是否击中节奏点
func _check_hit() -> void:
	# 找到最近的节奏点
	var nearest_index = -1
	var nearest_distance = tolerance + 1.0
	
	for i in range(beat_count):
		if hit_beats[i]:  # 已经击中过，跳过
			continue
		
		var distance = abs(pointer_position - beat_positions[i])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i
	
	# 判定
	if nearest_index >= 0 and nearest_distance <= tolerance:
		hit_beats[nearest_index] = true
		current_beat_index += 1
		
		# 视觉反馈：改变节奏点颜色
		if beat_nodes != null and beat_nodes.get_child_count() > nearest_index:
			var beat_node = beat_nodes.get_child(nearest_index)
			if beat_node is ColorRect:
				beat_node.color = Color(0.2, 0.8, 0.2, 1.0)  # 绿色表示成功
		
		# 检查是否全部完成
		if current_beat_index >= beat_count:
			_complete_game(true)
		else:
			_update_ui()
	else:
		# 未击中，可以添加失败反馈
		pass

## 完成游戏
func _complete_game(success: bool) -> void:
	is_active = false
	
	# 计算击中数量
	var hit_count = 0
	for hit in hit_beats:
		if hit:
			hit_count += 1
	
	var result = {
		"success": success,
		"hit_count": hit_count,
		"total_beats": beat_count,
		"score": float(hit_count) / float(beat_count) * 100.0
	}
	
	# 延迟一小段时间后发送结果，让玩家看到最终状态
	await get_tree().create_timer(0.5).timeout
	rhythm_completed.emit(result)
	queue_free()

## 游戏循环
func _process(delta: float) -> void:
	if not is_active:
		return
	
	# 只有在开始移动后才更新指针位置
	if pointer_moving:
		# 移动指针
		pointer_position += pointer_speed * delta
		
		# 检查是否超出范围
		if pointer_position > track_length:
			# 如果还有未击中的节奏点，判定为失败
			if current_beat_index < beat_count:
				_complete_game(false)
			else:
				_complete_game(true)
			return
	
	# 更新UI（每帧更新指针位置和分数）
	_update_ui()

## 初始化
func _ready() -> void:
	# 确保在暂停时也能处理
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 获取节点引用（如果场景中已定义）
	if track_line == null:
		track_line = $TrackLine
	if beat_nodes == null:
		beat_nodes = $BeatNodes
	if indicator == null:
		indicator = $Indicator
	if instruction_label == null:
		instruction_label = $InstructionLabel
	if score_label == null:
		score_label = $ScoreLabel
	
	# 设置轨道长度和位置（轨道在屏幕中央，X=500开始）
	track_length = 600.0
	
	# 初始隐藏
	visible = false


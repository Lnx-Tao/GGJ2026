extends Control

## 游戏主菜单控制器

@onready var start_button: Button = $StartButton
@onready var help_button: Button = $HelpButton
@onready var title_label: Label = $TitleLabel
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

func _ready() -> void:
	# 连接按钮信号
	start_button.pressed.connect(_on_start_button_pressed)
	help_button.pressed.connect(_on_help_button_pressed)
	
	# 确保游戏未暂停
	get_tree().paused = false
	
	# 设置背景音乐循环播放
	if bgm_player.stream:
		# 确保音乐会循环播放
		if bgm_player.stream is AudioStreamOggVorbis:
			bgm_player.stream.loop = true
		# 如果autoplay没有自动播放，手动播放
		if not bgm_player.playing:
			bgm_player.play()

## 开始游戏按钮点击
func _on_start_button_pressed() -> void:
	# 切换到游戏场景
	get_tree().change_scene_to_file("res://Scene/GameWorld.tscn")

## 帮助按钮点击（预留功能）
func _on_help_button_pressed() -> void:
	# TODO: 实现帮助界面
	print("帮助按钮被点击 - 功能待实现")

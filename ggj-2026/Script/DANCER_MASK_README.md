# 舞者面具功能使用说明

## 概述
舞者面具是一个节奏判定系统，玩家需要在指针移动到节奏点（圆圈）内时点击鼠标来触发判定。

## 文件结构
- `dancer_mask.gd` - 主控制器，提供调用接口
- `dancer_mask_ui.gd` - UI控制器，处理界面显示和输入
- `dancer_mask_ui.tscn` - UI场景文件
- `dancer_mask_example.gd` - 使用示例

## 快速开始

### 方法1：最简单的方式（推荐）

```gdscript
# 在任何脚本中
func use_dancer_mask() -> void:
    var DancerMask = load("res://Script/dancer_mask.gd")
    DancerMask.quick_start(4, func(result): _on_rhythm_completed(result))

func _on_rhythm_completed(result: Dictionary) -> void:
    if result.get("success"):
        print("成功！得分: ", result.get("score"), "%")
    else:
        print("失败")
```

### 方法2：创建实例并管理

```gdscript
var dancer_mask: Node = null

func use_dancer_mask() -> void:
    # 创建实例
    dancer_mask = load("res://Script/dancer_mask.gd").new()
    get_tree().root.add_child(dancer_mask)
    
    # 连接信号
    dancer_mask.rhythm_completed.connect(_on_rhythm_completed)
    
    # 开始游戏
    # 参数：节奏点数量, 指针速度(像素/秒), 判定容差(像素)
    dancer_mask.start_rhythm_game(4, 200.0, 30.0)

func _on_rhythm_completed(result: Dictionary) -> void:
    print("结果: ", result)
    # 清理
    dancer_mask = null
```

### 方法3：在场景中添加节点

1. 在 `GameWorld.tscn` 中添加一个 `Node` 节点
2. 将脚本设置为 `res://Script/dancer_mask.gd`
3. 在代码中调用：

```gdscript
@onready var dancer_mask = $DancerMask

func use_dancer_mask() -> void:
    dancer_mask.start_rhythm_game(4, 200.0, 30.0)
    dancer_mask.rhythm_completed.connect(_on_rhythm_completed)
```

## API 说明

### `start_rhythm_game(beat_count, speed, tolerance)`
开始节奏游戏

**参数：**
- `beat_count` (int): 节奏点数量，默认 4
- `speed` (float): 指针移动速度（像素/秒），默认 200.0
- `tolerance` (float): 判定容差范围（像素），默认 30.0

### `stop_rhythm_game()`
停止当前正在运行的节奏游戏

### `is_active() -> bool`
检查是否正在运行节奏游戏

### 信号：`rhythm_completed(result: Dictionary)`
节奏游戏完成时触发

**result 字典包含：**
- `success` (bool): 是否成功完成所有节奏点
- `hit_count` (int): 击中的节奏点数量
- `total_beats` (int): 总节奏点数量
- `score` (float): 得分百分比 (0-100)

## 返回值示例

```gdscript
{
    "success": true,
    "hit_count": 4,
    "total_beats": 4,
    "score": 100.0
}
```

## 游戏机制

1. 游戏开始后，屏幕上会显示一个水平滑动条
2. 滑动条上有均匀分布的紫色圆圈（节奏点）
3. 红色指针从左侧开始向右移动
4. 当指针进入圆圈范围内时，点击鼠标左键或右键进行判定
5. 成功击中的圆圈会变成绿色
6. 需要击中所有节奏点才能成功

## 自定义参数

你可以根据需要调整参数：

```gdscript
# 更多节奏点，更慢的速度，更宽松的判定
dancer_mask.start_rhythm_game(6, 150.0, 40.0)

# 更少节奏点，更快的速度，更严格的判定
dancer_mask.start_rhythm_game(3, 250.0, 20.0)
```

## 注意事项

1. 同时只能运行一个节奏游戏实例
2. 如果游戏未完成，指针移动到末尾会自动判定为失败
3. UI会自动处理输入，不需要额外的输入处理
4. 游戏完成后会自动清理UI，无需手动管理

## 集成建议

建议在你的角色或面具系统中这样调用：

```gdscript
# 在 character.gd 或类似的脚本中
func use_dancer_mask_ability() -> void:
    var DancerMask = load("res://Script/dancer_mask.gd")
    DancerMask.quick_start(4, func(result): 
        if result.get("success"):
            # 激活舞者面具能力
            activate_dancer_mask_power()
        else:
            # 能力使用失败
            print("舞者面具能力激活失败")
    )
```


class_name ItemDef
extends Resource
## 器物定义（图鉴 / 订单共用）。S2 之后可由 data/catalog.json 批量生成 .tres。

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var task: String = ""
@export_multiline var hint: String = ""
@export var customer: String = ""
@export var species: String = ""
@export_range(1, 5) var rarity: int = 1
@export var silhouette: Texture2D
@export var thumbnail: Texture2D
@export var codex_order: int = 0

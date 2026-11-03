class_name ItemData
extends Resource
## One item definition. Create these as .tres files in the editor
## (right-click FileSystem > New Resource > ItemData) or in code.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: StringName = &""
@export var display_name: String = "New Item"
@export_multiline var description: String = ""
@export var category: String = "Misc"
@export var rarity: Rarity = Rarity.COMMON
@export_range(1, 9999) var max_stack: int = 1
@export var weight: float = 1.0
@export var value: int = 0
## If true, "Use" removes one from the stack.
@export var consumable: bool = false

@export_group("3D Model")
## Your own model (.glb / .tscn). Takes priority over `mesh`.
@export var model_scene: PackedScene
## Quick option: any Mesh (BoxMesh, a mesh from an imported file...).
@export var mesh: Mesh
@export var color: Color = Color(0.8, 0.8, 0.8)
@export_range(0.0, 1.0) var metallic: float = 0.0
@export_range(0.0, 1.0) var roughness: float = 0.6
@export var emission_energy: float = 0.0
## 1.0 = fits the slot. Bigger/smaller to taste.
@export_range(0.2, 3.0) var preview_scale: float = 1.0


static func rarity_color(r: int) -> Color:
	match r:
		Rarity.UNCOMMON: return Color("5fd068")
		Rarity.RARE: return Color("4aa3ff")
		Rarity.EPIC: return Color("b76cff")
		Rarity.LEGENDARY: return Color("ffaa33")
	return Color("b8c0cc")


static func rarity_name(r: int) -> String:
	return String(Rarity.keys()[clampi(r, 0, Rarity.size() - 1)]).capitalize()

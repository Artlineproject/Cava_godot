extends Area2D
# Script pour les symboles
@export var symbol_id = "symbole_circle_1"  # Format: symbole_TYPE_NUMÉRO
@export var visible_only_with_light = true
@export var fade_speed = 2.0
@export var visibility_threshold = 0.7
@export var hint_pulse = false

var is_discovered = false
var target_alpha = 0.0
var pulse_time = 0.0

signal symbol_discovered(symbol_id)

func _ready():
	add_to_group("symbols")
	
	var sprite = $Sprite2D
	sprite.light_mask = 1
	
	if visible_only_with_light:
		sprite.modulate.a = 0

func _process(delta):
	if visible_only_with_light:
		var current_alpha = $Sprite2D.modulate.a
		
		if current_alpha < target_alpha:
			$Sprite2D.modulate.a = min(current_alpha + fade_speed * delta, target_alpha)
		elif current_alpha > target_alpha:
			$Sprite2D.modulate.a = max(current_alpha - fade_speed * delta, target_alpha)
	
	if hint_pulse and target_alpha > 0 and target_alpha < visibility_threshold:
		pulse_time += delta
		var pulse = sin(pulse_time * 5) * 0.1 + 0.9
		$Sprite2D.scale = Vector2(pulse, pulse)

func reveal_by_light(intensity):
	if visible_only_with_light:
		target_alpha = clamp(intensity, 0, 1)
		
		if target_alpha > visibility_threshold and not is_discovered:
			is_discovered = true
			SymbolManager.discover_symbol(symbol_id)
			emit_signal("symbol_discovered", symbol_id)
			
			if has_node("DiscoverySound"):
				$DiscoverySound.play()
			
			return true
	
	return false

func is_fully_visible():
	return $Sprite2D.modulate.a > visibility_threshold

func get_symbol_id():
	return symbol_id

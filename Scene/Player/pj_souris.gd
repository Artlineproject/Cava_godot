extends Node2D

@export var light_intensity = 0.8
@export var light_radius = 200

# Signal émis quand un symbole est révélé
signal symbol_revealed(symbol_id)	

func _ready():
	# Assurez-vous que le PJ souris est visible au démarrage
	visible = true
	
	# Ajouter ou configurer un PointLight2D
	var light = get_node_or_null("PointLight2D")
	if not light:
		light = PointLight2D.new()
		light.texture = preload("res://Scene/Player/Assets/PlayerPointLight.png")  # Ajustez le chemin
		add_child(light)
	
	# Configurer la lumière
	light.enabled = true
	light.energy = 0.7  # Intensité modérée
	light.texture_scale = light_radius / 128.0  # Adapter au rayon de détection
	light.range_item_cull_mask = 1


func _process(delta):
	# Suivre la position de la souris
	global_position = get_global_mouse_position()
	
	# Vérifier les symboles sous la lumière
	check_symbols_under_light()

func check_symbols_under_light():
	var symbols = get_tree().get_nodes_in_group("symbols")
	
	for symbol in symbols:
		# Calculer la distance entre le symbole et la lumière
		var distance = global_position.distance_to(symbol.global_position)
		
		# Calculer l'intensité de la lumière sur le symbole
		var intensity = 0
		if distance < light_radius:
			intensity = 1.0 - (distance / light_radius)
			
		# Appliquer l'effet de révélation
		if symbol.has_method("reveal_by_light"):
			symbol.reveal_by_light(intensity * light_intensity)

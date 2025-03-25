extends Node2D
@export var light_intensity = 0.8
@export var light_radius = 200
# Signal émis quand un symbole est révélé
signal symbol_revealed(symbol_id)

# État pour l'animation
var over_code_panel = false

func _ready():
	# Assurez-vous que le PJ souris est visible au démarrage
	visible = true
	
	# Ajouter ou configurer un PointLight2D
	var light = get_node_or_null("PointLight2D")
	if not light:
		light = PointLight2D.new()
		light.texture = preload("res://Scene/Player/Assets/Halo_PJ_souris.png")  # Ajustez le chemin
		add_child(light)
	
	# Configurer la lumière
	light.enabled = true
	light.energy = 0.1  # Intensité modérée
	light.texture_scale = light_radius / 128.0  # Adapter au rayon de détection
	light.range_item_cull_mask = 1
	
	# Initialiser l'AnimatedSprite2D si présent
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default")
	
	# Ajouter au groupe pour interaction avec les plaques de code
	add_to_group("player_mouse")

func _process(delta):
	# Suivre la position de la souris
	global_position = get_global_mouse_position()
	
	# Vérifier les symboles sous la lumière
	check_symbols_under_light()
	
	# Vérifier si on est sur un panneau de code (pour l'animation du PJ souris)
	check_if_over_code_panel()

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
			var revealed = symbol.reveal_by_light(intensity * light_intensity)
			if revealed:
				emit_signal("symbol_revealed", symbol.get_symbol_id())

# Fonction pour vérifier si on est sur un panneau de code (n'importe quelle partie)
func check_if_over_code_panel():
	var was_over_panel = over_code_panel
	over_code_panel = false
	
	# Vérifier tous les code panels
	var code_panels = get_tree().get_nodes_in_group("code_panels")
	for panel in code_panels:
		# Méthode 1: Vérifier si on est proche de n'importe quel slot
		if panel.has_method("is_mouse_over_any_slot"):
			if panel.is_mouse_over_any_slot(global_position):
				over_code_panel = true
				break
		
		# Méthode 2 (alternative): Vérifier si on est dans une zone générale autour du panneau
		# Si la méthode 1 ne fonctionne pas, décommentez cette partie et ajustez les valeurs
		
		#var panel_position = panel.global_position
		#var panel_size = Vector2(200, 100)  # Estimation - ajuster selon la taille réelle de votre panneau
		
		# Vérifier si le curseur est dans une zone rectangulaire entourant le panneau
		#if (global_position.x > panel_position.x - panel_size.x/2 and 
		#    global_position.x < panel_position.x + panel_size.x/2 and
		#    global_position.y > panel_position.y - panel_size.y/2 and
		#    global_position.y < panel_position.y + panel_size.y/2):
		#    over_code_panel = true
		#    break
	
	# Changer l'animation en conséquence
	if over_code_panel != was_over_panel and has_node("AnimatedSprite2D"):
		if over_code_panel:
			$AnimatedSprite2D.play("hover")
		else:
			$AnimatedSprite2D.play("default")

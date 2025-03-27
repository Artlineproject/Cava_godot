extends Node2D
# Script principal du niveau

@onready var background = $Backgrounds/Background
@onready var canvas = $Backgrounds/CanvasModulate
@onready var tilemap = $Tilemaps/TileMap
# Références aux nœuds
@onready var doors = get_tree().get_nodes_in_group("doors")
@onready var player_keyboard = $Players/Player # Le personnage contrôlé au clavier
@onready var player_mouse = $Players/PjSouris  # Le personnage contrôlé à la souris
@onready var code_panels = get_tree().get_nodes_in_group("PanelCode")

func _ready():
	
	# Configuration de l'éclairage
	setup_light_masks()
	
	# Configuration des portes
	setup_doors()
	
	# Configuration des panneaux de code
	setup_code_panels()
	
	# Connecter les signaux
	connect_signals()

# Configuration de l'éclairage
func setup_light_masks():
	# Configuration globale pour le CanvasModulate
	if canvas:
		canvas.color = Color(0.15, 0.15, 0.17)  # Très sombre
	
	# Pour tous les éléments qui doivent être affectés par la lumière
	var nodes_to_light = []
	
	if tilemap:
		nodes_to_light.append(tilemap)
	
	if background:
		nodes_to_light.append(background)
	
	# Pour tous les sprites de portes
	for door in doors:
		if door.has_node("DoorSprite"):
			nodes_to_light.append(door.get_node("DoorSprite"))
	
	# Appliquer le mask de lumière à tous les nœuds
	for node in nodes_to_light:
		node.light_mask = 1
	
	# Configuration des lumières des joueurs
	setup_player_lights()

func setup_player_lights():
	
	# Configuration de la lumière du joueur clavier
	if player_keyboard:
		# Vérifier si le PointLight2D existe déjà
		var light = player_keyboard.get_node_or_null("PointLight2D")
		
		# Si non, créer un nouveau
		if not light:
			light = PointLight2D.new()
			light.texture = preload("res://Scene/Player/Assets/Halo_PJ_clavier.png")  # Ajustez le chemin
			player_keyboard.add_child(light)
		
		# Configurer la lumière
		light.enabled = true
		light.energy = 1  # Intensité modérée
		light.texture_scale = 1  # Rayon modéré
		light.range_item_cull_mask = 1

func configure_point_light(light):
	if light:
		# Paramètres essentiels pour PointLight2D
		light.enabled = true
		light.energy = 0.6  # Réduit de 1.0 à 0.6 pour moins d'intensité
		light.range_item_cull_mask = 1
		
		# Ajustement du rayon de la lumière
		light.texture_scale = 0.8  # Réduit de 1.0 à 0.8 pour une portée plus courte
		
		# Paramètres des ombres
		light.shadow_enabled = true
		light.shadow_filter = 1
		light.shadow_filter_smooth = 5.0
		
		# Atténuation plus progressive (si votre version de Godot supporte ces propriétés)
		if "shadow_item_cull_mask" in light:
			light.shadow_item_cull_mask = 1

# Configuration des portes
func setup_doors():
	for door in doors:
		# S'assurer que chaque porte a un ID unique
		if door.door_id == "":
			door.door_id = "door_" + door.name.to_lower()
		
		# Connecter les signaux des portes
		door.door_opened.connect(_on_door_opened.bind(door))
		door.teleport_completed.connect(_on_teleport_completed.bind(door))

# Configuration des panneaux de code
func setup_code_panels():
	print("Configuration des panneaux de code...")
	for panel in code_panels:
		# Connecter les signaux
		if !panel.is_connected("code_correct", _on_code_correct):
			panel.code_correct.connect(_on_code_correct.bind(panel))
			print("Signal code_correct connecté pour " + panel.name)
		
		if !panel.is_connected("code_incorrect", _on_code_incorrect):
			panel.code_incorrect.connect(_on_code_incorrect.bind(panel))
			print("Signal code_incorrect connecté pour " + panel.name)
		
		# Associer chaque panneau à une porte
		if panel.has_meta("associated_door"):
			var door_name = panel.get_meta("associated_door")
			print("Panneau " + panel.name + " associé à la porte " + door_name)
			
			for door in doors:
				if door.name == door_name:
					print("Porte trouvée: " + door.name + " avec ID: " + door.door_id)
					# Définir le code du panneau pour qu'il corresponde à la porte
					var door_code = SymbolManager.get_current_door_code()
					if door_code.size() > 0:
						panel.set_combination(door_code)
						print("Code défini pour le panneau: " + str(door_code))

# Connecter les signaux globaux
func connect_signals():
	# Connecter les signaux du SymbolManager
	SymbolManager.symbol_discovered.connect(_on_symbol_discovered)
	SymbolManager.all_symbols_discovered.connect(_on_all_symbols_discovered)

# Callback quand une porte est ouverte
func _on_door_opened(door):
	print("Porte ouverte: " + door.name)
	
	# Effets visuels ou sonores
	# $DoorOpenSound.play()

# Callback quand un téléport est complété
func _on_teleport_completed(door):
	print("Téléportation terminée vers: " + door.name)
	
	# Mettre à jour la porte active
	SymbolManager.set_current_door(door.door_id)

# Callback quand un code est correct
func _on_code_correct(panel):
	print("Signal code_correct reçu du panneau: " + panel.name)
	
	# Trouver la porte associée
	if panel.has_meta("associated_door"):
		var door_name = panel.get_meta("associated_door")
		print("Recherche de la porte: " + door_name)
		
		var door_found = false
		for door in doors:
			print("Vérification de la porte: " + door.name)
			if door.name == door_name:
				door_found = true
				print("Porte trouvée! Tentative d'ouverture...")
				door.open()
				break
		
		if !door_found:
			print("ERREUR CRITIQUE: Porte " + door_name + " non trouvée!")
			print("Portes disponibles: " + str(doors))
	else:
		print("ERREUR: Le panneau n'a pas de métadonnée 'associated_door'")

# Callback quand un code est incorrect
func _on_code_incorrect(panel):
	print("Code incorrect entré sur le panneau: " + panel.name)
	
	# Feedback visuel ou sonore
	# $WrongCodeSound.play()

# Callback quand un symbole est découvert
func _on_symbol_discovered(symbol_id):
	print("Symbole découvert: " + symbol_id)
	
	# Feedback visuel ou sonore
	# $SymbolDiscoveredSound.play()

# Callback quand tous les symboles sont découverts
func _on_all_symbols_discovered():
	print("Tous les symboles nécessaires ont été découverts!")
	
	# Feedback visuel ou sonore qui guide vers le panneau de code
	# $AllSymbolsDiscoveredSound.play()

extends Node2D
# Panneau de code

@export var available_symbols = ["trait", "chapeau", "cercle_bas", "cercle_haut", "L", "T"]
@export var interactive_by_group = "player_mouse"
@export var associated_door_name = ""
@export var animation_name_hover = "hover"
@export var animation_name_default = "default"
@export var animation_name_success = "success" # Animation pour code correct (symboles uniquement)

# Variables pour la détection de survol
var hover_check_interval = 0.05
var last_hover_check_time = 0
var last_mouse_position = Vector2.ZERO
var hover_detection_radius = 70
var hovering_slot_index = -1

var current_slots = ["", "", ""]
var is_active = true

signal code_submitted(code)
signal code_correct
signal code_incorrect
signal slot_changed(slot_index, symbol)

@onready var slots = [$Slot1, $Slot2, $Slot3]
@onready var submit_button = $SubmitButton

func _ready():
	print("=== Initialisation du panneau de code ===")
	
	# Initialiser les slots
	for i in range(slots.size()):
		_initialize_slot(i)
	
	# Connecter le bouton de soumission
	submit_button.pressed.connect(_on_submit_pressed)
	
	# Connecter les slots
	for i in range(slots.size()):
		slots[i].input_event.connect(_on_slot_input.bind(i))
	
	# S'assurer que les symboles sont initialement cachés
	for i in range(slots.size()):
		_hide_all_symbols(i)
	
	# Ajouter au groupe code_panels
	add_to_group("code_panels")

func _process(delta):
	# Vérification de survol à intervalles réguliers
	last_hover_check_time += delta
	if last_hover_check_time >= hover_check_interval:
		last_hover_check_time = 0
		check_mouse_over_slots()

# Fonction pour vérifier quel slot est survolé
func check_mouse_over_slots():
	# Ne pas vérifier si le panneau est désactivé
	if not is_active:
		return
		
	# Récupérer la position du joueur souris
	var mouse_players = get_tree().get_nodes_in_group(interactive_by_group)
	if mouse_players.size() == 0:
		return
	
	var mouse_player = mouse_players[0]
	var mouse_pos = mouse_player.global_position
	
	# Ne vérifier que si la souris a bougé significativement
	if last_mouse_position.distance_to(mouse_pos) < 5:
		return
		
	last_mouse_position = mouse_pos
	
	# Déterminer le slot le plus proche dans le rayon de détection
	var closest_slot = -1
	var closest_distance = hover_detection_radius
	
	for i in range(slots.size()):
		var distance = mouse_pos.distance_to(slots[i].global_position)
		if distance < closest_distance:
			closest_slot = i
			closest_distance = distance
	
	# Si le slot survolé a changé
	if closest_slot != hovering_slot_index:
		# Désactiver l'effet de survol sur l'ancien slot
		if hovering_slot_index != -1:
			print("Fin du survol du slot " + str(hovering_slot_index + 1))
			_set_slot_hover_state(hovering_slot_index, false)
		
		# Activer l'effet de survol sur le nouveau slot
		hovering_slot_index = closest_slot
		if hovering_slot_index != -1:
			_set_slot_hover_state(hovering_slot_index, true)
			print("Survol du slot " + str(hovering_slot_index + 1) + " détecté")

# Forcer une animation spécifique sur un nœud
func _force_animation(sprite_node, anim_name):
	if sprite_node is AnimatedSprite2D:
		if sprite_node.sprite_frames and sprite_node.sprite_frames.has_animation(anim_name):
			sprite_node.stop()
			sprite_node.animation = anim_name
			sprite_node.frame = 0
			sprite_node.play()
			return true
	return false

# Fonction pour changer l'état de survol d'un slot
func _set_slot_hover_state(slot_index, is_hovering):
	var slot = slots[slot_index]
	var anim_name = animation_name_hover if is_hovering else animation_name_default
	
	print("Slot " + str(slot_index + 1) + ": " + ("Activation" if is_hovering else "Désactivation") + " animation " + anim_name)
	
	# 1. Animer le SlotSprite (la base)
	if slot.has_node("SlotSprite"):
		var success = _force_animation(slot.get_node("SlotSprite"), anim_name)
		if success:
			print("  - Animation " + anim_name + " lancée sur SlotSprite")
	
	# 2. Animer le symbole actuellement visible
	var current_symbol = current_slots[slot_index]
	if current_symbol != "":
		var symbol_node_name = "Symbol_" + current_symbol
		if slot.has_node(symbol_node_name):
			var symbol_node = slot.get_node(symbol_node_name)
			
			# Vérifier si le symbole est un AnimatedSprite2D
			if symbol_node is AnimatedSprite2D:
				var success = _force_animation(symbol_node, anim_name)
				if success:
					print("  - Animation " + anim_name + " lancée sur symbole " + current_symbol)
				else:
					print("  - Le symbole " + current_symbol + " n'a pas d'animation " + anim_name)
			else:
				print("  - Le symbole " + current_symbol + " n'est pas un AnimatedSprite2D")
	
	# Jouer un son de survol si disponible
	if is_hovering and slot.has_node("HoverSound"):
		slot.get_node("HoverSound").play()

# Fonction pour jouer l'animation de succès uniquement sur les symboles
func _play_success_animation():
	print("Animation de succès déclenchée sur les symboles")
	
	# Pour chaque slot, animer uniquement le symbole visible
	for i in range(slots.size()):
		var slot = slots[i]
		var current_symbol = current_slots[i]
		
		if current_symbol != "":
			var symbol_node_name = "Symbol_" + current_symbol
			if slot.has_node(symbol_node_name):
				var symbol_node = slot.get_node(symbol_node_name)
				
				if symbol_node is AnimatedSprite2D:
					var success = _force_animation(symbol_node, animation_name_success)
					if success:
						print("  - Animation " + animation_name_success + " lancée sur symbole " + current_symbol)
					else:
						print("  - Le symbole " + current_symbol + " n'a pas d'animation " + animation_name_success)

# Initialiser un slot
func _initialize_slot(slot_index):
	var slot = slots[slot_index]
	
	# Vérifier les nœuds de symbole
	for symbol in available_symbols:
		var symbol_node_name = "Symbol_" + symbol
		if not slot.has_node(symbol_node_name):
			print("ERREUR: Nœud " + symbol_node_name + " manquant dans le slot " + str(slot_index+1))
	
	# Réinitialiser la sélection
	current_slots[slot_index] = ""
	_hide_all_symbols(slot_index)

# Fonction pour cacher tous les symboles d'un slot
func _hide_all_symbols(slot_index):
	var slot = slots[slot_index]
	
	for symbol in available_symbols:
		var symbol_node_name = "Symbol_" + symbol
		if slot.has_node(symbol_node_name):
			slot.get_node(symbol_node_name).visible = false

# Fonction pour montrer uniquement le symbole sélectionné
func _show_selected_symbol(slot_index):
	var slot = slots[slot_index]
	var selected_symbol = current_slots[slot_index]
	
	# D'abord, cacher tous les symboles
	_hide_all_symbols(slot_index)
	
	# Puis, montrer uniquement le symbole sélectionné, s'il y en a un
	if selected_symbol != "":
		var symbol_node_name = "Symbol_" + selected_symbol
		if slot.has_node(symbol_node_name):
			var symbol_node = slot.get_node(symbol_node_name)
			symbol_node.visible = true
			
			# Si ce slot est actuellement survolé, jouer l'animation hover
			if slot_index == hovering_slot_index:
				if symbol_node is AnimatedSprite2D:
					_force_animation(symbol_node, animation_name_hover)
			else:
				if symbol_node is AnimatedSprite2D:
					_force_animation(symbol_node, animation_name_default)
		else:
			print("ERREUR: Symbole " + symbol_node_name + " introuvable dans le slot " + str(slot_index+1))

# Gérer l'input sur un slot
func _on_slot_input(viewport, event, shape_idx, slot_index):
	if not is_active or not event is InputEventMouseButton:
		return
	
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Vérifier si le clic vient du groupe interactif (PJ souris)
		var mouse_in_group = false
		for body in get_tree().get_nodes_in_group(interactive_by_group):
			if body.global_position.distance_to(slots[slot_index].global_position) < 50:
				mouse_in_group = true
				break
		
		if mouse_in_group:
			_cycle_symbol(slot_index)
			
			# Jouer un son de clic si disponible
			if slots[slot_index].has_node("ClickSound"):
				slots[slot_index].get_node("ClickSound").play()

# Fonction pour cycler entre les symboles
func _cycle_symbol(slot_index):
	var current_index = -1
	
	# Trouver l'index actuel du symbole
	if current_slots[slot_index] == "":
		current_index = -1
	else:
		current_index = available_symbols.find(current_slots[slot_index])
	
	# Passer au symbole suivant
	current_index = (current_index + 1) % available_symbols.size()
	current_slots[slot_index] = available_symbols[current_index]
	
	# Mettre à jour l'affichage
	_show_selected_symbol(slot_index)
	
	# Émettre le signal
	slot_changed.emit(slot_index, current_slots[slot_index])
	print("Slot " + str(slot_index+1) + " changé à: " + current_slots[slot_index])

# Fonction pour soumettre le code
func _on_submit_pressed():
	if not is_active:
		return
	
	# Vérifier si tous les slots sont remplis
	var all_filled = true
	for i in range(current_slots.size()):
		if current_slots[i] == "":
			all_filled = false
			break
	
	if all_filled:
		# Débogage de la vérification de code
		print("======= VÉRIFICATION DE CODE =======")
		print("Code entré: " + str(current_slots))
		print("Porte active: " + SymbolManager.current_door_id)
		print("Code attendu: " + str(SymbolManager.get_current_door_code()))
		
		# Soumettre le code
		code_submitted.emit(current_slots)
		
		# Vérifier le code via le gestionnaire de symboles
		var is_correct = SymbolManager.verify_code(current_slots)
		print("Résultat de la vérification: " + str(is_correct))
		
		# Émettre le signal approprié
		if is_correct:
			print("Code correct! Signal code_correct émis.")
			
			# Jouer l'animation de succès sur les symboles uniquement
			_play_success_animation()
			
			# Émettre le signal
			code_correct.emit()
			
			# Test direct de l'ouverture de porte
			if has_meta("associated_door"):
				var door_name = get_meta("associated_door")
				print("Tentative d'ouverture directe de la porte: " + door_name)
				
				var door = null
				for d in get_tree().get_nodes_in_group("doors"):
					if d.name == door_name:
						door = d
						break
				
				if door:
					print("Porte trouvée, ouverture directe...")
					door.open()
				else:
					print("ERREUR: Porte non trouvée dans le groupe 'doors'")
			else:
				print("ERREUR: Ce panneau n'a pas de métadonnée 'associated_door'")
			
			# Désactiver le panneau après un court délai pour voir l'animation
			await get_tree().create_timer(1.0).timeout
			is_active = false
		else:
			print("Code incorrect. Réinitialisation du panneau.")
			code_incorrect.emit()
			reset()
		
		print("==================================")

# Réinitialiser le panneau
func reset():
	for i in range(current_slots.size()):
		current_slots[i] = ""
		_hide_all_symbols(i)
		
		# Réinitialiser l'animation de la plaque
		if slots[i].has_node("SlotSprite"):
			var sprite = slots[i].get_node("SlotSprite")
			if sprite is AnimatedSprite2D:
				_force_animation(sprite, animation_name_default)

# Désactiver le panneau
func disable():
	is_active = false
	submit_button.disabled = true

# Définir manuellement une combinaison spécifique
func set_combination(symbols):
	if symbols.size() != slots.size():
		push_error("La combinaison doit avoir le même nombre de symboles que de slots")
		return
	
	# Vérifier que tous les symboles existent
	for symbol in symbols:
		if not available_symbols.has(symbol):
			push_error("Symbole inconnu: " + symbol)
			return
	
	# Définir la combinaison dans le système
	var door_id = SymbolManager.current_door_id
	SymbolManager.add_door_code(door_id, symbols.duplicate())
	print("Combinaison définie pour la porte " + door_id + ": " + str(symbols))

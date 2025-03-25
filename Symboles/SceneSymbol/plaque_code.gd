extends Node2D
# Panneau de code

@export var available_symbols = ["trait", "chapeau", "cercle_bas", "cercle_haut", "L", "T"]
@export var interactive_by_group = "player_mouse"
@export var associated_door_name = ""  # Nom de la porte associée
@export var animation_name_hover = "hover"  # Nom de l'animation hover (à personnaliser si différent)
@export var animation_name_default = "default"  # Nom de l'animation par défaut

# Variables pour la détection de survol améliorée
var last_hover_check_time = 0
var hover_check_interval = 0.05  # Vérifier toutes les 50ms
var last_mouse_position = Vector2.ZERO
var hover_detection_radius = 70  # Rayon de détection plus large

var current_slots = ["", "", ""]
var is_active = true
var hovering_slot_index = -1  # Stocke l'index du slot survolé (-1 = aucun)

signal code_submitted(code)
signal code_correct
signal code_incorrect
signal slot_changed(slot_index, symbol)

@onready var slots = [$Slot1, $Slot2, $Slot3]
@onready var submit_button = $SubmitButton

func _ready():
	# Initialiser les slots vides
	for i in range(slots.size()):
		_initialize_slot(i)
		
		# Afficher des informations de débogage pour chaque slot
		print("Configuration du slot " + str(i+1) + ":")
		if slots[i].has_node("SlotSprite"):
			var sprite = slots[i].get_node("SlotSprite")
			print("  - SlotSprite trouvé")
			
			if sprite is AnimatedSprite2D:
				print("  - C'est bien un AnimatedSprite2D")
				
				if sprite.sprite_frames:
					print("  - SpriteFrames trouvé")
					print("  - Animations disponibles: " + str(sprite.sprite_frames.get_animation_names()))
					
					if sprite.sprite_frames.has_animation(animation_name_default):
						print("  - Animation '" + animation_name_default + "' trouvée")
						sprite.play(animation_name_default)
					else:
						print("  - ERREUR: Animation '" + animation_name_default + "' non trouvée")
				else:
					print("  - ERREUR: Pas de SpriteFrames configuré")
			else:
				print("  - ERREUR: SlotSprite n'est pas un AnimatedSprite2D")
		else:
			print("  - ERREUR: Nœud SlotSprite non trouvé")
	
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
	# N'exécuter la vérification de survol qu'à intervalles définis
	last_hover_check_time += delta
	if last_hover_check_time >= hover_check_interval:
		last_hover_check_time = 0
		check_mouse_over_slots()

# Fonction améliorée pour vérifier quel slot est survolé
func check_mouse_over_slots():
	# Récupérer la position du PJ souris
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
			_set_slot_hover_state(hovering_slot_index, false)
		
		# Activer l'effet de survol sur le nouveau slot
		hovering_slot_index = closest_slot
		if hovering_slot_index != -1:
			_set_slot_hover_state(hovering_slot_index, true)
			print("Survol du slot " + str(hovering_slot_index + 1) + " détecté")

# Fonction améliorée pour changer l'état de survol d'un slot
func _set_slot_hover_state(slot_index, is_hovering):
	var slot = slots[slot_index]
	
	# Vérifier si le slot a un nœud SlotSprite
	if slot.has_node("SlotSprite"):
		var sprite = slot.get_node("SlotSprite")
		
		# Vérifier si c'est un AnimatedSprite2D
		if sprite is AnimatedSprite2D:
			# Éviter de jouer l'animation si elle est déjà en cours
			var current_anim = sprite.animation
			var target_anim = animation_name_hover if is_hovering else animation_name_default
			
			if current_anim != target_anim:
				# Vérifier si le sprite a des frames
				if sprite.sprite_frames:
					# Vérifier si les animations existent
					var has_target_anim = sprite.sprite_frames.has_animation(target_anim)
					
					if has_target_anim:
						sprite.play(target_anim)
						print("Slot " + str(slot_index+1) + ": " + 
							("Activation" if is_hovering else "Désactivation") + 
							" animation " + target_anim)
					else:
						# Animations non disponibles, utiliser modulation
						slot.modulate = Color(1.2, 1.2, 1.2) if is_hovering else Color(1.0, 1.0, 1.0)
				else:
					# Pas de sprite frames, utiliser modulation
					slot.modulate = Color(1.2, 1.2, 1.2) if is_hovering else Color(1.0, 1.0, 1.0)
		else:
			# Pas un AnimatedSprite2D, utiliser modulation
			slot.modulate = Color(1.2, 1.2, 1.2) if is_hovering else Color(1.0, 1.0, 1.0)
	else:
		# Pas de SlotSprite, utiliser modulation sur le slot entier
		slot.modulate = Color(1.2, 1.2, 1.2) if is_hovering else Color(1.0, 1.0, 1.0)
	
	# Jouer un son de survol si disponible et si on entre dans l'état hover
	if is_hovering and slot.has_node("HoverSound"):
		slot.get_node("HoverSound").play()

# Fonction pour vérifier si la souris est au-dessus de n'importe quel slot
func is_mouse_over_any_slot(mouse_position):
	for slot in slots:
		if mouse_position.distance_to(slot.global_position) < 50:
			return true
	return false

# Fonction pour récupérer le slot survolé
func get_hovering_slot_index():
	return hovering_slot_index

# Initialiser un slot
func _initialize_slot(slot_index):
	# Vérifier que les nœuds de symbole existent
	var slot = slots[slot_index]
	
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
			slot.get_node(symbol_node_name).visible = true
		else:
			print("ERREUR: Symbole " + symbol_node_name + " introuvable dans le slot " + str(slot_index+1))

# Version alternative avec transition (optionnelle)
func _show_selected_symbol_with_transition(slot_index):
	var slot = slots[slot_index]
	var selected_symbol = current_slots[slot_index]
	
	# Fade out tous les symboles
	for symbol in available_symbols:
		var symbol_node_name = "Symbol_" + symbol
		if slot.has_node(symbol_node_name):
			var symbol_node = slot.get_node(symbol_node_name)
			if symbol_node.visible:
				# Créer un tween pour le fade out
				var tween = create_tween()
				tween.tween_property(symbol_node, "modulate:a", 0.0, 0.1)
				tween.tween_callback(func(): symbol_node.visible = false)
	
	# Montrer et fade in le symbole sélectionné
	if selected_symbol != "":
		var symbol_node_name = "Symbol_" + selected_symbol
		if slot.has_node(symbol_node_name):
			var symbol_node = slot.get_node(symbol_node_name)
			symbol_node.visible = true
			symbol_node.modulate.a = 0.0
			
			# Créer un tween pour le fade in
			var tween = create_tween()
			tween.tween_property(symbol_node, "modulate:a", 1.0, 0.1)

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
	# Si vous préférez la version avec transition, utilisez:
	# _show_selected_symbol_with_transition(slot_index)
	
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

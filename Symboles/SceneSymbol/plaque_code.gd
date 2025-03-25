extends Node2D
# Panneau de code

@export var available_symbols = ["circle", "triangle", "square"]
@export var interactive_by_group = "player_mouse"
@export var associated_door_name = ""  # Nom de la porte associée
@export var circle_symbol_scene: PackedScene
@export var triangle_symbol_scene: PackedScene
@export var square_symbol_scene: PackedScene
@export var animation_name_hover = "hover"  # Nom de l'animation hover (à personnaliser si différent)
@export var animation_name_default = "default"  # Nom de l'animation par défaut

var current_slots = ["", "", ""]
var is_active = true
var current_symbol_instances = [null, null, null]
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
		_clear_slot(i)
		
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
	
	# Ajouter au groupe code_panels
	add_to_group("code_panels")

func _process(delta):
	# Vérifier si la souris est au-dessus d'un slot
	check_mouse_over_slots()

# Fonction pour vérifier quel slot est survolé
func check_mouse_over_slots():
	var old_hovering_slot = hovering_slot_index
	hovering_slot_index = -1
	
	# Récupérer la position de tous les joueurs souris
	var mouse_players = get_tree().get_nodes_in_group(interactive_by_group)
	for player in mouse_players:
		var mouse_pos = player.global_position
		
		# Vérifier chaque slot
		for i in range(slots.size()):
			var distance = mouse_pos.distance_to(slots[i].global_position)
			if distance < 50:  # Ajuster ce rayon selon vos besoins
				hovering_slot_index = i
				break
		
		if hovering_slot_index != -1:
			break  # On a trouvé un slot survolé, inutile de continuer
	
	# Si le slot survolé a changé
	if old_hovering_slot != hovering_slot_index:
		# Désactiver l'effet de survol sur l'ancien slot
		if old_hovering_slot != -1:
			_set_slot_hover_state(old_hovering_slot, false)
		
		# Activer l'effet de survol sur le nouveau slot
		if hovering_slot_index != -1:
			_set_slot_hover_state(hovering_slot_index, true)

# Fonction pour changer l'état de survol d'un slot
func _set_slot_hover_state(slot_index, is_hovering):
	var slot = slots[slot_index]
	
	# Vérifier si le slot a un nœud SlotSprite
	if slot.has_node("SlotSprite"):
		var sprite = slot.get_node("SlotSprite")
		
		# Vérifier si c'est un AnimatedSprite2D
		if sprite is AnimatedSprite2D:
			# Vérifier si le sprite a des frames
			if sprite.sprite_frames:
				# Vérifier si les animations existent
				var has_hover = sprite.sprite_frames.has_animation(animation_name_hover)
				var has_default = sprite.sprite_frames.has_animation(animation_name_default)
				
				if is_hovering and has_hover:
					# Cas 1: État hover et animation hover disponible
					sprite.play(animation_name_hover)
					
					# En mode debug, affichez un message la première fois
					if sprite.animation != animation_name_hover:
						print("Slot " + str(slot_index+1) + ": Activation animation hover")
				elif has_default:
					# Cas 2: État normal et animation default disponible
					sprite.play(animation_name_default)
					
					# En mode debug, affichez un message la première fois
					if sprite.animation != animation_name_default:
						print("Slot " + str(slot_index+1) + ": Activation animation default")
				else:
					# Cas 3: Animations non disponibles, utiliser modulation
					print("Animations manquantes pour slot " + str(slot_index+1) + ", utilisation de modulate")
					slot.modulate = Color(1.2, 1.2, 1.2) if is_hovering else Color(1.0, 1.0, 1.0)
			else:
				# Cas 4: Pas de sprite frames, utiliser modulation
				slot.modulate = Color(1.2, 1.2, 1.2) if is_hovering else Color(1.0, 1.0, 1.0)
		else:
			# Cas 5: Pas un AnimatedSprite2D, utiliser modulation
			slot.modulate = Color(1.2, 1.2, 1.2) if is_hovering else Color(1.0, 1.0, 1.0)
	else:
		# Cas 6: Pas de SlotSprite, utiliser modulation sur le slot entier
		slot.modulate = Color(1.2, 1.2, 1.2) if is_hovering else Color(1.0, 1.0, 1.0)
	
	# Jouer un son de survol si disponible
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

# Le reste du code reste inchangé
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
	_update_slot_visual(slot_index)
	
	# Émettre le signal
	slot_changed.emit(slot_index, current_slots[slot_index])

func _update_slot_visual(slot_index):
	# D'abord, supprimer l'ancien symbole s'il existe
	_clear_slot(slot_index)
	
	var symbol_name = current_slots[slot_index]
	var symbol_scene = null
	
	# Sélectionner la scène appropriée
	match symbol_name:
		"circle":
			symbol_scene = circle_symbol_scene
		"triangle":
			symbol_scene = triangle_symbol_scene
		"square":
			symbol_scene = square_symbol_scene
	
	if symbol_name != "" and symbol_scene:
		# Instancier la scène du symbole
		var symbol_instance = symbol_scene.instantiate()
		slots[slot_index].add_child(symbol_instance)
		
		# Positionner le symbole au centre du slot
		symbol_instance.position = Vector2.ZERO
		
		# S'assurer que le symbole est visible (z-index élevé)
		symbol_instance.z_index = 10
		
		# Stocker l'instance pour pouvoir la supprimer plus tard
		current_symbol_instances[slot_index] = symbol_instance

func _clear_slot(slot_index):
	# Supprimer l'ancien symbole s'il existe
	if current_symbol_instances[slot_index]:
		current_symbol_instances[slot_index].queue_free()
		current_symbol_instances[slot_index] = null

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
		_clear_slot(i)

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

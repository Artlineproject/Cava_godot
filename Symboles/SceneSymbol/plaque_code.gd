extends Node2D
# Panneau de code

@export var available_symbols = ["circle", "triangle", "square"]
@export var interactive_by_group = "player_mouse"
@export var associated_door_name = ""  # Nom de la porte associée
@export var circle_symbol_scene: PackedScene
@export var triangle_symbol_scene: PackedScene
@export var square_symbol_scene: PackedScene

var current_slots = ["", "", ""]
var is_active = true
var current_symbol_instances = [null, null, null]

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
	
	# Connecter le bouton de soumission
	submit_button.pressed.connect(_on_submit_pressed)
	
	# Connecter les slots
	for i in range(slots.size()):
		slots[i].input_event.connect(_on_slot_input.bind(i))
	
	# Ajouter au groupe code_panels
	add_to_group("code_panels")

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

# Ajoutez cette fonction au script du panneau de code pour un meilleur diagnostic
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

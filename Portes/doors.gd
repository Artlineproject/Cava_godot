extends Node2D

# Porte avec téléportation et système de code
@export var door_id = "door_1_1"  # ID unique pour cette porte
@export var is_open = false  # On commence avec une porte fermée par défaut
@export var destination_door_path: NodePath  # Chemin vers la porte de destination
@export var player_group = "player"  # Assurez-vous que c'est le même groupe que votre joueur
@export var requires_code = true  # Si cette porte nécessite un code pour s'ouvrir

# Variables internes
var player_in_range = false
var destination_door = null
var teleporting = false
var player_controls_disabled = false  # Variable pour suivre l'état des contrôles du joueur

# Références aux nœuds
@onready var sprite = $DoorSprite
@onready var detection_area = $DetectionArea
@onready var spawn_point = $SpawnPoint

# Signaux
signal door_opened
signal door_closed
signal teleport_started
signal teleport_completed
signal controls_disabled_changed(disabled)  # Nouveau signal pour désactiver les contrôles du joueur

func _ready():
	# Ajouter cette porte au groupe "doors"
	add_to_group("doors")
	
	# Enregistrer cette porte dans le gestionnaire de symboles
	if door_id != "" and requires_code:
		# Si c'est la porte active au début du niveau
		if SymbolManager.current_door_id == door_id:
			SymbolManager.set_current_door(door_id)
		
		# Connecter le signal du gestionnaire de symboles
		SymbolManager.all_symbols_discovered.connect(_on_all_symbols_discovered)
	
	# Définir l'animation initiale
	if sprite:
		if is_open:
			sprite.play("idle_open")
		else:
			sprite.play("idle_closed")
	else:
		push_error("DoorSprite non trouvé dans la porte!")
	
	# Connecter aux signaux
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	else:
		push_error("DetectionArea non trouvée dans la porte!")
	
	# Obtenir la référence à la porte de destination
	if !destination_door_path.is_empty():
		destination_door = get_node(destination_door_path)
		print("Porte " + door_id + " liée à: ", destination_door_path)
	else:
		print("Attention: aucune porte de destination définie pour " + door_id + "!")

func _process(delta):
	# Vérifier si le joueur est dans la zone et appuie sur "ui_down" (S ou flèche bas)
	if player_in_range and not player_controls_disabled:
		if Input.is_action_just_pressed("ui_down"):  # "ui_down" est mappé à S et flèche bas par défaut
			print("Touche S détectée - tentative d'utilisation de la porte")
			if is_open:
				# Si la porte est ouverte, téléporter le joueur
				_teleport_player()
			elif requires_code and not SymbolManager.check_door_symbols(door_id):
				# Jouer l'animation shake seulement si la porte est fermée, 
				# qu'elle nécessite un code et que le code n'a pas été entré correctement
				_shake_door()
				print("La porte est verrouillée - code requis")

# Téléporter le joueur vers la porte de destination
func _teleport_player():
	if not destination_door:
		push_error("Porte de destination non définie!")
		return
	
	teleporting = true
	teleport_started.emit()
	print("Téléportation en cours...")
	
	# Récupérer le joueur
	var player = null
	for body in detection_area.get_overlapping_bodies():
		if body.is_in_group(player_group):
			player = body
			print("Joueur trouvé dans la zone de détection")
			break
	
	if player:
		# Désactiver les contrôles du joueur
		_set_player_controls_disabled(true)
		
		# Créer un effet de fondu au noir
		var transition_rect = ColorRect.new()
		transition_rect.color = Color(0, 0, 0, 0)
		transition_rect.size = get_viewport_rect().size
		transition_rect.global_position = Vector2.ZERO
		
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 100
		add_child(canvas_layer)
		canvas_layer.add_child(transition_rect)
		
		var tween = create_tween()
		tween.tween_property(transition_rect, "color:a", 1.0, 0.3)
		
		await tween.finished
		
		# Téléporter le joueur
		player.global_position = destination_door.spawn_point.global_position
		print("Joueur téléporté à la position:", destination_door.spawn_point.global_position)
		
		# Mettre à jour la porte active dans le gestionnaire de symboles
		if destination_door.door_id != "":
			SymbolManager.set_current_door(destination_door.door_id)
		
		# Animation d'ouverture de la porte de destination
		destination_door.sprite.play("open")
		
		# Fondu inverse
		tween = create_tween()
		tween.tween_property(transition_rect, "color:a", 0.0, 0.3)
		
		await tween.finished
		canvas_layer.queue_free()
		
		# Attendre que l'animation d'ouverture se termine
		await destination_door.sprite.animation_finished
		
		# Réinitialiser les animations aux états statiques
		sprite.play("idle_closed")
		destination_door.sprite.play("idle_open")
		
		# Réactiver les contrôles du joueur
		_set_player_controls_disabled(false)
		
		teleporting = false
		teleport_completed.emit()
	else:
		print("Aucun joueur trouvé dans la zone de détection!")
		teleporting = false

# Nouvelle fonction pour faire trembler la porte
func _shake_door():
	print("Fonction shake_door() appelée sur la porte " + door_id)
	
	if sprite:
		# Pour AnimatedSprite2D
		if sprite is AnimatedSprite2D:
			if sprite.sprite_frames.has_animation("shake"):
				print("Animation 'shake' trouvée, lecture...")
				
				# Désactiver les contrôles du joueur pendant l'animation
				_set_player_controls_disabled(true)
				
				sprite.play("shake")
				
				# Attendre la fin de l'animation
				await sprite.animation_finished
				
				print("Animation shake terminée, retour à idle_closed")
				sprite.play("idle_closed")
				
				# Réactiver les contrôles du joueur
				_set_player_controls_disabled(false)
			else:
				print("ERREUR: Animation 'shake' manquante!")
				print("Animations disponibles: " + str(sprite.sprite_frames.get_animation_names()))
		# Pour AnimationPlayer
		elif sprite is AnimationPlayer:
			if sprite.has_animation("shake"):
				print("Animation 'shake' trouvée, lecture...")
				
				# Désactiver les contrôles du joueur pendant l'animation
				_set_player_controls_disabled(true)
				
				sprite.play("shake")
				
				# Attendre la fin de l'animation
				await sprite.animation_finished
				
				print("Animation shake terminée, retour à idle_closed")
				sprite.play("idle_closed")
				
				# Réactiver les contrôles du joueur
				_set_player_controls_disabled(false)
			else:
				print("ERREUR: Animation 'shake' manquante!")
				print("Animations disponibles: " + str(sprite.get_animation_list()))
		else:
			print("ERREUR: Type de nœud sprite non pris en charge!")
	else:
		print("Le nœud sprite est null!")

# Quand le joueur entre dans la zone de détection
func _on_detection_area_body_entered(body):
	if body.is_in_group(player_group):
		player_in_range = true
		print("Joueur entré dans la zone de la porte " + door_id)

# Quand le joueur quitte la zone de détection
func _on_detection_area_body_exited(body):
	if body.is_in_group(player_group):
		player_in_range = false
		print("Joueur sorti de la zone de la porte " + door_id)

# Dans le script de porte
func open():
	print("Fonction open() appelée sur la porte " + door_id)
	
	if not is_open:
		print("La porte était fermée, ouverture...")
		is_open = true
		
		if sprite:
			# Pour AnimatedSprite2D
			if sprite is AnimatedSprite2D:
				if sprite.sprite_frames.has_animation("open"):
					print("Animation 'open' trouvée, lecture...")
					
					# Désactiver les contrôles du joueur pendant l'animation
					_set_player_controls_disabled(true)
					
					sprite.play("open")
					
					# Attendre la fin de l'animation
					await sprite.animation_finished
					
					print("Animation terminée, passage à idle_open")
					sprite.play("idle_open")
					
					# Réactiver les contrôles du joueur
					_set_player_controls_disabled(false)
				else:
					print("ERREUR: Animation 'open' manquante!")
					print("Animations disponibles: " + str(sprite.sprite_frames.get_animation_names()))
			# Pour AnimationPlayer
			elif sprite is AnimationPlayer:
				if sprite.has_animation("open"):
					print("Animation 'open' trouvée, lecture...")
					
					# Désactiver les contrôles du joueur pendant l'animation
					_set_player_controls_disabled(true)
					
					sprite.play("open")
					
					# Attendre la fin de l'animation
					await sprite.animation_finished
					
					print("Animation terminée, passage à idle_open")
					sprite.play("idle_open")
					
					# Réactiver les contrôles du joueur
					_set_player_controls_disabled(false)
				else:
					print("ERREUR: Animation 'open' manquante!")
					print("Animations disponibles: " + str(sprite.get_animation_list()))
			else:
				print("ERREUR: Type de nœud sprite non pris en charge!")
		else:
			print("Le nœud sprite est null!")
		
		door_opened.emit()
		print("Signal door_opened émis")
	else:
		print("La porte est déjà ouverte!")

# Fonction pour définir l'état des contrôles du joueur
func _set_player_controls_disabled(disabled):
	player_controls_disabled = disabled
	controls_disabled_changed.emit(disabled)
	print("Controls du joueur " + ("désactivés" if disabled else "activés"))

# Vérifier si une porte est déverrouillée (si son code a été entré correctement)
func is_unlocked():
	if not requires_code:
		return true
	return SymbolManager.check_door_symbols(door_id)

# Réaction lorsque tous les symboles sont découverts
func _on_all_symbols_discovered():
	# Ouvrir la porte seulement si c'est la porte active et qu'elle nécessite un code
	if requires_code and SymbolManager.current_door_id == door_id:
		open()
		print("Tous les symboles découverts pour la porte " + door_id + " - Ouverture automatique")

# Définir un code personnalisé pour cette porte
func set_code(symbols):
	SymbolManager.add_door_code(door_id, symbols)
	print("Code défini pour la porte " + door_id + ": " + str(symbols))

extends CharacterBody2D

class_name PlatformerController2D

@export var README: String = "Version minimaliste avec uniquement: idle, walk, jump et mouvements/gravité de base"

@export_category("Necessary Child Nodes")
@export var PlayerSprite: AnimatedSprite2D
@export var PlayerCollider: CollisionShape2D

# INFO SUR LE MOUVEMENT HORIZONTAL 
@export_category("L/R Movement")
## La vitesse maximale à laquelle le joueur peut se déplacer
@export_range(50, 500) var maxSpeed: float = 200.0
## Combien de temps (en secondes) le joueur met pour atteindre sa vitesse maximale depuis l'arrêt
@export_range(0.01, 4) var timeToReachMaxSpeed: float = 0.3
## Combien de temps (en secondes) le joueur met pour passer de la vitesse maximale à l'arrêt
@export_range(0.01, 4) var timeToReachZeroSpeed: float = 0.2
## Si activé, le joueur change de direction instantanément, mais conserve les valeurs d'accélération/décélération
@export var directionalSnap: bool = false

# INFO SUR LE SAUT 
@export_category("Jumping and Gravity")
## La hauteur maximale du saut du joueur
@export_range(0, 20) var jumpHeight: float = 2.0
## La force avec laquelle le personnage est attiré vers le sol
@export_range(0, 100) var gravityScale: float = 16.0
## La vitesse maximale à laquelle le joueur peut tomber
@export_range(0, 1000) var terminalVelocity: float = 400.0
## Le joueur descendra plus vite de ce facteur lorsqu'il tombe, pour une courbe de saut moins flottante
@export_range(0.5, 3) var descendingGravityFactor: float = 1.2
## Activer ceci fait que relâcher la touche de saut en montant réduit de moitié la vitesse verticale, permettant une hauteur de saut variable
@export var shortHopAkaVariableJumpHeight: bool = true
@export_range(0.01, 1.0) var groundFriction: float = 0.25  # Friction au sol
@export_range(0.01, 1.0) var airFriction: float = 0.05    # Friction en l'air

# PARAMÈTRES POUR LES PENTES
@export_category("Slope Handling")
## Angle maximum des pentes que le joueur peut monter (en degrés)
@export_range(0, 180) var maxSlopeAngle: float = 150.0
## Force d'assistance pour monter les pentes raides
@export_range(0, 100) var slopeAssistForce: float = 50.0
## Distance de snap au sol
@export_range(0, 50) var floorSnapLength: float = 32.0

@export_category("Animations (Check Box if has animation)")
## Les animations doivent être nommées "jump" en minuscules comme indiqué dans la case à cocher
@export var jump: bool
## Les animations doivent être nommées "idle" en minuscules comme indiqué dans la case à cocher
@export var idle: bool
## Les animations doivent être nommées "walk" en minuscules comme indiqué dans la case à cocher
@export var walk: bool

# Variables pour le contrôle du mouvement
var acceleration: float
var deceleration: float
var jumpMagnitude: float = 500.0
var appliedGravity: float
var appliedTerminalVelocity: float
var wasMovingR: bool = true
var maxSpeedLock: float
var gravityActive: bool = true

# Variables pour les animations
var anim
var col
var animScaleLock: Vector2

# Variables d'entrée
var upHold: bool = false
var downHold: bool = false
var leftHold: bool = false
var leftTap: bool = false
var leftRelease: bool = false
var rightHold: bool = false
var rightTap: bool = false
var rightRelease: bool = false
var jumpTap: bool = false
var jumpRelease: bool = false

# Variable pour savoir si le joueur est en train de sauter
var is_jumping: bool = false

func _ready():
	anim = PlayerSprite
	col = PlayerCollider
	_updateData()

func _updateData():
	# Calculer les valeurs dérivées des paramètres
	acceleration = maxSpeed / timeToReachMaxSpeed
	deceleration = -maxSpeed / timeToReachZeroSpeed
	
	jumpMagnitude = (10.0 * jumpHeight) * gravityScale
	
	maxSpeedLock = maxSpeed
	
	animScaleLock = abs(anim.scale)
	
	# Validation des valeurs pour éviter les divisions par zéro
	if timeToReachMaxSpeed <= 0:
		timeToReachMaxSpeed = 0.01
	if timeToReachZeroSpeed <= 0:
		timeToReachZeroSpeed = 0.01

# Fonction pour gérer les animations du joueur
func _handle_animations():
	# Gestion de la direction du sprite
	if rightHold:
		anim.scale.x = animScaleLock.x
	if leftHold:
		anim.scale.x = animScaleLock.x * -1
	
	# Animations simplifiées: seulement idle, walk et jump
	
	# Animation de saut
	if !is_on_floor() and jump:
		anim.play("jump")
		return
			
	# Animations au sol
	if is_on_floor():
		var moving_on_ground = abs(velocity.x) > 0.1
		
		if moving_on_ground and walk:
			anim.speed_scale = abs(velocity.x / 150)
			anim.play("walk")
		elif idle:
			anim.speed_scale = 1
			anim.play("idle")

func _process(_delta):
	# Vérifie que l'initialisation est faite correctement
	if anim != null and col != null:
		# Gérer les animations mais seulement une fois que tout est prêt
		_handle_animations()
	else:
		# Essayer de réinitialiser les variables si elles sont nulles
		anim = PlayerSprite
		col = PlayerCollider

func _physics_process(delta):
	# Lecture des entrées
	_read_inputs()
	
	# Gestion des mouvements horizontaux
	_handle_horizontal_movement(delta)
	
	# Gestion du saut et de la gravité
	_handle_jump_and_gravity(delta)
	
	# Gestion des pentes (séparée de la logique de saut)
	_handle_slopes(delta)
	
	# Déplacer le personnage (une seule fois par frame)
	move_and_slide()

# Lecture des entrées utilisateur
func _read_inputs():
	# Capturer toutes les entrées à chaque frame
	leftHold = Input.is_action_pressed("left")
	rightHold = Input.is_action_pressed("right")
	upHold = Input.is_action_pressed("up")
	downHold = Input.is_action_pressed("down")
	leftTap = Input.is_action_just_pressed("left")
	rightTap = Input.is_action_just_pressed("right")
	leftRelease = Input.is_action_just_released("left")
	rightRelease = Input.is_action_just_released("right")
	jumpTap = Input.is_action_just_pressed("jump")
	jumpRelease = Input.is_action_just_released("jump")

# Nouvelle fonction pour gérer les pentes
func _handle_slopes(delta):
	# Définir les paramètres avancés de pente
	floor_max_angle = deg_to_rad(maxSlopeAngle)
	floor_snap_length = floorSnapLength
	
	# Assistance pour monter les pentes raides, mais seulement si:
	# 1. Le joueur est au sol
	# 2. Le joueur n'est pas en train de sauter
	# 3. Le joueur est sur une pente raide
	# 4. Le joueur essaie de se déplacer horizontalement
	if is_on_floor() and not is_jumping and get_floor_normal().y > -0.9:
		if (leftHold or rightHold):
			# Assistance plus modérée pour monter la pente
			velocity.y -= slopeAssistForce * delta

# Gestion des mouvements horizontaux
func _handle_horizontal_movement(delta):
	# Appliquer une friction spécifique selon l'état
	if is_on_floor():
		# Friction plus forte au sol
		if abs(velocity.x) < 10:
			velocity.x = 0  # Arrêt complet à basse vitesse
		elif !leftHold && !rightHold:
			# Friction au sol quand aucune touche n'est pressée
			velocity.x = lerp(velocity.x, 0.0, groundFriction)
	else:
		# Légère friction en l'air
		if !leftHold && !rightHold:
			velocity.x = lerp(velocity.x, 0.0, airFriction)

	var target_speed = 0.0
	
	# Déterminer la vitesse cible en fonction des entrées
	if rightHold and leftHold:
		target_speed = 0.0
	elif rightHold:
		target_speed = maxSpeed
	elif leftHold:
		target_speed = -maxSpeed
	
	# Deux modes de déplacement distincts
	if directionalSnap:
		# Mode snap : change instantanément de direction, mais conserve l'accélération/décélération
		if target_speed != 0:
			# Direction change, but use acceleration for ramping up
			if sign(velocity.x) != sign(target_speed) and velocity.x != 0:
				velocity.x = 0  # Reset velocity when changing direction
			
			if abs(velocity.x) < abs(target_speed):
				velocity.x += sign(target_speed) * acceleration * delta
				velocity.x = clamp(velocity.x, -maxSpeed, maxSpeed)
			else:
				velocity.x = target_speed
		else:
			# Pour l'arrêt, utiliser la décélération normale
			if velocity.x > 0:
				velocity.x = max(0, velocity.x + deceleration * delta)
			elif velocity.x < 0:
				velocity.x = min(0, velocity.x - deceleration * delta)
	else:
		# Mode standard : accélération et décélération progressives
		if target_speed != 0:
			if abs(velocity.x) < abs(target_speed):
				# Accélération
				if target_speed > 0:
					velocity.x += acceleration * delta
				else:
					velocity.x -= acceleration * delta
				velocity.x = clamp(velocity.x, -maxSpeed, maxSpeed)
			
			# Changement de direction (décélération d'abord)
			if (target_speed > 0 and velocity.x < 0) or (target_speed < 0 and velocity.x > 0):
				if velocity.x > 0:
					velocity.x = max(0, velocity.x + deceleration * delta)
				else:
					velocity.x = min(0, velocity.x - deceleration * delta)
		else:
			# Aucune touche pressée - décélération
			if velocity.x > 0:
				velocity.x = max(0, velocity.x + deceleration * delta)
			elif velocity.x < 0:
				velocity.x = min(0, velocity.x - deceleration * delta)
	
	# Mettre à jour les variables de direction
	if velocity.x > 0:
		wasMovingR = true
	elif velocity.x < 0:
		wasMovingR = false
		
	# Arrêt complet à faible vitesse
	if abs(velocity.x) < 5:
		velocity.x = 0

# Gestion du saut et de la gravité
func _handle_jump_and_gravity(delta):
	# Réinitialiser l'état de saut si on touche le sol
	if is_on_floor():
		is_jumping = false
	
	# Ajuster la gravité en fonction de la montée/descente
	if velocity.y > 0:
		appliedGravity = gravityScale * descendingGravityFactor
	else:
		appliedGravity = gravityScale
	
	appliedTerminalVelocity = terminalVelocity
	
	# Appliquer la gravité
	if gravityActive:
		if velocity.y < appliedTerminalVelocity:
			velocity.y += appliedGravity * delta * 60  # Multiplié par 60 pour simuler la physique frame-indépendante
		elif velocity.y > appliedTerminalVelocity:
			velocity.y = appliedTerminalVelocity
	
	# Gestion du saut variable
	if shortHopAkaVariableJumpHeight and jumpRelease and velocity.y < 0:
		velocity.y = velocity.y / 2
	
	# Logique de saut
	if jumpTap and is_on_floor():
		_jump()

# Exécution du saut    
func _jump():
	velocity.y = -jumpMagnitude
	is_jumping = true
	
	# Préserver la vélocité horizontale au début du saut
	if leftHold:
		velocity.x = -maxSpeed
	elif rightHold:
		velocity.x = maxSpeed

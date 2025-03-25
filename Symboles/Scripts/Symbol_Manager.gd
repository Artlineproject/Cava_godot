extends Node
# Gestionnaire de symboles - autoload singleton

# Dictionnaire des codes de porte - Mis à jour avec les nouveaux symboles
var door_codes = {
	"door_1_1": ["trait", "chapeau", "cercle_bas"],
	"door_1_2": ["T", "cercle_haut", "L"],
	"door_1_3": ["cercle_bas", "trait", "chapeau"],
	"door_1_4": ["L", "T", "cercle_haut"]
}

# Liste des symboles découverts dans la zone actuelle
var discovered_symbols = []

# La porte active actuellement
var current_door_id = "door_1_1"

# Signal émis quand un symbole est découvert
signal symbol_discovered(symbol_id)
signal all_symbols_discovered

func _ready():
	# Initialiser la liste des symboles découverts
	reset_discovered_symbols()

# Réinitialiser la liste des symboles découverts
func reset_discovered_symbols():
	discovered_symbols = []

# Marquer un symbole comme découvert
func discover_symbol(symbol_id):
	if not discovered_symbols.has(symbol_id):
		discovered_symbols.append(symbol_id)
		emit_signal("symbol_discovered", symbol_id)
		
		# Vérifier si tous les symboles de la zone sont découverts
		check_all_symbols_discovered()
		return true
	return false

# Vérifier si tous les symboles nécessaires sont découverts
func check_all_symbols_discovered():
	if door_codes.has(current_door_id):
		var required_symbols = door_codes[current_door_id]
		var all_discovered = true
		
		for symbol in required_symbols:
			if not has_discovered_symbol_type(symbol):
				all_discovered = false
				break
		
		if all_discovered:
			emit_signal("all_symbols_discovered")
			return true
	
	return false

# Définir la porte active
func set_current_door(door_id):
	if door_id != current_door_id:
		current_door_id = door_id
		reset_discovered_symbols()
		print("Door ID set to: " + door_id)

# Obtenir le code de la porte active
func get_current_door_code():
	if door_codes.has(current_door_id):
		return door_codes[current_door_id]
	return []

# Extraire le type de symbole à partir de son ID complet
func get_symbol_type(symbol_id):
	# Format attendu: "symbole_trait_1", "symbole_chapeau_2", etc.
	var parts = symbol_id.split("_")
	if parts.size() >= 2:
		return parts[1]  # Retourne "trait", "chapeau", etc.
	return symbol_id

# Vérifier si un type spécifique de symbole a été découvert
func has_discovered_symbol_type(symbol_type):
	for discovered in discovered_symbols:
		if get_symbol_type(discovered) == symbol_type:
			return true
	return false

# Vérifier un code entré
func verify_code(entered_code):
	print("SymbolManager: Vérification du code")
	print("Code entré: " + str(entered_code))
	print("Porte active: " + current_door_id)
	
	var door_code = get_current_door_code()
	print("Code de la porte: " + str(door_code))
	
	if entered_code.size() != door_code.size():
		print("Tailles différentes: " + str(entered_code.size()) + " vs " + str(door_code.size()))
		return false
	
	for i in range(door_code.size()):
		if entered_code[i] != door_code[i]:
			print("Différence à l'index " + str(i) + ": " + entered_code[i] + " vs " + door_code[i])
			return false
	
	print("Les codes correspondent!")
	return true

# Ajouter un code personnalisé pour une porte
func add_door_code(door_id, symbols):
	door_codes[door_id] = symbols.duplicate()

# Pour le débogage - afficher le statut actuel
func debug_status():
	print("==== SYMBOL MANAGER STATUS ====")
	print("Current Door: " + current_door_id)
	print("Door Code: " + str(get_current_door_code()))
	print("Discovered Symbols: " + str(discovered_symbols))
	print("===========================")

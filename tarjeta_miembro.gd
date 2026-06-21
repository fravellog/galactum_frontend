extends PanelContainer

# 1. Cargamos el nuevo modal arriba del todo
var PerfilTripulanteEscena = preload("res://modal_perfil_tripulante.tscn")

@onready var label_nombre = $MarginContainer/VBoxContainer/HBoxContainer/Label
@onready var label_rango = $MarginContainer/VBoxContainer/HBoxContainer/Label2
@onready var label_stats = $MarginContainer/VBoxContainer/HBoxContainer2/Label
@onready var label_estado = $MarginContainer/VBoxContainer/Label

# 1. Nueva variable para "recordar" a este jugador
var datos_jugador : Dictionary = {}

func configurar_miembro(datos: Dictionary):
	# 2. Guardamos los datos apenas nos los entregan
	datos_jugador = datos 
	
	label_nombre.text = "👤 " + datos["nombre"]
	
	var icono_rango = "🔹 "
	if datos["rango"] == "Líder":
		icono_rango = "👑 "
	elif datos["rango"] == "Oficial":
		icono_rango = "⭐ "
		
	label_rango.text = icono_rango + datos["rango"]
	
	var poder = str(datos["poder"])
	var tropas = str(datos["tropas"])
	var bajas = str(datos["bajas"])
	label_stats.text = "⚡ " + poder + " | 🪖 " + tropas + " | 💀 " + bajas
	
	label_estado.text = datos["estado"]

# 3. La función que detecta nuestro clic (generada por la señal)
func _on_gui_input(event: InputEvent) -> void:
	# Usamos la misma lógica del fondo oscuro
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 2. Reemplazamos el print por la instanciación del modal
		var nuevo_perfil = PerfilTripulanteEscena.instantiate()
		# 3. PRIMERO lo añadimos a la pantalla (despierta los nodos)
		get_tree().current_scene.add_child(nuevo_perfil)
		# 4. SEGUNDO le pasamos los datos
		nuevo_perfil.configurar_perfil(datos_jugador)

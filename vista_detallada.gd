extends Control

var TarjetaMiembroEscena = preload("res://tarjeta_miembro.tscn")
# 1. Cargamos el Modal
var ModalUnirseEscena = preload("res://modal_unirse.tscn")

@onready var btn_volver = $VBoxContainer/MarginContainer/HBoxContainer/Button2
@onready var label_titulo = $VBoxContainer/MarginContainer/HBoxContainer/Label
# 2. Referencia al botón de solicitar (asegúrate de que sea Button2 o el nombre que le diste)
@onready var btn_solicitar = $VBoxContainer/MarginContainer/HBoxContainer/Button
@onready var contenedor_miembros = $VBoxContainer/TabContainer/Miembros/VBoxContainer/ScrollContainer/VBoxContainer

# Variables para recordar los datos de esta alianza
var id_actual : int = 0
var nombre_actual : String = ""
var requisito_actual : int = 0

func _ready():
	btn_volver.pressed.connect(_on_btn_volver_pressed)
	# 3. Conectamos el botón
	btn_solicitar.pressed.connect(_on_btn_solicitar_pressed)

func _on_btn_volver_pressed():
	queue_free()

# 4. Actualizamos la función para recibir los 3 datos
func configurar_vista(id: int, nombre: String, req: int):
	id_actual = id
	nombre_actual = nombre
	requisito_actual = req
	
	label_titulo.text = "🛡️ " + nombre_actual
	_cargar_miembros_falsos()

# 5. La función que abre el modal
func _on_btn_solicitar_pressed():
	var nuevo_modal = ModalUnirseEscena.instantiate()
	# Le pasamos los datos que guardamos
	nuevo_modal.configurar_modal(id_actual, nombre_actual, requisito_actual)
	get_tree().current_scene.add_child(nuevo_modal)

# (Aquí abajo dejas tu función _cargar_miembros_falsos intacta)

# 3. Función temporal para generar miembros dinámicos (Mock Data)
func _cargar_miembros_falsos():
	# Limpiamos la lista primero por seguridad
	for hijo in contenedor_miembros.get_children():
		hijo.queue_free()
		
	var lista_jugadores = []
	
	# Usamos 'match' para revisar el ID de la alianza seleccionada
	match id_actual:
		1: # Si es Striker Force (ID 1)
			lista_jugadores = [
				{"nombre": "AstroRey", "rango": "Líder", "poder": "950K", "tropas": "50K", "bajas": "25K", "estado": "🟢 Activo (hace 5m)"},
				{"nombre": "NovaGuard", "rango": "Oficial", "poder": "820K", "tropas": "45K", "bajas": "18K", "estado": "🟢 Activo (hace 1h)"}
			]
		2: # Si es Nova Vanguard (ID 2)
			lista_jugadores = [
				{"nombre": "ComandanteX", "rango": "Líder", "poder": "500K", "tropas": "30K", "bajas": "10K", "estado": "🟢 Activo (hace 10m)"},
				{"nombre": "EstrellaFugaz", "rango": "Miembro", "poder": "400K", "tropas": "20K", "bajas": "5K", "estado": "🟡 Inactivo (hace 2d)"}
			]
		3: # Si es Legión Cósmica (ID 3)
			lista_jugadores = [
				{"nombre": "LordGalactum", "rango": "Líder", "poder": "2.5M", "tropas": "150K", "bajas": "80K", "estado": "🟢 Activo (hace 1m)"},
				{"nombre": "CometaOscuro", "rango": "Miembro", "poder": "350K", "tropas": "15K", "bajas": "2K", "estado": "🔴 Ausente"}
			]
		_: # El guion bajo significa "Por defecto" (si el ID es otro)
			lista_jugadores = [
				{"nombre": "ReclutaNuevo", "rango": "Miembro", "poder": "10K", "tropas": "1K", "bajas": "0", "estado": "🟢 Activo"}
			]
	
	# Clonamos una tarjeta por cada jugador en la lista correspondiente
	for datos in lista_jugadores:
		var nueva_tarjeta = TarjetaMiembroEscena.instantiate()
		contenedor_miembros.add_child(nueva_tarjeta)
		nueva_tarjeta.configurar_miembro(datos)

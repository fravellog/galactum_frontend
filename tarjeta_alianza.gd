extends PanelContainer

# 1. Cargamos la escena del Modal
var VistaDetalladaEscena = preload("res://vista_detallada.tscn")
var ModalUnirseEscena = preload("res://modal_unirse.tscn")

# Referencias a los nodos visuales
@onready var label_titulo = $MarginContainer/HBoxContainer/VBoxContainer/Label
@onready var label_stats = $MarginContainer/HBoxContainer/VBoxContainer/Label2
@onready var label_requisitos = $MarginContainer/HBoxContainer/VBoxContainer/Label3
@onready var btn_solicitar = $MarginContainer/HBoxContainer/VBoxContainer2/Button2
@onready var btn_ver = $MarginContainer/HBoxContainer/VBoxContainer2/Button
# Variables para guardar los datos de esta alianza
var id_alianza : int = 0
var nombre_alianza : String = ""
var requisito_poder: int = 0

func _ready():
	# 2. Conectamos el clic del botón a nuestra nueva función
	btn_ver.pressed.connect(_on_btn_ver_pressed) # Añadimos esta línea
	btn_solicitar.pressed.connect(_on_btn_solicitar_pressed)

func configurar_tarjeta(datos_alianza: Dictionary):
	id_alianza = datos_alianza["id"]
	nombre_alianza = datos_alianza["nombre"] # Guardamos el nombre para pasárselo al modal
	
	label_titulo.text = "🛡️ " + nombre_alianza + " Lv. " + str(datos_alianza["nivel"])
	
	var miembros = str(datos_alianza["miembros_actuales"]) + "/" + str(datos_alianza["miembros_maximos"])
	var poder = str(datos_alianza["poder_total"])
	var region = datos_alianza["region"]
	label_stats.text = "👥 " + miembros + "  ⚡ " + poder + "  🌍 " + region
	
	label_requisitos.text = "📋 Requisito: Poder ≥ " + str(datos_alianza["req_poder"])
	
	if APIManager.get("poder_jugador") != null and APIManager.poder_jugador < datos_alianza["req_poder"]:
		btn_solicitar.disabled = true
		btn_solicitar.text = "🔒 Nivel Bajo"
	requisito_poder = datos_alianza["req_poder"] # Guardamos este dato

# 3. La función que se activa al presionar "Solicitar"
func _on_btn_solicitar_pressed():
	# Creamos un clon de nuestro menú emergente
	var nuevo_modal = ModalUnirseEscena.instantiate()
	
	# Le inyectamos los datos de ESTA tarjeta específica
	nuevo_modal.configurar_modal(id_alianza, nombre_alianza, requisito_poder)
	
	# Añadimos el modal a la "escena actual" (el menú principal) 
	# para que aparezca por encima de absolutamente todo el juego.
	get_tree().current_scene.add_child(nuevo_modal)

func _on_btn_ver_pressed():
	var nueva_vista = VistaDetalladaEscena.instantiate()
	# Hacemos que ocupe toda la pantalla y la añadimos a la escena actual 
	get_tree().current_scene.add_child(nueva_vista)
	# Le pasamos el ID, el Nombre y el Requisito de Poder
	nueva_vista.configurar_vista(id_alianza, nombre_alianza, requisito_poder)

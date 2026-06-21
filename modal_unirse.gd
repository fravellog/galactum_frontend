extends Control

# Referencias a los nodos clave
@onready var checkbox_reglas = $CenterContainer/Panel/MarginContainer/VBoxContainer/CheckBox
@onready var btn_cancelar = $CenterContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/Button
@onready var btn_enviar = $CenterContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/Button2
@onready var input_mensaje = $CenterContainer/Panel/MarginContainer/VBoxContainer/TextEdit

# Variable para saber a qué alianza nos estamos intentando unir
var id_alianza_destino : int = 0

func _ready():
	# 1. Por defecto, el botón de enviar arranca deshabilitado
	btn_enviar.disabled = true
	
	# 2. Conectamos las señales (cuando el jugador hace clic)
	checkbox_reglas.toggled.connect(_on_checkbox_reglas_toggled)
	btn_cancelar.pressed.connect(_on_btn_cancelar_pressed)
	btn_enviar.pressed.connect(_on_btn_enviar_pressed)

# Cuando el jugador marca o desmarca la casilla de reglas
func _on_checkbox_reglas_toggled(esta_marcado: bool):
	# Si está marcado, el botón se habilita. Si no, se deshabilita.
	btn_enviar.disabled = !esta_marcado

# Cuando el jugador se arrepiente y presiona "Cancelar"
func _on_btn_cancelar_pressed():
	# Destruimos este menú para que desaparezca de la pantalla
	queue_free()

# Cuando el jugador presiona "Enviar solicitud"
func _on_btn_enviar_pressed():
	var mensaje = input_mensaje.text
	print("Enviando solicitud a la alianza ID: ", id_alianza_destino)
	print("Mensaje adjunto: ", mensaje)
	
	# (Aquí después agregaremos el nodo HTTPRequest para enviarlo al servidor de tu compañero)
	
	# Por ahora, cerramos el modal simulando que se envió
	queue_free()

# Esta función la llamaremos desde afuera para pasarle los datos antes de abrirlo
# Fíjate que agregamos "req_poder: int" a los paréntesis
func configurar_modal(id_alianza: int, nombre_alianza_seleccionada: String, req_poder: int):
	id_alianza_destino = id_alianza
	# Opcional: Si quieres actualizar el título desde el código
	var label_titulo = $CenterContainer/Panel/MarginContainer/VBoxContainer/Label
	label_titulo.text = "🤝 Unirse a " + nombre_alianza_seleccionada
	# Suponiendo que tu Label2 es el de los requisitos:
	var label_req = $CenterContainer/Panel/MarginContainer/VBoxContainer/Label2
	label_req.text = "📋 Requisito: Poder ≥ " + str(req_poder)

func _on_color_rect_gui_input(event: InputEvent) -> void:
	# Preguntamos: ¿Fue un clic de ratón (o toque de pantalla) Y fue presionado Y fue el clic izquierdo?
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("El jugador hizo clic afuera. Cerrando menú...")
		queue_free() # Destruimos el modal

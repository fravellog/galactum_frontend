extends Control

@onready var label_nombre = $CenterContainer/Panel/MarginContainer/VBoxContainer/Label2
@onready var label_rango = $CenterContainer/Panel/MarginContainer/VBoxContainer/Label3
@onready var label_stats = $CenterContainer/Panel/MarginContainer/VBoxContainer/Label4
@onready var label_estado = $CenterContainer/Panel/MarginContainer/VBoxContainer/Label5
@onready var btn_cerrar = $CenterContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/Button

func _ready():
	btn_cerrar.pressed.connect(cerrar_modal)

# Función para inyectar los datos del jugador
func configurar_perfil(datos: Dictionary):
	label_nombre.text = datos["nombre"]
	label_rango.text = "Rango: " + datos["rango"]
	label_stats.text = "⚡ Poder: " + str(datos["poder"]) + "\n🪖 Tropas: " + str(datos["tropas"]) + "\n💀 Bajas: " + str(datos["bajas"])
	label_estado.text = "Estado: " + datos["estado"]

func cerrar_modal():
	queue_free()

# Para cerrar al hacer clic en el fondo oscuro
func _on_color_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cerrar_modal()

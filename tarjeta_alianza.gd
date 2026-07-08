extends PanelContainer

var VistaDetalladaEscena = preload("res://vista_detallada.tscn")
var ModalUnirseEscena = preload("res://modal_unirse.tscn")

@onready var label_titulo = $MarginContainer/HBoxContainer/VBoxContainer/Label
@onready var label_stats = $MarginContainer/HBoxContainer/VBoxContainer/Label2
@onready var label_requisitos = $MarginContainer/HBoxContainer/VBoxContainer/Label3
@onready var btn_solicitar = $MarginContainer/HBoxContainer/VBoxContainer2/Button2
@onready var btn_ver = $MarginContainer/HBoxContainer/VBoxContainer2/Button

var id_alianza: int = 0
var nombre_alianza: String = ""
var requisito_poder: int = 0


func _ready():
	btn_ver.pressed.connect(_on_btn_ver_pressed)
	btn_solicitar.pressed.connect(_on_btn_solicitar_pressed)


func configurar_tarjeta(datos_alianza: Dictionary) -> void:
	id_alianza = _to_int(datos_alianza.get("id", 0), 0)
	nombre_alianza = str(datos_alianza.get("nombre", "Alianza sin nombre"))
	requisito_poder = _to_int(datos_alianza.get("req_poder", 0), 0)

	var nivel: int = _to_int(datos_alianza.get("nivel", 1), 1)
	var miembros_actuales: int = _to_int(datos_alianza.get("miembros_actuales", 0), 0)
	var miembros_maximos: int = _to_int(datos_alianza.get("miembros_maximos", 0), 0)
	var poder_total: String = str(datos_alianza.get("poder_total", "0"))
	var region: String = str(datos_alianza.get("region", "ES"))
	var poder_jugador: int = _to_int(APIManager.usuario_actual.get("poder", 0), 0)

	var lider_jugador_id: int = _to_int(datos_alianza.get("lider_jugador_id", null), 0)
	var alliance_id_usuario: int = _to_int(APIManager.usuario_actual.get("alliance_id", 0), 0)

	var usuario_tiene_alianza: bool = alliance_id_usuario > 0

	label_titulo.text = "🛡️ " + nombre_alianza + " Lv. " + str(nivel)
	label_stats.text = "👥 " + str(miembros_actuales) + "/" + str(miembros_maximos) + "  ⚡ " + poder_total + "  🌍 " + region
	label_requisitos.text = "📋 Requisito: Poder ≥ " + str(requisito_poder)

	if usuario_tiene_alianza:
		btn_solicitar.disabled = true
		btn_solicitar.text = "Ya tienes alianza"
	elif lider_jugador_id <= 0:
		btn_solicitar.disabled = true
		btn_solicitar.text = "Sin líder"
	elif poder_jugador < requisito_poder:
		btn_solicitar.disabled = true
		btn_solicitar.text = "Poder insuficiente"
	elif miembros_actuales >= miembros_maximos:
		btn_solicitar.disabled = true
		btn_solicitar.text = "Alianza completa"
	else:
		btn_solicitar.disabled = false
		btn_solicitar.text = "📩 Solicitar"
func _on_btn_solicitar_pressed():
	var nuevo_modal = ModalUnirseEscena.instantiate()

	# Debe estar en el árbol antes de configurar sus @onready.
	get_tree().current_scene.add_child(nuevo_modal)

	nuevo_modal.configurar_modal(
		id_alianza,
		nombre_alianza,
		requisito_poder
	)


func _on_btn_ver_pressed():
	var nueva_vista = VistaDetalladaEscena.instantiate()
	get_tree().current_scene.add_child(nueva_vista)
	nueva_vista.configurar_vista(id_alianza, nombre_alianza, requisito_poder)
	
func _to_int(value: Variant, fallback: int = 0) -> int:
	if value == null:
		return fallback

	if typeof(value) == TYPE_INT:
		return int(value)

	if typeof(value) == TYPE_FLOAT:
		return int(value)

	if typeof(value) == TYPE_STRING:
		var texto: String = str(value).strip_edges()

		if texto.is_valid_int():
			return texto.to_int()

	return fallback

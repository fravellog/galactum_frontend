extends Control


var request: HTTPRequest
var tripulantes: Array = []
var tripulante_actual: Dictionary = {}

@onready var hbox_principal: HBoxContainer = $HBoxContainer_Principal
@onready var panel_lista: PanelContainer = $HBoxContainer_Principal/Panel_Lista
@onready var scroll_lista: ScrollContainer = $HBoxContainer_Principal/Panel_Lista/ScrollContainer
@onready var panel_detalles: PanelContainer = $HBoxContainer_Principal/Panel_Detalles
@onready var vbox_detalles: VBoxContainer = $HBoxContainer_Principal/Panel_Detalles/VBoxContainer

@onready var foto_personaje: TextureRect = $HBoxContainer_Principal/Panel_Detalles/VBoxContainer/Foto_Personaje
@onready var label_nombre: Label = $HBoxContainer_Principal/Panel_Detalles/VBoxContainer/Label_Nombre
@onready var label_lore: Label = $HBoxContainer_Principal/Panel_Detalles/VBoxContainer/Label_Lore
@onready var grid_stats: GridContainer = $HBoxContainer_Principal/Panel_Detalles/VBoxContainer/GridContainer_Stats
@onready var label_stat_1: Label = $HBoxContainer_Principal/Panel_Detalles/VBoxContainer/GridContainer_Stats/Label
@onready var label_stat_2: Label = $HBoxContainer_Principal/Panel_Detalles/VBoxContainer/GridContainer_Stats/Label2
@onready var button_modificar: Button = $HBoxContainer_Principal/Panel_Detalles/VBoxContainer/Button_Modificar

var grid_personajes: GridContainer
var btn_centro_mando: Button
var btn_volver_nave: Button


func _ready() -> void:
	grid_personajes = _obtener_grid_personajes()
	btn_centro_mando = get_node_or_null("MarginContainer/HBoxContainer_Navegacion/Button_CentroMando") as Button
	btn_volver_nave = get_node_or_null("MarginContainer/HBoxContainer_Navegacion/Button_Volver") as Button

	if btn_volver_nave == null:
		btn_volver_nave = get_node_or_null("MarginContainer/Button_Volver") as Button

	_configurar_layout()
	_configurar_botones()

	request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_tripulantes_completado)

	_mostrar_cargando()
	_cargar_tripulantes_backend()


func _obtener_grid_personajes() -> GridContainer:
	var nodo_1: Node = get_node_or_null(
		"HBoxContainer_Principal/Panel_Lista/ScrollContainer/GridContainer_Personajes"
	)

	if nodo_1 != null:
		return nodo_1 as GridContainer

	var nodo_2: Node = get_node_or_null(
		"HBoxContainer_Principal/Panel_Lista/ScrollContainer/GridContainer_Pers"
	)

	if nodo_2 != null:
		return nodo_2 as GridContainer

	var nuevo_grid: GridContainer = GridContainer.new()
	nuevo_grid.name = "GridContainer_Personajes"
	scroll_lista.add_child(nuevo_grid)

	return nuevo_grid


func _configurar_layout() -> void:
	hbox_principal.add_theme_constant_override("separation", 20)

	panel_lista.custom_minimum_size = Vector2(430, 0)
	panel_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL

	panel_detalles.custom_minimum_size = Vector2(520, 0)
	panel_detalles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_detalles.size_flags_vertical = Control.SIZE_EXPAND_FILL

	scroll_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_lista.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	grid_personajes.columns = 1
	grid_personajes.custom_minimum_size = Vector2(400, 0)
	grid_personajes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_personajes.add_theme_constant_override("h_separation", 10)
	grid_personajes.add_theme_constant_override("v_separation", 10)

	vbox_detalles.custom_minimum_size = Vector2(500, 0)
	vbox_detalles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_detalles.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_detalles.add_theme_constant_override("separation", 10)

	foto_personaje.visible = false

	label_nombre.custom_minimum_size = Vector2(480, 0)
	label_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	label_lore.custom_minimum_size = Vector2(480, 120)
	label_lore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	grid_stats.columns = 1
	grid_stats.custom_minimum_size = Vector2(480, 0)
	grid_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_stats.add_theme_constant_override("h_separation", 8)
	grid_stats.add_theme_constant_override("v_separation", 8)

	label_stat_1.custom_minimum_size = Vector2(480, 0)
	label_stat_1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_stat_1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	label_stat_2.custom_minimum_size = Vector2(480, 0)
	label_stat_2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_stat_2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	button_modificar.disabled = true
	button_modificar.text = "Mejora pendiente"


func _configurar_botones() -> void:
	if btn_centro_mando != null:
		btn_centro_mando.pressed.connect(_volver_centro_mando)

	if btn_volver_nave != null:
		btn_volver_nave.pressed.connect(_volver_mi_nave)


func _cargar_tripulantes_backend() -> void:
	var headers: PackedStringArray = PackedStringArray(
		APIManager.get_auth_headers()
	)

	var error: int = request.request(
		APIManager.base_url + "/tripulantes/mi-nave",
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		_mostrar_error(
			"No fue posible iniciar la consulta al backend."
		)


func _on_tripulantes_completado(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var texto: String = body.get_string_from_utf8()

	if response_code != 200:
		_mostrar_error(
			"Error HTTP "
			+ str(response_code)
			+ ": "
			+ texto
		)

		return

	var parsed: Variant = JSON.parse_string(texto)
	var lista: Array = _extraer_tripulantes(parsed)

	tripulantes = lista

	if tripulantes.is_empty():
		_mostrar_sin_tripulantes()
		return

	_mostrar_tripulantes()


func _extraer_tripulantes(parsed: Variant) -> Array:
	if typeof(parsed) == TYPE_ARRAY:
		return parsed as Array

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary

		var data: Variant = response.get(
			"tripulantes",
			response.get("data", [])
		)

		if typeof(data) == TYPE_ARRAY:
			return data as Array

	return []


func _mostrar_cargando() -> void:
	_limpiar_lista()

	var label_cargando: Label = _crear_label_lista(
		"Cargando tripulantes desde el backend..."
	)

	grid_personajes.add_child(label_cargando)

	label_nombre.text = "Cargando tripulación"
	label_lore.text = "Consultando GET /tripulantes/mi-nave en FastAPI."
	label_stat_1.text = "Estado: consultando servidor"
	label_stat_2.text = "Esperando respuesta del backend..."
	button_modificar.disabled = true
	button_modificar.text = "Mejora pendiente"


func _mostrar_sin_tripulantes() -> void:
	_limpiar_lista()

	var label_vacio: Label = _crear_label_lista(
		"No se encontraron tripulantes en la nave."
	)

	grid_personajes.add_child(label_vacio)

	label_nombre.text = "Tripulación vacía"

	label_lore.text = (
		"No se encontraron tripulantes en la nave.\n\n"
		+ "La pantalla ya está consultando el backend correctamente, "
		+ "pero todavía no existen tripulantes registrados para este jugador."
	)

	label_stat_1.text = "Estado: sin tripulantes asignados"
	label_stat_2.text = "Origen de datos: FastAPI / Neon"

	button_modificar.disabled = true
	button_modificar.text = "Mejora pendiente"


func _mostrar_error(mensaje: String) -> void:
	_limpiar_lista()

	var label_error: Label = _crear_label_lista(
		"No fue posible cargar la tripulación."
	)

	grid_personajes.add_child(label_error)

	label_nombre.text = "Error de tripulación"
	label_lore.text = mensaje
	label_stat_1.text = "Estado: error"
	label_stat_2.text = "Revisa FastAPI, Neon o el token JWT."
	button_modificar.disabled = true
	button_modificar.text = "Mejora pendiente"


func _mostrar_tripulantes() -> void:
	_limpiar_lista()

	for item: Variant in tripulantes:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var tripulante: Dictionary = item as Dictionary
		var boton: Button = _crear_boton_tripulante(tripulante)

		grid_personajes.add_child(boton)

	if tripulantes.size() > 0:
		var primer_item: Variant = tripulantes[0]

		if typeof(primer_item) == TYPE_DICTIONARY:
			_seleccionar_tripulante(primer_item as Dictionary)


func _crear_boton_tripulante(tripulante: Dictionary) -> Button:
	var nombre: String = _obtener_nombre(tripulante)
	var rol: String = _obtener_rol(tripulante)
	var nivel: int = _obtener_nivel(tripulante)

	var boton: Button = Button.new()

	boton.text = (
		nombre
		+ "\n"
		+ rol
		+ " | Nivel "
		+ str(nivel)
	)

	boton.custom_minimum_size = Vector2(400, 72)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	boton.pressed.connect(
		_seleccionar_tripulante.bind(tripulante)
	)

	return boton


func _seleccionar_tripulante(tripulante: Dictionary) -> void:
	tripulante_actual = tripulante

	var nombre: String = _obtener_nombre(tripulante)
	var rol: String = _obtener_rol(tripulante)
	var nivel: int = _obtener_nivel(tripulante)
	var especializacion: String = _obtener_especializacion(tripulante)
	var estado: String = str(
		tripulante.get("estado", "Disponible")
	)

	label_nombre.text = nombre

	label_lore.text = (
		rol
		+ "\n\nEspecialización: "
		+ especializacion
		+ "\nEstado: "
		+ estado
	)

	label_stat_1.text = (
		"Nivel: "
		+ str(nivel)
		+ "\nRol: "
		+ rol
	)

	label_stat_2.text = (
		"Especialización: "
		+ especializacion
		+ "\nEstado: "
		+ estado
	)

	button_modificar.disabled = false
	button_modificar.text = "Modificar / Subir nivel"


func _crear_label_lista(texto: String) -> Label:
	var label: Label = Label.new()

	label.text = texto
	label.custom_minimum_size = Vector2(400, 90)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	return label


func _limpiar_lista() -> void:
	for child: Node in grid_personajes.get_children():
		child.queue_free()


func _obtener_nombre(tripulante: Dictionary) -> String:
	return str(
		tripulante.get(
			"nombre",
			tripulante.get("name", "Tripulante sin nombre")
		)
	)


func _obtener_rol(tripulante: Dictionary) -> String:
	return str(
		tripulante.get(
			"rol",
			tripulante.get(
				"role",
				tripulante.get("especializacion", "Tripulante")
			)
		)
	)


func _obtener_especializacion(tripulante: Dictionary) -> String:
	return str(
		tripulante.get(
			"especializacion",
			tripulante.get("specialty", "General")
		)
	)


func _obtener_nivel(tripulante: Dictionary) -> int:
	var valor: Variant = tripulante.get(
		"nivel",
		tripulante.get("level", 1)
	)

	return _to_int(valor, 1)


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


func _volver_centro_mando() -> void:
	get_tree().change_scene_to_file("res://centro_mando.tscn")


func _volver_mi_nave() -> void:
	get_tree().change_scene_to_file("res://mi_nave.tscn")

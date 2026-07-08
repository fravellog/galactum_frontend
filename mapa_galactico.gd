extends Control


const MAP_MIN: float = -4000.0
const MAP_MAX: float = 4000.0
const SHIP_SIZE: Vector2 = Vector2(70, 70)
const SECTOR_SIZE: Vector2 = Vector2(150, 58)

var request_mapa: HTTPRequest
var request_viaje: HTTPRequest

var mapa_data: Dictionary = {}
var sectores: Array = []
var sector_seleccionado: Dictionary = {}

@onready var fondo: TextureRect = $FondoEspacial
@onready var area_radar: Control = $Area_Radar
@onready var linea_ruta: Line2D = $Area_Radar/Linea_Ruta
@onready var icono_jugador: TextureRect = $Area_Radar/Icono_Jugador
@onready var icono_alianza: TextureRect = $Area_Radar/Icono_Alianza

@onready var panel_info: PanelContainer = $Panel_Informacion
@onready var info_box: VBoxContainer = $Panel_Informacion/MarginContainer/VBoxContainer
@onready var label_titulo: Label = $Panel_Informacion/MarginContainer/VBoxContainer/Label_Titulo
@onready var label_ubicacion_jugador: Label = $Panel_Informacion/MarginContainer/VBoxContainer/Label_UbicacionJugador
@onready var label_ubicacion_alianza: Label = $Panel_Informacion/MarginContainer/VBoxContainer/Label_UbicacionAlianza
@onready var label_distancia: Label = $Panel_Informacion/MarginContainer/VBoxContainer/Label_Distancia
@onready var btn_centro_mando = $MarginContainer/HBoxContainer/Button_CentroMando

var boton_centro_mando: Button
var boton_viajar: Button
var label_estado: Label
var sector_buttons_container: Node


func _ready() -> void:
	_configurar_layout()
	_configurar_requests()
	_mostrar_cargando()
	_cargar_mapa_backend()
	btn_centro_mando.pressed.connect(_on_btn_centro_mando_pressed)
	


func _configurar_layout() -> void:
	area_radar.anchor_left = 0.0
	area_radar.anchor_top = 0.0
	area_radar.anchor_right = 1.0
	area_radar.anchor_bottom = 1.0
	area_radar.offset_left = 0.0
	area_radar.offset_top = 0.0
	area_radar.offset_right = 0.0
	area_radar.offset_bottom = 0.0
	area_radar.mouse_filter = Control.MOUSE_FILTER_PASS

	panel_info.anchor_left = 0.0
	panel_info.anchor_top = 1.0
	panel_info.anchor_right = 0.0
	panel_info.anchor_bottom = 1.0
	panel_info.offset_left = 22.0
	panel_info.offset_top = -175.0
	panel_info.offset_right = 460.0
	panel_info.offset_bottom = -20.0

	info_box.add_theme_constant_override("separation", 6)

	for label_item: Label in [
		label_titulo,
		label_ubicacion_jugador,
		label_ubicacion_alianza,
		label_distancia,
	]:
		label_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	icono_jugador.custom_minimum_size = SHIP_SIZE
	icono_jugador.size = SHIP_SIZE
	icono_jugador.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono_jugador.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	icono_alianza.custom_minimum_size = Vector2(62, 62)
	icono_alianza.size = Vector2(62, 62)
	icono_alianza.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono_alianza.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono_alianza.visible = false

	linea_ruta.clear_points()
	linea_ruta.default_color = Color(0.0, 1.0, 1.0, 0.65)
	linea_ruta.width = 3.0

	label_estado = Label.new()
	label_estado.text = "Estado: preparando mapa..."
	label_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(label_estado)

	boton_viajar = Button.new()
	boton_viajar.text = "Viajar al sector"
	boton_viajar.disabled = true
	boton_viajar.custom_minimum_size = Vector2(0, 38)
	boton_viajar.pressed.connect(_on_boton_viajar_pressed)
	info_box.add_child(boton_viajar)

	sector_buttons_container = Node.new()
	sector_buttons_container.name = "SectorButtons"
	area_radar.add_child(sector_buttons_container)



func _configurar_requests() -> void:
	request_mapa = HTTPRequest.new()
	request_viaje = HTTPRequest.new()

	add_child(request_mapa)
	add_child(request_viaje)

	request_mapa.request_completed.connect(_on_mapa_completado)
	request_viaje.request_completed.connect(_on_viaje_completado)


func _cargar_mapa_backend() -> void:
	var error: int = request_mapa.request(
		APIManager.base_url + "/map/sectores",
		APIManager.get_auth_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		_mostrar_error("No fue posible iniciar la consulta del mapa.")


func _on_mapa_completado(
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

	if typeof(parsed) != TYPE_DICTIONARY:
		_mostrar_error("El backend no devolvió un mapa JSON válido.")
		return

	mapa_data = parsed as Dictionary

	var raw_sectores: Variant = mapa_data.get("sectores", [])

	if typeof(raw_sectores) == TYPE_ARRAY:
		sectores = raw_sectores as Array
	else:
		sectores = []

	_dibujar_mapa()


func _dibujar_mapa() -> void:
	_limpiar_sectores()
	linea_ruta.clear_points()
	sector_seleccionado.clear()
	boton_viajar.disabled = true

	var nave: Dictionary = _obtener_nave()
	var posicion_nave: Dictionary = _obtener_posicion_nave(nave)
	var ship_screen_pos: Vector2 = _world_to_screen(
		_to_float(posicion_nave.get("x", 0.0), 0.0),
		_to_float(posicion_nave.get("y", 0.0), 0.0)
	)

	icono_jugador.position = ship_screen_pos - (SHIP_SIZE / 2.0)
	icono_jugador.size = SHIP_SIZE
	icono_jugador.visible = true

	label_titulo.text = "📡 Mapa Galáctico conectado"
	label_ubicacion_jugador.text = (
		"🚀 Nave: "
		+ str(nave.get("nombre", "Sin nombre"))
		+ " | X "
		+ _format_float(_to_float(posicion_nave.get("x", 0.0), 0.0))
		+ " | Y "
		+ _format_float(_to_float(posicion_nave.get("y", 0.0), 0.0))
	)
	label_ubicacion_alianza.text = "🛰️ Selecciona un sector del mapa."

	var estado_movimiento: String = "En espera"

	if bool(nave.get("en_movimiento", false)):
		estado_movimiento = "Viajando"

	label_distancia.text = (
		"⚡ Energía: "
		+ str(nave.get("energia_actual", 0))
		+ " / "
		+ str(nave.get("energia_maxima", 0))
		+ " | Estado: "
		+ estado_movimiento
	)

	label_estado.text = "Mapa cargado desde FastAPI. Sectores disponibles: " + str(sectores.size())

	if sectores.is_empty():
		label_estado.text = "No se encontraron sectores disponibles."
		return

	for item: Variant in sectores:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var sector: Dictionary = item as Dictionary
		_crear_boton_sector(sector)


func _crear_boton_sector(sector: Dictionary) -> void:
	var sector_x: float = _to_float(sector.get("x", 0.0), 0.0)
	var sector_y: float = _to_float(sector.get("y", 0.0), 0.0)
	var posicion: Vector2 = _world_to_screen(sector_x, sector_y)

	var boton: Button = Button.new()
	boton.text = (
		"● "
		+ str(sector.get("nombre", "Sector"))
		+ "\n"
		+ str(sector.get("tipo", "Desconocido"))
	)
	boton.custom_minimum_size = SECTOR_SIZE
	boton.size = SECTOR_SIZE
	boton.position = posicion - (SECTOR_SIZE / 2.0)
	boton.tooltip_text = str(sector.get("descripcion", ""))
	boton.alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boton.pressed.connect(_seleccionar_sector.bind(sector, boton))

	sector_buttons_container.add_child(boton)


func _seleccionar_sector(sector: Dictionary, boton: Button) -> void:
	sector_seleccionado = sector

	var nave: Dictionary = _obtener_nave()
	var posicion_nave: Dictionary = _obtener_posicion_nave(nave)

	var ship_pos: Vector2 = _world_to_screen(
		_to_float(posicion_nave.get("x", 0.0), 0.0),
		_to_float(posicion_nave.get("y", 0.0), 0.0)
	)

	var sector_pos: Vector2 = boton.position + (boton.size / 2.0)

	linea_ruta.clear_points()
	linea_ruta.add_point(ship_pos)
	linea_ruta.add_point(sector_pos)

	icono_alianza.position = sector_pos + Vector2(35, -75)
	icono_alianza.visible = true

	var distancia: float = ship_pos.distance_to(sector_pos)
	var energia: int = _to_int(sector.get("energia_requerida", 0), 0)

	label_ubicacion_alianza.text = (
		"🎯 Destino: "
		+ str(sector.get("nombre", "Sector"))
		+ " | "
		+ str(sector.get("tipo", "Desconocido"))
	)

	label_distancia.text = (
		"📍 Coordenadas: X "
		+ _format_float(_to_float(sector.get("x", 0.0), 0.0))
		+ " | Y "
		+ _format_float(_to_float(sector.get("y", 0.0), 0.0))
		+ " | Energía requerida: "
		+ str(energia)
	)

	label_estado.text = (
		"Peligro: "
		+ str(sector.get("peligro", "No definido"))
		+ " | Distancia visual: "
		+ _format_float(distancia)
	)

	boton_viajar.disabled = false
	boton_viajar.text = "Viajar a " + str(sector.get("nombre", "sector"))


func _on_boton_viajar_pressed() -> void:
	if sector_seleccionado.is_empty():
		label_estado.text = "Selecciona un sector antes de viajar."
		return

	var sector_id: int = _to_int(sector_seleccionado.get("id", 0), 0)

	if sector_id <= 0:
		label_estado.text = "El sector seleccionado no tiene un ID válido."
		return

	boton_viajar.disabled = true
	label_estado.text = "Iniciando viaje en FastAPI..."

	var error: int = request_viaje.request(
		APIManager.base_url + "/map/viajar?sector_id=" + str(sector_id),
		APIManager.get_auth_headers(),
		HTTPClient.METHOD_POST,
		""
	)

	if error != OK:
		label_estado.text = "No fue posible enviar la orden de viaje."
		boton_viajar.disabled = false


func _on_viaje_completado(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var texto: String = body.get_string_from_utf8()

	if response_code != 200:
		var mensaje_error: String = _extraer_detail(texto)
		label_estado.text = "No se pudo iniciar el viaje: " + mensaje_error
		boton_viajar.disabled = false
		return

	var parsed: Variant = JSON.parse_string(texto)

	if typeof(parsed) != TYPE_DICTIONARY:
		label_estado.text = "Viaje iniciado, pero la respuesta no fue válida."
		_cargar_mapa_backend()
		return

	var response: Dictionary = parsed as Dictionary
	label_estado.text = str(response.get("mensaje", "Viaje iniciado correctamente."))

	_cargar_mapa_backend()


func _obtener_nave() -> Dictionary:
	var nave_raw: Variant = mapa_data.get("nave", {})

	if typeof(nave_raw) == TYPE_DICTIONARY:
		return nave_raw as Dictionary

	return {}


func _obtener_posicion_nave(nave: Dictionary) -> Dictionary:
	var posicion_raw: Variant = nave.get("posicion", {})

	if typeof(posicion_raw) == TYPE_DICTIONARY:
		return posicion_raw as Dictionary

	return {
		"x": 0.0,
		"y": 0.0,
	}


func _limpiar_sectores() -> void:
	for child: Node in sector_buttons_container.get_children():
		child.queue_free()


func _mostrar_cargando() -> void:
	label_titulo.text = "📡 Cargando mapa galáctico"
	label_ubicacion_jugador.text = "Consultando posición real de la nave..."
	label_ubicacion_alianza.text = "Consultando sectores disponibles..."
	label_distancia.text = "Esperando respuesta del backend."
	label_estado.text = "GET /map/sectores"
	boton_viajar.disabled = true


func _mostrar_error(mensaje: String) -> void:
	label_titulo.text = "📡 Error de mapa"
	label_ubicacion_jugador.text = "No fue posible cargar el mapa galáctico."
	label_ubicacion_alianza.text = mensaje
	label_distancia.text = "Revisa FastAPI, Neon o el token JWT."
	label_estado.text = "Error"
	boton_viajar.disabled = true


func _world_to_screen(x: float, y: float) -> Vector2:
	var radar_size: Vector2 = area_radar.size

	if radar_size.x <= 0.0 or radar_size.y <= 0.0:
		radar_size = get_viewport_rect().size

	var padding: float = 95.0
	var usable_width: float = maxf(1.0, radar_size.x - (padding * 2.0))
	var usable_height: float = maxf(1.0, radar_size.y - (padding * 2.0))

	var normalized_x: float = inverse_lerp(MAP_MIN, MAP_MAX, clampf(x, MAP_MIN, MAP_MAX))
	var normalized_y: float = inverse_lerp(MAP_MIN, MAP_MAX, clampf(y, MAP_MIN, MAP_MAX))

	return Vector2(
		padding + (normalized_x * usable_width),
		padding + ((1.0 - normalized_y) * usable_height)
	)


func _extraer_detail(response_text: String) -> String:
	var parsed: Variant = JSON.parse_string(response_text)

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		return str(response.get("detail", response_text))

	if response_text.strip_edges().is_empty():
		return "Error desconocido."

	return response_text


func _to_float(value: Variant, fallback: float = 0.0) -> float:
	if value == null:
		return fallback

	if typeof(value) == TYPE_FLOAT:
		return value as float

	if typeof(value) == TYPE_INT:
		return float(value)

	if typeof(value) == TYPE_STRING:
		var texto: String = str(value).strip_edges()

		if texto.is_valid_float():
			return texto.to_float()

	return fallback


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


func _format_float(value: float) -> String:
	return str(snappedf(value, 0.01))
	
	
func _on_btn_centro_mando_pressed() -> void:
	get_tree().change_scene_to_file("res://centro_mando.tscn")

extends "res://galactum_screen_base.gd"

var list_request: HTTPRequest
var action_request: HTTPRequest

var status_label: Label
var list_box: VBoxContainer


func _ready() -> void:
	var shell: Dictionary = build_shell(
		"MISIONES",
		"TABLERO DE OPERACIONES"
	)

	status_label = shell["status"] as Label

	var info_bundle: Dictionary = make_margin_panel()
	var info_panel: PanelContainer = info_bundle["panel"] as PanelContainer
	var info_margin: MarginContainer = info_bundle["margin"] as MarginContainer

	content_box.add_child(info_panel)

	var info_text: Label = make_label(
		"Selecciona una operación y confirma su aceptación. "
		+ "La respuesta será validada por el backend.",
		16,
		COLOR_MUTED
	)

	info_margin.add_child(info_text)

	content_box.add_child(
		make_section_title("MISIONES DISPONIBLES")
	)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 12)
	scroll.add_child(list_box)

	list_request = HTTPRequest.new()
	action_request = HTTPRequest.new()

	add_child(list_request)
	add_child(action_request)

	list_request.request_completed.connect(_on_list_completed)
	action_request.request_completed.connect(_on_accept_completed)

	finish_shell()
	_load_missions()


func _load_missions() -> void:
	set_status(
		status_label,
		"Cargando misiones...",
		COLOR_WARN
	)

	set_footer("Consultando tablero de operaciones...")

	var error: int = list_request.request(
		api_url("/misiones/disponibles"),
		auth_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		set_status(
			status_label,
			"Error de conexión",
			COLOR_DANGER
		)

		set_footer(
			"No fue posible iniciar la consulta.",
			COLOR_DANGER
		)


func _on_list_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(
			status_label,
			"Error HTTP " + str(response_code),
			COLOR_DANGER
		)

		set_footer(
			"No se pudo cargar el tablero.",
			COLOR_DANGER
		)

		return

	var parsed: Variant = JSON.parse_string(text)
	var missions: Array = _extract_missions(parsed)

	if missions.is_empty():
		clear_children(list_box)

		var empty_label: Label = make_label(
			"No hay misiones disponibles actualmente.",
			16,
			COLOR_MUTED
		)

		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_box.add_child(empty_label)

		set_status(
			status_label,
			"Sin misiones activas",
			COLOR_WARN
		)

		set_footer(
			"El backend respondió correctamente, pero no hay misiones para mostrar."
		)

		return

	clear_children(list_box)

	for mission_data: Variant in missions:
		if typeof(mission_data) == TYPE_DICTIONARY:
			var mission: Dictionary = mission_data as Dictionary
			_add_mission_card(mission)

	set_status(
		status_label,
		str(missions.size()) + " misiones activas",
		COLOR_OK
	)

	set_footer(
		"Selecciona una misión para aceptarla.",
		COLOR_OK
	)


func _extract_missions(parsed: Variant) -> Array:
	if typeof(parsed) == TYPE_ARRAY:
		return parsed as Array

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary

		var candidate: Variant = response.get(
			"misiones",
			response.get("data", [])
		)

		if typeof(candidate) == TYPE_ARRAY:
			return candidate as Array

	return []


func _add_mission_card(mission: Dictionary) -> void:
	var bundle: Dictionary = make_margin_panel()
	var card: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer

	card.custom_minimum_size.y = 150
	list_box.add_child(card)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)
	row.add_child(details)

	var title: String = str(
		mission.get("titulo", "Misión sin título")
	)

	var description: String = str(
		mission.get("descripcion", "Sin descripción")
	)

	var difficulty: String = str(
		mission.get("dificultad", "No definida")
	)

	var reward: String = str(
		mission.get(
			"recompensa_creditos",
			mission.get("recompensa", 0)
		)
	)

	var mission_id: int = _to_int(
		mission.get("id", 0),
		0
	)

	details.add_child(
		make_label(title, 20, COLOR_ACCENT)
	)

	details.add_child(
		make_label(description, 15, COLOR_MUTED)
	)

	details.add_child(
		make_label(
			"Dificultad: "
			+ difficulty
			+ "  |  Recompensa: "
			+ reward
			+ " créditos",
			14,
			COLOR_TEXT
		)
	)

	var accept_button: Button = make_button(
		"Aceptar misión",
		COLOR_OK
	)

	accept_button.custom_minimum_size = Vector2(150, 42)
	accept_button.pressed.connect(
		_accept_mission.bind(mission_id)
	)

	row.add_child(accept_button)


func _accept_mission(mission_id: int) -> void:
	if mission_id <= 0:
		set_footer(
			"La misión seleccionada no tiene un ID válido.",
			COLOR_DANGER
		)

		return

	set_status(
		status_label,
		"Aceptando misión...",
		COLOR_WARN
	)

	set_footer("Enviando solicitud al backend...")

	var error: int = action_request.request(
		api_url(
			"/misiones/"
			+ str(mission_id)
			+ "/aceptar"
		),
		auth_headers(),
		HTTPClient.METHOD_POST,
		""
	)

	if error != OK:
		set_status(
			status_label,
			"Error de conexión",
			COLOR_DANGER
		)

		set_footer(
			"No fue posible enviar la aceptación.",
			COLOR_DANGER
		)


func _on_accept_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(
			status_label,
			"No aceptada",
			COLOR_DANGER
		)

		set_footer(
			"Error HTTP "
			+ str(response_code)
			+ ": "
			+ text,
			COLOR_DANGER
		)

		return

	var parsed: Variant = JSON.parse_string(text)

	var message: String = "Misión aceptada correctamente."

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary

		message = str(
			response.get(
				"message",
				response.get(
					"mensaje",
					message
				)
			)
		)

	set_status(
		status_label,
		"Misión asignada",
		COLOR_OK
	)

	set_footer(message, COLOR_OK)


func _to_int(value: Variant, fallback: int = 0) -> int:
	if value == null:
		return fallback

	if typeof(value) == TYPE_INT:
		return value as int

	if typeof(value) == TYPE_FLOAT:
		return int(value)

	if typeof(value) == TYPE_STRING:
		var value_text: String = str(value).strip_edges()

		if value_text.is_valid_int():
			return value_text.to_int()

	return fallback

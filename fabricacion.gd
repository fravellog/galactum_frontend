extends "res://galactum_screen_base.gd"


var list_request: HTTPRequest
var craft_request: HTTPRequest

var status_label: Label
var ship_label: Label
var recipes_box: VBoxContainer


func _ready() -> void:
	var shell: Dictionary = build_shell(
		"FABRICACIÓN",
		"MEJORAS DE NAVE Y CONSUMO DE RECURSOS"
	)

	status_label = shell["status"] as Label

	_build_summary()
	_build_recipe_list()

	list_request = HTTPRequest.new()
	craft_request = HTTPRequest.new()

	add_child(list_request)
	add_child(craft_request)

	list_request.request_completed.connect(_on_recipes_completed)
	craft_request.request_completed.connect(_on_craft_completed)

	finish_shell()
	_load_recipes()


func _build_summary() -> void:
	var bundle: Dictionary = make_margin_panel()
	var panel: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer
	content_box.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	ship_label = make_label(
		"Nave: cargando datos de fabricación...",
		18,
		COLOR_TEXT
	)
	box.add_child(ship_label)

	box.add_child(
		make_label(
			"Usa los recursos del inventario real para mejorar energía, escudo, casco, extractor y capacidad de carga.",
			14,
			COLOR_MUTED
		)
	)


func _build_recipe_list() -> void:
	content_box.add_child(
		make_section_title("RECETAS DISPONIBLES")
	)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(scroll)

	recipes_box = VBoxContainer.new()
	recipes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipes_box.add_theme_constant_override("separation", 12)
	scroll.add_child(recipes_box)


func _load_recipes() -> void:
	set_status(
		status_label,
		"Cargando recetas...",
		COLOR_WARN
	)

	set_footer("Consultando /crafting/recetas en FastAPI...")

	var error: int = list_request.request(
		api_url("/crafting/recetas"),
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
			"No fue posible iniciar la consulta de fabricación.",
			COLOR_DANGER
		)


func _on_recipes_completed(
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
			_extraer_detail(text),
			COLOR_DANGER
		)
		return

	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		set_status(
			status_label,
			"Respuesta inválida",
			COLOR_DANGER
		)
		set_footer(
			"El backend no devolvió un JSON válido.",
			COLOR_DANGER
		)
		return

	var response: Dictionary = parsed as Dictionary
	_show_recipes(response)


func _show_recipes(response: Dictionary) -> void:
	clear_children(recipes_box)

	var ship: Dictionary = _get_dictionary(
		response.get("nave", {})
	)

	ship_label.text = (
		"Nave: "
		+ str(ship.get("nombre", "Sin nombre"))
		+ " | Nivel "
		+ str(ship.get("nivel", 1))
		+ " | Energía "
		+ str(ship.get("energia_actual", 0))
		+ " / "
		+ str(ship.get("energia_maxima", 0))
		+ " | Escudo "
		+ str(ship.get("escudo_actual", 0))
		+ " / "
		+ str(ship.get("escudo_maximo", 0))
		+ " | Casco "
		+ str(ship.get("casco_actual", 0))
		+ " / "
		+ str(ship.get("casco_maximo", 0))
	)

	var raw_recipes: Variant = response.get("recetas", [])

	if typeof(raw_recipes) != TYPE_ARRAY:
		set_status(
			status_label,
			"Datos inválidos",
			COLOR_DANGER
		)
		set_footer(
			"La lista de recetas no llegó como arreglo.",
			COLOR_DANGER
		)
		return

	var recipes: Array = raw_recipes as Array

	if recipes.is_empty():
		var empty_label: Label = make_label(
			"No existen recetas disponibles para fabricar.",
			16,
			COLOR_MUTED
		)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		recipes_box.add_child(empty_label)
		set_status(status_label, "Sin recetas", COLOR_WARN)
		set_footer("El backend respondió correctamente, pero no hay recetas.")
		return

	for item: Variant in recipes:
		if typeof(item) == TYPE_DICTIONARY:
			var recipe: Dictionary = item as Dictionary
			_add_recipe_card(recipe)

	set_status(
		status_label,
		str(recipes.size()) + " recetas disponibles",
		COLOR_OK
	)
	set_footer(
		"Fabricación conectada al inventario y nave reales en Neon.",
		COLOR_OK
	)


func _add_recipe_card(recipe: Dictionary) -> void:
	var bundle: Dictionary = make_margin_panel()
	var card: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer
	card.custom_minimum_size = Vector2(0, 168)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipes_box.add_child(card)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)
	row.add_child(details)

	var title: String = str(recipe.get("nombre", "Receta sin nombre"))
	var category: String = str(recipe.get("categoria", "General"))
	var description: String = str(recipe.get("descripcion", "Sin descripción."))
	var effect: String = str(recipe.get("efecto", "Sin efecto definido."))
	var current_value: int = _to_int(recipe.get("valor_actual", 0), 0)
	var max_value: int = _to_int(recipe.get("valor_maximo", 0), 0)
	var stat_name: String = str(recipe.get("stat_nombre", "Estadística"))
	var can_craft: bool = bool(recipe.get("puede_fabricar", false))
	var max_reached: bool = bool(recipe.get("maximo_alcanzado", false))

	details.add_child(
		make_label(
			"⚙ " + title,
			20,
			COLOR_ACCENT
		)
	)

	details.add_child(
		make_label(
			category + " | " + stat_name + ": " + str(current_value) + " / " + str(max_value),
			14,
			COLOR_TEXT
		)
	)

	details.add_child(
		make_label(description, 14, COLOR_MUTED)
	)

	details.add_child(
		make_label("Efecto: " + effect, 14, COLOR_OK)
	)

	details.add_child(
		make_label(
			"Materiales: " + _materials_text(recipe),
			14,
			COLOR_MUTED
		)
	)

	var action_box: VBoxContainer = VBoxContainer.new()
	action_box.custom_minimum_size = Vector2(185, 0)
	action_box.add_theme_constant_override("separation", 8)
	row.add_child(action_box)

	var state_text: String = "Disponible"
	var state_color: Color = COLOR_OK

	if max_reached:
		state_text = "Máximo alcanzado"
		state_color = COLOR_WARN
	elif not can_craft:
		state_text = "Faltan materiales"
		state_color = COLOR_DANGER

	var state_label: Label = make_label(state_text, 14, state_color)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_box.add_child(state_label)

	var button: Button = make_button("Fabricar mejora", COLOR_OK)
	button.custom_minimum_size = Vector2(165, 42)
	button.disabled = not can_craft
	button.pressed.connect(
		_craft_recipe.bind(str(recipe.get("id", "")))
	)
	action_box.add_child(button)

	if not can_craft and not max_reached:
		var missing_label: Label = make_label(
			_missing_text(recipe),
			12,
			COLOR_DANGER
		)
		missing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action_box.add_child(missing_label)


func _craft_recipe(recipe_id: String) -> void:
	if recipe_id.strip_edges().is_empty():
		set_footer("Receta inválida.", COLOR_DANGER)
		return

	set_status(status_label, "Fabricando mejora...", COLOR_WARN)
	set_footer("Consumiendo recursos y actualizando nave en Neon...")

	var error: int = craft_request.request(
		api_url("/crafting/fabricar?receta_id=" + recipe_id.uri_encode()),
		auth_headers(),
		HTTPClient.METHOD_POST,
		""
	)

	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible enviar la orden de fabricación.", COLOR_DANGER)


func _on_craft_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "Fabricación rechazada", COLOR_DANGER)
		set_footer(_extraer_detail(text), COLOR_DANGER)
		_load_recipes()
		return

	var parsed: Variant = JSON.parse_string(text)
	var message: String = "Mejora fabricada correctamente."

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		message = str(response.get("mensaje", message))

	set_status(status_label, "Mejora aplicada", COLOR_OK)
	set_footer(message, COLOR_OK)
	_load_recipes()


func _materials_text(recipe: Dictionary) -> String:
	var raw_materials: Variant = recipe.get("materiales", [])

	if typeof(raw_materials) != TYPE_ARRAY:
		return "Sin materiales definidos"

	var materials: Array = raw_materials as Array
	var parts: Array[String] = []

	for item: Variant in materials:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var material: Dictionary = item as Dictionary
		var name: String = str(material.get("nombre", "Recurso"))
		var required: int = _to_int(material.get("cantidad", 0), 0)
		var available: int = _to_int(material.get("disponible", 0), 0)
		parts.append(name + " " + str(available) + "/" + str(required))

	return ", ".join(parts)


func _missing_text(recipe: Dictionary) -> String:
	var raw_missing: Variant = recipe.get("faltantes", [])

	if typeof(raw_missing) != TYPE_ARRAY:
		return "Faltan materiales"

	var missing: Array = raw_missing as Array
	var parts: Array[String] = []

	for item: Variant in missing:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = item as Dictionary
		parts.append(
			str(entry.get("nombre", "Recurso"))
			+ ": -"
			+ str(entry.get("faltan", 0))
		)

	if parts.is_empty():
		return "Faltan materiales"

	return ", ".join(parts)


func _get_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary

	return {}


func _extraer_detail(response_text: String) -> String:
	if response_text.strip_edges().is_empty():
		return "Error desconocido."

	var parsed: Variant = JSON.parse_string(response_text)

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		return str(response.get("detail", response_text))

	return response_text


func _to_int(value: Variant, fallback: int = 0) -> int:
	if value == null:
		return fallback

	if typeof(value) == TYPE_INT:
		return int(value)

	if typeof(value) == TYPE_FLOAT:
		return int(value)

	if typeof(value) == TYPE_STRING:
		var text: String = str(value).strip_edges()

		if text.is_valid_int():
			return text.to_int()

	return fallback

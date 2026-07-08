extends "res://galactum_screen_base.gd"

var request: HTTPRequest

var status_label: Label
var commander_label: Label
var total_label: Label
var resource_list: VBoxContainer


func _ready() -> void:
	var shell: Dictionary = build_shell(
		"INVENTARIO",
		"RECURSOS REALES ALMACENADOS EN NEON"
	)

	status_label = shell["status"] as Label

	_build_summary()
	_build_resource_list()

	request = HTTPRequest.new()
	add_child(request)

	request.request_completed.connect(_on_inventory_completed)

	finish_shell()
	_load_inventory()


func _build_summary() -> void:
	var bundle: Dictionary = make_margin_panel()

	var summary_panel: PanelContainer = bundle["panel"] as PanelContainer
	var summary_margin: MarginContainer = bundle["margin"] as MarginContainer

	summary_panel.custom_minimum_size = Vector2(0, 100)
	content_box.add_child(summary_panel)

	var summary_row: HBoxContainer = HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 16)
	summary_margin.add_child(summary_row)

	var left_column: VBoxContainer = VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 4)
	summary_row.add_child(left_column)

	commander_label = make_label(
		"Comandante: Cargando...",
		18,
		COLOR_TEXT
	)

	left_column.add_child(commander_label)

	var description_label: Label = make_label(
		"Bodega persistida en PostgreSQL / Neon.",
		14,
		COLOR_MUTED
	)

	left_column.add_child(description_label)

	total_label = make_label(
		"0 tipos | 0 unidades",
		17,
		COLOR_ACCENT
	)

	total_label.custom_minimum_size = Vector2(220, 0)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	summary_row.add_child(total_label)


func _build_resource_list() -> void:
	var section_title: Label = make_section_title(
		"BODEGA DE RECURSOS"
	)

	content_box.add_child(section_title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	content_box.add_child(scroll)

	resource_list = VBoxContainer.new()
	resource_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_list.add_theme_constant_override("separation", 12)

	scroll.add_child(resource_list)

	scroll.resized.connect(_adjust_list_width.bind(scroll))
	call_deferred("_adjust_list_width", scroll)


func _adjust_list_width(scroll: ScrollContainer) -> void:
	if not is_instance_valid(resource_list):
		return

	var available_width: float = maxf(
		0.0,
		scroll.size.x - 10.0
	)

	resource_list.custom_minimum_size = Vector2(
		available_width,
		0
	)


func _load_inventory() -> void:
	set_status(
		status_label,
		"Cargando recursos...",
		COLOR_WARN
	)

	set_footer("Consultando bodega persistida en Neon...")

	var error: int = request.request(
		api_url("/inventario/materiales"),
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


func _on_inventory_completed(
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
			"No se pudo cargar el inventario.",
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
	_show_inventory(response)


func _show_inventory(response: Dictionary) -> void:
	var raw_storage: Variant = response.get("bodega", [])

	if typeof(raw_storage) != TYPE_ARRAY:
		set_status(
			status_label,
			"Datos inválidos",
			COLOR_DANGER
		)

		set_footer(
			"La bodega no llegó como una lista.",
			COLOR_DANGER
		)

		return

	var storage: Array = raw_storage as Array

	commander_label.text = (
		"Comandante: "
		+ str(response.get("comandante", "Desconocido"))
	)

	clear_children(resource_list)

	var total_units: int = 0
	var valid_resources: int = 0

	for entry: Variant in storage:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var resource: Dictionary = entry as Dictionary
		var quantity: int = _to_int(
			resource.get("cantidad", 0),
			0
		)

		total_units += quantity
		valid_resources += 1

		_add_resource_card(resource)

	total_label.text = (
		str(valid_resources)
		+ " tipos | "
		+ _format_number(total_units)
		+ " unidades"
	)

	if valid_resources == 0:
		_add_empty_message()

		set_status(
			status_label,
			"Bodega vacía",
			COLOR_WARN
		)

		set_footer(
			"Tu inventario existe, pero todavía no contiene recursos.",
			COLOR_WARN
		)

		return

	set_status(
		status_label,
		"Bodega sincronizada",
		COLOR_OK
	)

	set_footer(
		"Inventario cargado desde PostgreSQL / Neon.",
		COLOR_OK
	)


func _add_resource_card(resource: Dictionary) -> void:
	var bundle: Dictionary = make_margin_panel()

	var card: PanelContainer = bundle["panel"] as PanelContainer
	var card_margin: MarginContainer = bundle["margin"] as MarginContainer

	card.custom_minimum_size = Vector2(0, 125)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	resource_list.add_child(card)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	card_margin.add_child(row)

	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)

	row.add_child(details)

	var resource_name: String = str(
		resource.get("recurso", "Recurso desconocido")
	)

	var quantity: int = _to_int(
		resource.get("cantidad", 0),
		0
	)

	var unit: String = str(
		resource.get("unidad", "unidades")
	)

	var title_label: Label = make_label(
		_resource_icon(resource_name)
		+ " "
		+ resource_name.to_upper(),
		19,
		COLOR_ACCENT
	)

	details.add_child(title_label)

	var separator: HSeparator = HSeparator.new()
	details.add_child(separator)

	var description_label: Label = make_label(
		_resource_description(resource_name),
		14,
		COLOR_MUTED
	)

	details.add_child(description_label)

	var quantity_box: VBoxContainer = VBoxContainer.new()
	quantity_box.custom_minimum_size = Vector2(180, 0)
	quantity_box.alignment = BoxContainer.ALIGNMENT_CENTER

	row.add_child(quantity_box)

	var quantity_label: Label = make_label(
		_format_number(quantity),
		30,
		COLOR_TEXT
	)

	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	quantity_box.add_child(quantity_label)

	var unit_label: Label = make_label(
		unit,
		14,
		COLOR_MUTED
	)

	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	quantity_box.add_child(unit_label)


func _add_empty_message() -> void:
	var message: Label = make_label(
		"No hay recursos en la bodega todavía.",
		17,
		COLOR_MUTED
	)

	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.custom_minimum_size = Vector2(0, 80)

	resource_list.add_child(message)


func _resource_icon(resource_name: String) -> String:
	var normalized_name: String = resource_name.to_lower()

	if "helio" in normalized_name:
		return "⚡"

	if "titanio" in normalized_name:
		return "◆"

	if "crédito" in normalized_name or "credito" in normalized_name:
		return "◈"

	if "litio" in normalized_name:
		return "◉"

	if "cobre" in normalized_name or "copper" in normalized_name:
		return "⬡"

	if "kliptium" in normalized_name:
		return "✦"

	if "agua" in normalized_name or "h2o" in normalized_name:
		return "◌"

	if "orgánico" in normalized_name or "organico" in normalized_name:
		return "◒"

	return "▣"


func _resource_description(resource_name: String) -> String:
	var normalized_name: String = resource_name.to_lower()

	if "helio" in normalized_name:
		return "Combustible energético para operaciones de nave."

	if "titanio" in normalized_name:
		return "Material estructural para construcción y mejoras."

	if "crédito" in normalized_name or "credito" in normalized_name:
		return "Moneda operativa del sistema."

	if "kliptium" in normalized_name:
		return "Mineral estratégico para tecnología avanzada."

	if "litio" in normalized_name:
		return "Recurso energético para sistemas de almacenamiento."

	if "cobre" in normalized_name or "copper" in normalized_name:
		return "Metal conductor para componentes electrónicos."

	if "agua" in normalized_name or "h2o" in normalized_name:
		return "Recurso esencial para soporte de tripulación."

	if "orgánico" in normalized_name or "organico" in normalized_name:
		return "Material base para suministros y bioprocesos."

	return "Material almacenado en la bodega."


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


func _format_number(number: int) -> String:
	var text: String = str(number)
	var result: String = ""
	var count: int = 0

	for index: int in range(text.length() - 1, -1, -1):
		result = text[index] + result
		count += 1

		if count % 3 == 0 and index > 0:
			result = "." + result

	return result

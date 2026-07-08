extends "res://galactum_screen_base.gd"

var request: HTTPRequest
var status_label: Label
var profile_content: VBoxContainer


func _ready() -> void:
	var shell: Dictionary = build_shell(
		"PERFIL DEL COMANDANTE",
		"RESUMEN GENERAL DEL JUGADOR"
	)
	status_label = shell["status"] as Label

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(scroll)

	profile_content = VBoxContainer.new()
	profile_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_content.add_theme_constant_override("separation", 14)
	scroll.add_child(profile_content)

	profile_content.add_child(
		make_label("Cargando resumen del comandante...", 18, COLOR_MUTED)
	)

	request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_profile_completed)

	finish_shell()
	_load_profile()


func _load_profile() -> void:
	set_status(status_label, "Consultando perfil...", COLOR_WARN)
	set_footer("Solicitando resumen consolidado al backend...")

	var error: int = request.request(
		api_url("/api/v1/player/resumen"),
		auth_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible iniciar la solicitud.", COLOR_DANGER)


func _on_profile_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "Error HTTP " + str(response_code), COLOR_DANGER)
		set_footer(_extract_error(text, response_code), COLOR_DANGER)
		return

	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		set_status(status_label, "Respuesta inválida", COLOR_DANGER)
		set_footer("El perfil no llegó en formato JSON válido.", COLOR_DANGER)
		return

	var response: Dictionary = parsed as Dictionary
	var raw_data: Variant = response.get("data", {})

	if typeof(raw_data) != TYPE_DICTIONARY:
		set_status(status_label, "Datos inválidos", COLOR_DANGER)
		set_footer("El backend no devolvió el bloque data esperado.", COLOR_DANGER)
		return

	var data: Dictionary = raw_data as Dictionary
	_show_profile(data)


func _show_profile(data: Dictionary) -> void:
	clear_children(profile_content)

	var usuario: Dictionary = _dict(data.get("usuario", {}))
	var jugador: Dictionary = _dict(data.get("jugador", {}))
	var alianza: Dictionary = _dict(data.get("alianza", {}))
	var nave: Dictionary = _dict(data.get("nave", {}))
	var inventario: Dictionary = _dict(data.get("inventario", {}))
	var misiones: Dictionary = _dict(data.get("misiones", {}))
	var tripulacion: Dictionary = _dict(data.get("tripulacion", {}))
	var combates: Dictionary = _dict(data.get("combates", {}))
	var solicitudes: Dictionary = _dict(data.get("solicitudes_alianza", {}))

	_add_identity_card(usuario, jugador, alianza)

	profile_content.add_child(make_section_title("RESUMEN OPERATIVO"))

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	profile_content.add_child(grid)

	_add_stat_card(grid, "Poder", str(jugador.get("poder", 0)), "Poder base del comandante")
	_add_stat_card(grid, "Nave", str(nave.get("nombre", "Sin nave")), "Nivel " + str(nave.get("nivel", 0)))
	_add_stat_card(grid, "Inventario", str(inventario.get("total_unidades", 0)), str(inventario.get("total_tipos", 0)) + " tipo(s) de recurso")
	_add_stat_card(grid, "Misiones", str(misiones.get("reclamadas", 0)), "Reclamadas / " + str(misiones.get("total", 0)) + " totales")
	_add_stat_card(grid, "Tripulación", str(tripulacion.get("total", 0)), "Tripulantes registrados")
	_add_stat_card(grid, "Combates", str(combates.get("victorias", 0)), "Victorias / " + str(combates.get("total", 0)) + " combates")

	_add_ship_card(nave)
	_add_inventory_card(inventario)
	_add_missions_card(misiones)
	_add_alliance_card(alianza, solicitudes)

	set_status(status_label, "Perfil sincronizado", COLOR_OK)
	set_footer("Resumen generado desde FastAPI y Neon.", COLOR_OK)


func _add_identity_card(usuario: Dictionary, jugador: Dictionary, alianza: Dictionary) -> void:
	var bundle: Dictionary = make_margin_panel()
	var panel: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer
	panel.custom_minimum_size.y = 118
	profile_content.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	box.add_child(make_label("COMANDANTE " + str(jugador.get("nickname", "Sin nombre")).to_upper(), 25, COLOR_ACCENT))
	box.add_child(make_label("Correo: " + str(usuario.get("email", "Sin correo")), 15, COLOR_MUTED))
	box.add_child(make_label("ID jugador: " + str(jugador.get("id", "-")) + "  |  Usuario: " + str(usuario.get("username", "-")), 15))
	box.add_child(make_label("Alianza: " + str(alianza.get("nombre", "Sin alianza")) + "  |  Rol: " + str(alianza.get("rol", "Sin alianza")), 15, COLOR_OK if bool(alianza.get("pertenece", false)) else COLOR_WARN))


func _add_stat_card(grid: GridContainer, title: String, value: String, detail: String) -> void:
	var bundle: Dictionary = make_margin_panel()
	var card: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer
	card.custom_minimum_size = Vector2(0, 112)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(card)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	box.add_child(make_label(title.to_upper(), 14, COLOR_MUTED))
	box.add_child(make_label(value, 22, COLOR_ACCENT))
	box.add_child(make_label(detail, 14, COLOR_TEXT))


func _add_ship_card(nave: Dictionary) -> void:
	profile_content.add_child(make_section_title("NAVE ASIGNADA"))
	var bundle: Dictionary = make_margin_panel()
	var panel: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer
	profile_content.add_child(panel)

	var text: String = (
		"Nave: " + str(nave.get("nombre", "Sin nave")) + "\n"
		+ "Nivel: " + str(nave.get("nivel", 0)) + "\n"
		+ "Energía: " + str(nave.get("energia", "0 / 0")) + "\n"
		+ "Escudo: " + str(nave.get("escudo", "0 / 0")) + "\n"
		+ "Casco: " + str(nave.get("casco", "0 / 0")) + "\n"
		+ "Posición: " + str(nave.get("posicion", "X 0 | Y 0")) + "\n"
		+ "Estado: " + str(nave.get("estado_movimiento", "Sin datos"))
	)
	margin.add_child(make_label(text, 16))


func _add_inventory_card(inventario: Dictionary) -> void:
	profile_content.add_child(make_section_title("RECURSOS PRINCIPALES"))
	var bundle: Dictionary = make_margin_panel()
	var panel: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer
	profile_content.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var recursos: Array = []
	var raw: Variant = inventario.get("recursos_principales", [])
	if typeof(raw) == TYPE_ARRAY:
		recursos = raw as Array

	if recursos.is_empty():
		box.add_child(make_label("No hay recursos registrados en inventario.", 15, COLOR_WARN))
		return

	for item_value: Variant in recursos:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value as Dictionary
		box.add_child(make_label("• " + str(item.get("nombre", "Recurso")) + ": " + str(item.get("cantidad", 0)) + " unidades", 15))


func _add_missions_card(misiones: Dictionary) -> void:
	profile_content.add_child(make_section_title("ESTADO DE MISIONES"))
	var bundle: Dictionary = make_margin_panel()
	var margin: MarginContainer = bundle["margin"] as MarginContainer
	profile_content.add_child(bundle["panel"] as PanelContainer)
	margin.add_child(make_label("Activas: " + str(misiones.get("activas", 0)) + "  |  Completadas: " + str(misiones.get("completadas", 0)) + "  |  Reclamadas: " + str(misiones.get("reclamadas", 0)), 16))


func _add_alliance_card(alianza: Dictionary, solicitudes: Dictionary) -> void:
	profile_content.add_child(make_section_title("ALIANZA"))
	var bundle: Dictionary = make_margin_panel()
	var margin: MarginContainer = bundle["margin"] as MarginContainer
	profile_content.add_child(bundle["panel"] as PanelContainer)

	var text: String = "Sin alianza actual."
	if bool(alianza.get("pertenece", false)):
		text = (
			str(alianza.get("nombre", "Alianza")) + " [" + str(alianza.get("tag", "---")) + "]\n"
			+ "Rol: " + str(alianza.get("rol", "Miembro")) + "\n"
			+ "Miembros: " + str(alianza.get("miembros", 0)) + "/" + str(alianza.get("miembros_maximos", 0)) + "\n"
			+ "Solicitudes pendientes como líder: " + str(solicitudes.get("pendientes_como_lider", 0))
		)
	margin.add_child(make_label(text, 16))


func _dict(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}


func _extract_error(response_text: String, response_code: int) -> String:
	var parsed: Variant = JSON.parse_string(response_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		if response.has("detail"):
			return str(response["detail"])
	return "Error HTTP " + str(response_code)

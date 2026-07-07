extends "res://galactum_screen_base.gd"

var label_comandante: Label
var label_alianza: Label

func _ready():
	var shell := build_shell("GALACTUM", "CENTRO DE MANDO", false)
	var status: Label = shell["status"]
	set_status(status, "Sesión activa", COLOR_OK)

	var info_bundle := make_margin_panel()
	var info_panel: PanelContainer = info_bundle["panel"]
	var info_margin: MarginContainer = info_bundle["margin"]
	info_panel.custom_minimum_size.y = 112
	content_box.add_child(info_panel)

	var info_box := HBoxContainer.new()
	info_margin.add_child(info_box)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	info_box.add_child(left)

	label_comandante = make_label("Comandante: Cargando...", 20)
	label_alianza = make_label("Alianza: Cargando...", 15, COLOR_MUTED)
	left.add_child(label_comandante)
	left.add_child(label_alianza)

	var btn_profile := make_button("Perfil", COLOR_PANEL_ALT)
	btn_profile.custom_minimum_size = Vector2(116, 38)
	btn_profile.pressed.connect(_open_profile)
	info_box.add_child(btn_profile)

	content_box.add_child(make_section_title("MÓDULOS DEL SIMULADOR"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)

	_add_module(grid, "ALIANZAS", "Buscar, crear y gestionar", "res://menu_busqueda.tscn")
	_add_module(grid, "MI NAVE", "Estado operativo y navegación", "res://mi_nave.tscn")
	_add_module(grid, "INVENTARIO", "Recursos almacenados", "res://inventario.tscn")
	_add_module(grid, "TRIPULACIÓN", "Gestión de unidades", "res://gestion_tripulacion.tscn")
	_add_module(grid, "MAPA GALÁCTICO", "Exploración de sectores", "res://mapa_galactico.tscn")
	_add_module(grid, "MISIONES", "Operaciones disponibles", "res://misiones.tscn")
	_add_module(grid, "MINERÍA", "Asteroides y extracción", "res://mineria.tscn")
	_add_module(grid, "CONFLICTOS", "Operaciones de combate", "res://conflictos.tscn")
	_add_module(grid, "TORNEOS", "Módulo planificado", "", true)

	var btn_exit := make_button("Cerrar sesión", COLOR_DANGER)
	btn_exit.custom_minimum_size.y = 36
	btn_exit.pressed.connect(_logout)
	content_box.add_child(btn_exit)

	finish_shell()
	_load_user_info()


func _add_module(grid: GridContainer, title: String, description: String, path: String, disabled: bool = false):
	var card_bundle := make_margin_panel()
	var card: PanelContainer = card_bundle["panel"]
	var margin: MarginContainer = card_bundle["margin"]
	card.custom_minimum_size.y = 126
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	box.add_child(make_label(title, 18, COLOR_ACCENT))
	box.add_child(make_label(description, 14, COLOR_MUTED))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var button := make_button("Abrir", COLOR_PANEL_ALT)
	button.disabled = disabled
	button.text = "Próximamente" if disabled else "Abrir"
	if not disabled:
		button.pressed.connect(_go_to_scene.bind(path))
	box.add_child(button)


func _load_user_info():
	var nombre := str(APIManager.usuario_actual.get("nombre", APIManager.usuario_actual.get("username", "Comandante")))
	var poder := str(APIManager.usuario_actual.get("poder", 0))
	var alliance_id = APIManager.usuario_actual.get("alliance_id", null)
	label_comandante.text = "Comandante: " + nombre + "   |   Poder: " + poder
	if alliance_id == null or str(alliance_id) == "" or str(alliance_id) == "0":
		label_alianza.text = "Alianza: Sin alianza actual"
	else:
		label_alianza.text = "Alianza: Vinculado a una alianza"


func _go_to_scene(path: String):
	get_tree().change_scene_to_file(path)


func _open_profile():
	get_tree().change_scene_to_file("res://perfil_comandante.tscn")


func _logout():
	APIManager.token_jwt = ""
	APIManager.usuario_actual = {}
	get_tree().change_scene_to_file("res://menu_login.tscn")

extends Control

var TarjetaAlianzaEscena = preload("res://tarjeta_alianza.tscn")
var MapaGalacticoEscena = preload("res://mapa_galactico.tscn")

@onready var input_busqueda = $VBoxContainer/HBoxContainer/LineEdit
@onready var btn_buscar = $VBoxContainer/HBoxContainer/Button
@onready var http_request = $HTTPRequest
@onready var contenedor_lista = $VBoxContainer/ScrollContainer/VBoxContainer
@onready var label_saludo = $VBoxContainer/Header/HBoxContainer/Label_Saludo
@onready var button_salir = $VBoxContainer/Header/HBoxContainer/Button_Salir
@onready var btn_mapa = $VBoxContainer/Header/HBoxContainer/Button_Mapa
# 1. NUEVA VARIABLE: Guardará lo que el usuario escribió para usarlo cuando el servidor responda (o falle).
var ultima_busqueda: String = ""
func _ready():
	btn_buscar.pressed.connect(_on_btn_buscar_pressed)
	http_request.request_completed.connect(_on_request_completed)
	btn_mapa.pressed.connect(_on_btn_mapa_pressed)
	
	# Conectamos el botón de cerrar sesión
	button_salir.pressed.connect(_on_btn_salir_pressed)
	
	# Verificamos si el APIManager tiene los datos de nuestro usuario
	if APIManager.usuario_actual.has("nombre"):
		var nombre = APIManager.usuario_actual["nombre"]
		var poder = str(APIManager.usuario_actual["poder"])
		# Formateamos un saludo genial
		label_saludo.text = "🧑‍🚀 Comandante: " + nombre + " | ⚡ Poder: " + poder
	else:
		label_saludo.text = "⚠️ Sesión no detectada."

func _on_btn_buscar_pressed():
	# 2. Guardamos el texto y lo convertimos a minúsculas (.to_lower()) para que la búsqueda no falle por mayúsculas
	ultima_busqueda = input_busqueda.text.to_lower()
	print("Buscando: ", ultima_busqueda)
	
	for hijo in contenedor_lista.get_children():
		hijo.queue_free()
	
	var url = APIManager.base_url + "/api/v1/alianzas/buscar?search=" + ultima_busqueda
	var headers = APIManager.get_auth_headers()
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		print("Error al iniciar solicitud HTTP.")

func _on_request_completed(result, response_code, headers, body):
	var lista_alianzas = []
	
	if response_code == 200:
		var json_recibido = JSON.parse_string(body.get_string_from_utf8())
		lista_alianzas = json_recibido["alianzas"] 
	elif response_code == 0:
		print("Servidor apagado. Generando datos de prueba y filtrando...")
		
		# 3. Guardamos la lista completa en una variable temporal
		var mock_db = [
			{"id": 1, "nombre": "Striker Force", "nivel": 12, "miembros_actuales": 67, "miembros_maximos": 100, "poder_total": "4.2M", "region": "ES", "req_poder": 500000},
			{"id": 2, "nombre": "Nova Vanguard", "nivel": 8, "miembros_actuales": 45, "miembros_maximos": 100, "poder_total": "2.1M", "region": "EN", "req_poder": 200000},
			{"id": 3, "nombre": "Legión Cósmica", "nivel": 15, "miembros_actuales": 100, "miembros_maximos": 100, "poder_total": "9.5M", "region": "ES", "req_poder": 1000000}
		]
		
		# 4. LA MAGIA DEL FILTRADO:
		if ultima_busqueda == "":
			# Si el jugador presionó "Buscar" con la barra vacía, mostramos todas
			lista_alianzas = mock_db
		else:
			# Si escribió algo, revisamos una por una
			for alianza in mock_db:
				# Convertimos el nombre de la alianza a minúsculas y vemos si contiene lo que escribimos
				if ultima_busqueda in alianza["nombre"].to_lower():
					lista_alianzas.append(alianza)
	
	# Finalmente, creamos las tarjetas con la lista filtrada
	for datos in lista_alianzas:
		var nueva_tarjeta = TarjetaAlianzaEscena.instantiate()
		contenedor_lista.add_child(nueva_tarjeta)
		nueva_tarjeta.configurar_tarjeta(datos)

func _on_btn_salir_pressed():
	# Borramos los datos para que no queden guardados
	APIManager.usuario_actual = {}
	APIManager.token_jwt = ""
	
	# Lo devolvemos a la pantalla de login
	get_tree().change_scene_to_file("res://menu_login.tscn")

func _on_btn_mapa_pressed():
	var nuevo_mapa = MapaGalacticoEscena.instantiate()
	# Lo añadimos a la escena actual para que aparezca por encima
	get_tree().current_scene.add_child(nuevo_mapa)

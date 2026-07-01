extends Control

# 1. Cargamos la escena de la tarjeta que acabas de crear (nuestra "plantilla")
var TarjetaAlianzaEscena = preload("res://tarjeta_alianza.tscn")

# 2. Referencias a los nodos
@onready var input_busqueda = $VBoxContainer/HBoxContainer/LineEdit
@onready var btn_buscar = $VBoxContainer/HBoxContainer/Button
@onready var http_request = $HTTPRequest
@onready var contenedor_lista = $VBoxContainer/ScrollContainer/VBoxContainer # Aquí inyectaremos las tarjetas

func _ready():
	btn_buscar.pressed.connect(_on_btn_buscar_pressed)
	http_request.request_completed.connect(_on_request_completed)
	
	# Creamos una variable de poder temporal en el APIManager solo para probar
	APIManager.set("poder_jugador", 300000) # El jugador tiene 300k de poder

func _on_btn_buscar_pressed():
	var texto_buscado = input_busqueda.text
	print("Buscando: ", texto_buscado)
	
	# Limpiamos la lista anterior antes de mostrar nuevos resultados
	for hijo in contenedor_lista.get_children():
		hijo.queue_free()
	
	var url = APIManager.base_url + "/api/v1/alianzas/buscar?nombre=" + texto_buscado
	var headers = APIManager.get_auth_headers()
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		print("Error al iniciar solicitud HTTP.")

func _on_request_completed(result, response_code, headers, body):
	var lista_alianzas = []
	
	if response_code == 200:
		# Si el backend funciona, usamos los datos reales
		var json_recibido = JSON.parse_string(body.get_string_from_utf8())
		lista_alianzas = json_recibido["alianzas"] 
	elif response_code == 0:
		# TRUCO FRONTEND: Datos falsos si el backend está apagado
		print("Servidor apagado. Generando datos de prueba...")
		lista_alianzas = [
			{"id": 1, "nombre": "Striker Force", "nivel": 12, "miembros_actuales": 67, "miembros_maximos": 100, "poder_total": "4.2M", "region": "ES", "req_poder": 500000},
			{"id": 2, "nombre": "Nova Vanguard", "nivel": 8, "miembros_actuales": 45, "miembros_maximos": 100, "poder_total": "2.1M", "region": "EN", "req_poder": 200000},
			{"id": 3, "nombre": "Legión Cósmica", "nivel": 15, "miembros_actuales": 100, "miembros_maximos": 100, "poder_total": "9.5M", "region": "ES", "req_poder": 1000000}
		]
	
	# 3. El ciclo mágico: Clonar la tarjeta por cada alianza en la lista
	for datos in lista_alianzas:
		var nueva_tarjeta = TarjetaAlianzaEscena.instantiate() # Clonamos la escena
		contenedor_lista.add_child(nueva_tarjeta)              # La metemos al ScrollContainer
		nueva_tarjeta.configurar_tarjeta(datos)                # Le inyectamos los datos

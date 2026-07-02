extends Control

# Referencias a los nodos
@onready var btn_volver = $Boton_Volver
@onready var linea_ruta = $Area_Radar/Linea_Ruta
@onready var icono_jugador = $Area_Radar/Icono_Jugador
@onready var icono_alianza = $Area_Radar/Icono_Alianza

func _ready():
	# Conectamos el botón para salir del mapa
	btn_volver.pressed.connect(_on_btn_volver_pressed)
	
	# Llamamos a la función mágica para dibujar la ruta láser
	_dibujar_ruta_laser()

func _dibujar_ruta_laser():
	# Limpiamos cualquier punto anterior por si acaso
	linea_ruta.clear_points()
	
	# Calculamos el centro exacto de ambos iconos
	var centro_jugador = icono_jugador.position + (icono_jugador.size / 2.0)
	var centro_alianza = icono_alianza.position + (icono_alianza.size / 2.0)
	
	# Le decimos a la Linea2D que conecte el Punto A con el Punto B
	linea_ruta.add_point(centro_jugador)
	linea_ruta.add_point(centro_alianza)
	
	# Toque visual: Hacemos que la línea sea de un color cian brillante por código
	linea_ruta.default_color = Color(0.0, 1.0, 1.0, 0.5) 
	linea_ruta.width = 3.0

func _on_btn_volver_pressed():
	# Cierra el mapa y vuelve a la pantalla anterior
	queue_free()

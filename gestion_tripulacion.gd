extends Control

# Referencias del Lado Derecho (Detalles)
@onready var label_nombre = $HBoxContainer_Principal/Panel_Detalles/VBoxContainer/Label_Nombre
@onready var label_lore = $HBoxContainer_Principal/Panel_Detalles/VBoxContainer/Label_Lore
# (Asegúrate de arrastrar tus Labels de estadísticas aquí si les pusiste otro nombre)

# Referencias del Lado Izquierdo (Lista)
@onready var grid_personajes = $HBoxContainer_Principal/Panel_Lista/ScrollContainer/GridContainer_Personajes
@onready var btn_volver = $MarginContainer/Button_Volver

# Mock Data: Base de datos falsa de la tripulación
var base_datos_tripulacion = {
	"kael": {
		"nombre": "Comandante Kael",
		"lore": "Experto en tácticas de asalto y liderazgo en situaciones de gravedad cero. No suele retroceder ante el fuego enemigo.",
		"stats": "⚔️ Fuerza Física: 8  |  🔮 Magia: 2  |  🛡️ Resistencia: 7"
	},
	"aris": {
		"nombre": "Dra. Aris Thorne",
		"lore": "Especialista en biotecnología. Sus investigaciones en control mental han salvado a la alianza en múltiples ocasiones.",
		"stats": "⚔️ Fuerza Física: 3  |  🔮 Magia: 9  |  🧠 Control Mental: 8"
	}
}

func _ready():
	# Conectamos el botón de volver (puedes programar luego a qué escena regresa)
	btn_volver.pressed.connect(_on_btn_volver_pressed)
	
	# Generamos los botones de los personajes dinámicamente en el GridContainer
	_crear_botones_personajes()
	
	# Cargamos a Kael por defecto al abrir la pantalla
	_mostrar_detalles("kael")

func _crear_botones_personajes():
	# Limpiamos el contenedor por si acaso
	for hijo in grid_personajes.get_children():
		hijo.queue_free()
		
	# Creamos un botón por cada personaje en nuestra base de datos
	for id_personaje in base_datos_tripulacion.keys():
		var btn_personaje = Button.new()
		btn_personaje.text = base_datos_tripulacion[id_personaje]["nombre"]
		btn_personaje.custom_minimum_size = Vector2(150, 50) # Tamaño base para el botón
		
		# Conectamos el clic del botón a nuestra función, pasándole el ID del personaje
		btn_personaje.pressed.connect(func(): _mostrar_detalles(id_personaje))
		
		grid_personajes.add_child(btn_personaje)

func _mostrar_detalles(id_personaje: String):
	var datos = base_datos_tripulacion[id_personaje]
	
	label_nombre.text = datos["nombre"]
	label_lore.text = datos["lore"]
	
	# Aquí puedes actualizar tus labels específicos de estadísticas. 
	# Por simplicidad en el prototipo, lo puse todo en el lore o en un label general.
	print("Mostrando a: " + datos["nombre"] + " - " + datos["stats"])

func _on_btn_volver_pressed():
	queue_free() # Destruye esta pantalla para revelar la anterior

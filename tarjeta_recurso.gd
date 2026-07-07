extends PanelContainer


@onready var label_icono = $MarginContainer/VBoxContainer/HBoxContainer_Cabecera/Label_Icono
@onready var label_recurso = $MarginContainer/VBoxContainer/HBoxContainer_Cabecera/Label_Recurso
@onready var label_cantidad = $MarginContainer/VBoxContainer/Label_Cantidad
@onready var label_unidad = $MarginContainer/VBoxContainer/Label_Unidad
@onready var label_descripcion = $MarginContainer/VBoxContainer/Label_Descripcion


func configurar_recurso(datos_recurso: Dictionary):
	var nombre_recurso = str(datos_recurso.get("recurso", "Recurso desconocido"))
	var cantidad = _convertir_a_entero(datos_recurso.get("cantidad"), 0)
	var unidad = str(datos_recurso.get("unidad", "unidades"))

	label_icono.text = _obtener_icono(nombre_recurso)
	label_recurso.text = nombre_recurso.to_upper()
	label_cantidad.text = _formatear_numero(cantidad)
	label_unidad.text = unidad
	label_descripcion.text = _obtener_descripcion(nombre_recurso)


func _obtener_icono(nombre_recurso: String) -> String:
	var nombre = nombre_recurso.to_lower()

	if "helio" in nombre:
		return "⚡"

	if "titanio" in nombre:
		return "◆"

	if "crédito" in nombre or "credito" in nombre:
		return "◈"

	if "litio" in nombre:
		return "◉"

	if "cobre" in nombre:
		return "⬡"

	if "kliptium" in nombre:
		return "✦"

	return "▣"


func _obtener_descripcion(nombre_recurso: String) -> String:
	var nombre = nombre_recurso.to_lower()

	if "helio" in nombre:
		return "Combustible energético para operaciones de nave."

	if "titanio" in nombre:
		return "Material estructural para construcción y mejoras."

	if "crédito" in nombre or "credito" in nombre:
		return "Moneda operativa utilizada en el sistema."

	if "litio" in nombre:
		return "Material utilizado en sistemas de energía."

	if "cobre" in nombre:
		return "Recurso conductivo para componentes electrónicos."

	if "kliptium" in nombre:
		return "Mineral estratégico de alto valor galáctico."

	return "Material almacenado en la bodega."


func _formatear_numero(numero: int) -> String:
	var texto = str(numero)
	var resultado = ""
	var contador = 0

	for i in range(texto.length() - 1, -1, -1):
		resultado = texto[i] + resultado
		contador += 1

		if contador % 3 == 0 and i > 0:
			resultado = "." + resultado

	return resultado


func _convertir_a_entero(valor, valor_por_defecto: int = 0) -> int:
	if valor == null:
		return valor_por_defecto

	if typeof(valor) == TYPE_INT:
		return valor

	if typeof(valor) == TYPE_FLOAT:
		return int(valor)

	if typeof(valor) == TYPE_STRING:
		var texto = str(valor).strip_edges()

		if texto.is_valid_int():
			return texto.to_int()

	return valor_por_defecto

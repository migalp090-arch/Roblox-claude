--!strict
-- Datos por defecto de cada jugador. Al añadir un campo aquí, los jugadores existentes
-- lo reciben automáticamente al cargar (TableUtil.Reconcile).
-- Si cambias el significado de un campo existente, sube Version y añade una migración en DataService.

return {
	Version = 1,
}

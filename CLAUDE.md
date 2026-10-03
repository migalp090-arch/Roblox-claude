# Reglas del proyecto

Juego de Roblox en Luau con Rojo. Responde siempre en español, de forma breve y directa.

## Antes de cambiar código
- Lee `docs/ARQUITECTURA.md` y revisa si ya existe un sistema reutilizable. No dupliques funcionalidades.
- Cambia solo los archivos necesarios. No borres código del que dependan otros sistemas.
- Si un cambio afecta a varios sistemas, avisa antes de hacerlo.
- No crees sistemas (tienda, misiones, Game Passes…) hasta que el diseño los necesite.

## Convenciones
- Servidor: un ModuleScript por sistema en `src/server/Services/` con `Init` (sin esperas) y `Start`.
- Cliente: igual en `src/client/Controllers/`.
- Red: todos los remotos en `src/shared/Net/Definitions.luau`; Cliente → Servidor siempre con `args` y `rateLimit`. Usa `NetService` / `Net`, nunca RemoteEvents sueltos.
- Datos: campos nuevos en `DataTemplate`; modificar solo con `DataService:Set` / `:Increment`.
- Servidor autoritativo: dinero, daño, XP, inventario, compras y construcción se validan en el servidor.
- Rendimiento: nada pesado por frame, no conectar eventos repetidamente, limpiar conexiones al salir el jugador.
- `--!strict` en todos los archivos. Formato con StyLua, lint con Selene.

## Al terminar una tarea
- Actualiza `docs/ESTADO.md` (y `docs/DISENO.md` si cambió una decisión).
- Resume: qué se creó o cambió, archivos tocados, qué queda pendiente y qué comprobar en Studio.

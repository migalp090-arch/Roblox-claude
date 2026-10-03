# Arquitectura

## Dónde va cada cosa

| Carpeta en el repo | En Roblox Studio | Qué contiene |
|---|---|---|
| `src/server/` | `ServerScriptService.Server` | Lógica del servidor. `Services/` = un ModuleScript por sistema. |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` | Lógica del jugador. `Controllers/` = un ModuleScript por sistema. |
| `src/shared/` | `ReplicatedStorage.Shared` | Código y configuración que usan ambos lados. |
| (project.json) | `ReplicatedStorage.Assets` | Modelos y recursos que el cliente puede ver. |
| (project.json) | `ServerStorage.Assets` | Recursos que solo usa el servidor (el cliente no los ve). |
| (project.json) | `StarterGui.MainGui` | ScreenGui principal; las pantallas cuelgan de aquí (`UIController:GetRoot()`). |
| (project.json) | `Workspace.Map` | Mapa y decorado estático. |
| (project.json) | `Workspace.Spawns` | Puntos de aparición. |
| (project.json) | `Workspace.Runtime` | Objetos que crea el servidor durante la partida. |

Mapas, modelos y UI hechos a mano en Studio siguen viviendo en el archivo del juego (`.rbxl`), no en Git.
Cuando necesitemos guardarlos en el repo los exportaremos como modelos (`.rbxm`) en `assets/`.

## Servicios y controladores

Cada servicio (servidor) o controlador (cliente) es un ModuleScript con dos funciones opcionales:

- `Init()`: preparación. Se llama en todos antes de arrancar ninguno. No debe esperar (sin `task.wait`, sin llamadas a DataStore).
- `Start()`: arranca el sistema. Cada uno corre en su propio hilo.

`Shared/Util/Loader` los carga automáticamente: añadir un sistema nuevo = crear un archivo en `Services/` o `Controllers/`.
Para usar otro sistema, se hace `require` directo: `local DataService = require(script.Parent.DataService)`.

## Red (seguridad)

- Todos los remotos se declaran en `src/shared/Net/Definitions.luau`. El servidor los crea; nadie crea RemoteEvents a mano.
- Servidor: `NetService:On(nombre, handler)` para escuchar, `NetService:Fire(nombre, jugador, ...)` para avisar.
- Cliente: `Net.Fire`, `Net.Invoke`, `Net.On` (en `src/client/Net.luau`).
- Cada remoto Cliente → Servidor **debe** declarar `args` (un validador por argumento) y `rateLimit`. NetService descarta en silencio lo que no cumpla.
- El cliente nunca dice "tengo 100 monedas" o "he hecho 50 de daño": pide una acción ("quiero colocar esta pieza aquí") y el servidor comprueba si es posible.

## Datos del jugador

- `src/shared/Config/DataTemplate.luau`: datos por defecto. Añadir un campo aquí lo añade a todos los jugadores.
- Servidor: `DataService:Get`, `:Set`, `:Increment`, `:OnLoaded`, `:WaitForData`. `Set` e `Increment` avisan al cliente.
- Cliente: `DataController:Get`, `:OnChanged`, `:OnReady` (solo lectura).
- Bloqueo de sesión, reintentos, autoguardado cada 60 s (solo si hay cambios) y guardado al salir y al cerrar el servidor.

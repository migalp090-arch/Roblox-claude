# Egg Lab

Código del juego en Luau, sincronizado con Roblox Studio mediante [Rojo](https://rojo.space).

Ahora el juego es un **ajedrez 1v1** (ver `docs/ESTADO.md`).

- Empezar: [docs/INSTALACION.md](docs/INSTALACION.md)
- Diseño del juego: [docs/DISENO.md](docs/DISENO.md)
- Cómo está organizado el código: [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md)
- Estado actual: [docs/ESTADO.md](docs/ESTADO.md)

```
src/
  server/   -> ServerScriptService.Server       (Services/: lógica del servidor)
  client/   -> StarterPlayerScripts.Client      (Controllers/: lógica del jugador)
  shared/   -> ReplicatedStorage.Shared         (Net/, Config/, Util/)
```

Definidos en `default.project.json`: `ReplicatedStorage.Assets`, `ServerStorage.Assets`,
`StarterGui.MainGui` y las carpetas `Workspace.Map`, `Workspace.Spawns`, `Workspace.Runtime`.

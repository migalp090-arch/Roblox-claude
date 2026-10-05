# Estado del desarrollo

## Hecho
- Estructura Rojo + herramientas (Rokit, Selene, StyLua).
- Cargador de servicios/controladores, NetService (remotos validados y con límite de uso), DataService / DataController.
- **Ajedrez 1v1 completo** (ver `ARQUITECTURA.md`, sección Ajedrez):
  - Motor de reglas (`Shared/Chess/Rules`): movimientos legales, jaque, mate, ahogado, enroque, captura al paso, promoción, tablas (acuerdo, triple repetición, 50 jugadas, material insuficiente), notación en español. Probado con perft (6 posiciones de referencia) y partidas de prueba.
  - `MatchService` (servidor autoritativo): asientos, turnos, relojes 10+5 con incremento, validación de cada jugada, abandono, tiempo, desconexión, ofertas de tablas, revancha con colores alternados.
  - Escena (`SceneService` + `SceneBuilder`): peana de madera, marco con coordenadas, 64 casillas (mármol / madera), bandejas de capturas, suelo, focos con sombras suaves, atmósfera, bloom y corrección de color, motas de polvo.
  - 32 piezas 3D por código (`PieceFactory`): perfiles de revolución, collarines dorados, almenas, corona, cruz, caballo modelado con crin dorada (~25-50 partes por pieza).
  - Cliente: `BoardController` (animaciones: arco, captura a la bandeja, enroque, promoción con destello, rey que cae en mate), `CameraController` (3 vistas, giro y zoom limitados, encuadre adaptable), `InputController` (clic/toque), `ChessUIController` (relojes, jugadores, capturas, historial, sala de espera, promoción, tablas, abandonar con confirmación, pantalla de resultado, PC y móvil), `EffectsController` (sonidos y partículas).
- Coins (heredado) queda oculto con `GameConfig.ShowCoins = false`.

## Siguiente
- Probar en Studio (lista en "Qué comprobar en Studio") y ajustar a gusto: materiales, luces, sonidos (`AudioConfig`).
- Opcional: modo contra IA, ranking/ELO, varios tableros por servidor, guardar estadísticas con DataService.

## Pendiente / limitaciones conocidas
- Todo el código se ha escrito y comprobado fuera de Studio (tipos con luau-lsp, reglas y servidor con pruebas en Luau puro). **No se ha ejecutado dentro de Roblox Studio**: hay que revisar el aspecto de piezas, luces y UI allí.
- Sonidos: se usan los `rbxasset://sounds/` incluidos en el cliente (suenan discretos pero genéricos). Para sonidos propios, sube audios y cambia los Id en `Shared/Config/AudioConfig.luau`.
- Los símbolos de ajedrez de la UI (♟♞♝♜♛♚) dependen de la fuente de reserva de Roblox; si se ven como cuadrados, cambia `GLYPH` en `ChessUIController` por letras.
- Un solo tablero por servidor (los demás jugadores espectan). Sin materiales PBR con texturas (`SurfaceAppearance` necesita imágenes subidas): se usan los materiales integrados (Marble, Slate, Wood, Metal).
- El chat y la lista de jugadores de Roblox se ocultan para no tapar la interfaz (`UIController`).
- El motor de repetición y reloj no guardan nada en DataStore (las partidas no se persisten).

## Qué comprobar en Studio
1. Play (1 jugador): aparece la sala de espera; "Practicar solo (Studio)" arranca una partida con un solo jugador.
2. Test de 2 jugadores (Test → Local Server, 2 jugadores): cada uno elige un bando, la cámara cambia a su lado.
3. Mover todas las piezas, enroque, captura al paso, promoción, jaque (aro rojo + sonido), mate (rey cae, pantalla de resultado), ahogado, tablas, abandono, revancha.
4. Output sin errores ni avisos.
5. Vistas de cámara (teclas 1/2/3, R reinicia), giro con arrastre, zoom con rueda / pellizco.
6. Emulador móvil (retrato y apaisado): interfaz de barras, historial con botón "Jugadas".
7. Aspecto: caballos, brillo del mármol/pizarra, intensidad de luces (`SceneBuilder.buildLights`), niveles de gráficos bajos.

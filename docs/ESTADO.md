# Estado del desarrollo

## Hecho
- Estructura Rojo + herramientas (Rokit, Selene, StyLua).
- Cargador de servicios/controladores.
- NetService: remotos declarados en un sitio, validación de argumentos y límite de uso.
- DataService / DataController: guardado seguro del progreso.
- Coins: CurrencyService (AddCoins / SpendCoins / GetCoins, solo servidor, en memoria) + CoinsController (contador en pantalla).
- Estructura de Egg Lab: Assets (Replicated/ServerStorage), StarterGui.MainGui + UIController, carpetas de Workspace.

## Siguiente
- Elegir la dirección del juego (ver `DISENO.md`, sección 3).
- Primer sistema jugable del MVP.

## Pendiente
- Guardar las Coins con DataService (ahora se pierden al salir).

## Problemas conocidos
- Ninguno todavía. El código aún no se ha probado dentro de Roblox Studio.

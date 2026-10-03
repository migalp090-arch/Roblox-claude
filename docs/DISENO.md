# Egg Lab: documento de diseño (vivo)

Este documento se actualiza a medida que decidimos cosas. Lo marcado como **Propuesta** aún no está decidido.

## 1. Visión

Juego de **acción + construcción + progresión** para PC y móvil. Sin cerrar género todavía.
Objetivos: fácil de entender en el primer minuto, progresión clara, buena retención y fácil de ampliar.

## 2. Bucle principal (Propuesta)

```
Conseguir recursos (explorar / combatir)
        ↓
Construir y mejorar (base, defensas, herramientas)
        ↓
Superar retos más duros (enemigos, oleadas, jefes, zonas nuevas)
        ↓
Recompensas y desbloqueos (XP, nivel, piezas, armas)  →  vuelta al inicio
```

## 3. Direcciones posibles para el gancho principal

Las tres usan el mismo bucle; cambia qué pone a prueba lo que construyes.

| Opción | Idea | A favor | En contra |
|---|---|---|---|
| **A. Defensa por oleadas** (recomendada para empezar) | De "día" recoges recursos y construyes tu base; de "noche" llegan oleadas de enemigos que debes aguantar luchando junto a tus defensas. | Bucle muy claro, todo PvE (más fácil de equilibrar y de hacer seguro), escala bien con nuevos enemigos y piezas. | Hay que crear IA de enemigos desde el principio. |
| B. Exploración con base propia | Mundo por zonas; cada zona desbloquea recursos y piezas nuevas, tu base es tu progreso visible. | Mucho contenido ampliable, buena retención. | Más contenido (mapas) antes de que sea divertido. |
| C. Arena PvP con fuertes | Partidas cortas: construyes un fuerte y atacas el de los demás. | Muy rejugable, social. | PvP + construcción es lo más difícil de equilibrar y de proteger contra exploits. |

## 4. MVP (Propuesta, con la opción A)

Lo mínimo para que sea jugable y divertido:

1. **Recursos**: 1–2 tipos (p. ej. madera y piedra) que se recogen en el mapa.
2. **Construcción**: colocar piezas en una cuadrícula dentro de tu parcela (muro, puerta, torreta básica). El servidor valida posición, coste y límites.
3. **Combate**: un arma cuerpo a cuerpo y una a distancia; daño calculado en el servidor.
4. **Enemigos**: 2–3 tipos que atacan tu base durante la oleada.
5. **Progresión**: XP y nivel; cada nivel desbloquea una pieza o arma nueva.
6. **Guardado**: nivel, XP, recursos y desbloqueos (la base guardada puede ir después).

## 5. Sistemas planificados (se crean solo cuando hagan falta)

| Sistema | Estado |
|---|---|
| Red validada (NetService) | Hecho |
| Datos del jugador (DataService) | Hecho |
| Coins (sin guardar todavía) | Hecho |
| Recursos / economía | Pendiente |
| Construcción | Pendiente |
| Combate y vida | Pendiente |
| Enemigos y oleadas | Pendiente |
| Nivel y XP | Pendiente |
| Interfaz (HUD, menú de construcción) | Pendiente |
| Tienda, Game Passes, misiones, diarios | Más adelante |

## 6. Preguntas abiertas

- ¿Qué dirección (A, B o C) te gusta más? ¿O una mezcla?
- ¿Partidas por servidor compartido (todos en el mismo mapa) o cada jugador con su parcela?
- ¿Estilo visual? (low poly, realista, cartoon…)
- ¿Jugar solo, en cooperativo o ambos?

## 7. Decisiones tomadas

| Fecha | Decisión |
|---|---|
| 2026-10-03 | Nombre del juego: **Egg Lab**. |
| 2026-10-03 | Código en archivos con Rojo y versionado en GitHub. |
| 2026-10-03 | Servidor autoritativo: el cliente solo pide, el servidor valida y decide. |

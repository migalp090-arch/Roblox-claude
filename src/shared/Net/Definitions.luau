--!strict
-- Lista única de todos los remotos del juego. El servidor los crea a partir de aquí
-- y el cliente solo puede usar los nombres que aparecen en esta tabla.
--
--   direction = "ToClient": el servidor avisa al cliente (RemoteEvent).
--   direction = "ToServer": el cliente pide algo. Obligatorio: `args` (un validador por argumento)
--                           y `rateLimit` ({ count, per }). kind = "Function" si espera respuesta.
--
-- Ejemplo de remoto Cliente -> Servidor:
--   PlaceBlock = {
--       kind = "Event",
--       direction = "ToServer",
--       args = { Validate.string(32), Validate.vector3(2048) },
--       rateLimit = { count = 10, per = 1 },
--   },

local Validate = require(script.Parent.Parent.Util.Validate)

export type Definition = {
	kind: "Event" | "Function",
	direction: "ToClient" | "ToServer",
	args: { Validate.Validator }?,
	rateLimit: { count: number, per: number }?,
}

local Definitions: { [string]: Definition } = {
	-- Datos del jugador (servidor -> cliente)
	DataSnapshot = { kind = "Event", direction = "ToClient" },
	DataChanged = { kind = "Event", direction = "ToClient" },

	-- Moneda (servidor -> cliente)
	CoinsChanged = { kind = "Event", direction = "ToClient" },

	-- Ajedrez: el servidor es la única autoridad (reglas, turnos, relojes, resultado).
	ChessUpdate = { kind = "Event", direction = "ToClient" }, -- estado completo (+ último movimiento si lo hay)
	ChessSync = {
		kind = "Event",
		direction = "ToServer",
		args = {},
		rateLimit = { count = 3, per = 5 },
	},
	ChessSit = {
		kind = "Event",
		direction = "ToServer",
		args = { Validate.oneOf({ "white", "black", "solo" }) },
		rateLimit = { count = 4, per = 3 },
	},
	ChessMove = {
		kind = "Event",
		direction = "ToServer",
		-- origen, destino (0..63) y pieza de promoción ("" si no hay)
		args = { Validate.integer(0, 63), Validate.integer(0, 63), Validate.oneOf({ "", "q", "r", "b", "n" }) },
		rateLimit = { count = 6, per = 2 },
	},
	ChessAction = {
		kind = "Event",
		direction = "ToServer",
		args = { Validate.oneOf({ "resign", "offerDraw", "acceptDraw", "declineDraw", "rematch", "leave" }) },
		rateLimit = { count = 6, per = 4 },
	},
}

return Definitions

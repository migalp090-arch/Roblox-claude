--!strict
-- Ajustes generales del juego, compartidos por servidor y cliente.

return {
	GameName = "Egg Lab",

	-- Ajedrez
	Chess = {
		TimeSeconds = 600, -- tiempo por jugador
		IncrementSeconds = 5, -- incremento por jugada
		AllowSoloInStudio = true, -- un solo jugador controla ambos bandos (solo en Studio, para probar)
		MaxNameLength = 24,
	},

	-- Coins (sistema heredado, oculto en el juego de ajedrez)
	ShowCoins = false,
	StartingCoins = 0,
	MaxCoins = 1e12, -- tope de seguridad
}

--!strict
-- Ajustes de servidor para un juego sin personajes: el jugador solo ve el tablero con la cámara del cliente.

local Players = game:GetService("Players")

local SetupService = {}

function SetupService:Init()
	Players.CharacterAutoLoads = false
end

return SetupService

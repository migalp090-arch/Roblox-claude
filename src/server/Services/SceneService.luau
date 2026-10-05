--!strict
-- Construye una sola vez la escena estática del ajedrez en Workspace.Map (replicada a todos los clientes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SceneBuilder = require(ReplicatedStorage.Shared.Chess.SceneBuilder)

local SceneService = {}

function SceneService:Init()
	local map = workspace:FindFirstChild("Map")
	if not map then
		map = Instance.new("Folder")
		map.Name = "Map"
		map.Parent = workspace
	end
	SceneBuilder.build(map :: Instance)
end

return SceneService

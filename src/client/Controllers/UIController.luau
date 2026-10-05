--!strict
-- Punto de acceso a la interfaz. Todas las pantallas cuelgan de StarterGui.MainGui
-- (copiado a PlayerGui). Cada pantalla futura tendrá su propio controlador y usará GetRoot().
-- Como el juego no tiene personaje (CharacterAutoLoads = false), Roblox no copia StarterGui hasta que
-- aparece uno: si MainGui no llega, se crea aquí con las mismas propiedades.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local UIController = {}

local root: ScreenGui? = nil

-- Oculta los elementos del núcleo que tapan la interfaz del juego (lista de jugadores, mochila, chat, vida...).
local function hideCoreGui()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end

function UIController:Start()
	task.spawn(hideCoreGui)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("MainGui", 1.5)
	if not gui then
		local created = Instance.new("ScreenGui")
		created.Name = "MainGui"
		created.ResetOnSpawn = false
		created.IgnoreGuiInset = true
		created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		created.Parent = playerGui
		gui = created
	end
	root = gui :: ScreenGui
end

-- ScreenGui principal (espera a que exista).
function UIController:GetRoot(): ScreenGui
	while not root do
		task.wait()
	end
	return root :: ScreenGui
end

return UIController

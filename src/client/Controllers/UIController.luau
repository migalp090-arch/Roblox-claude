--!strict
-- Punto de acceso a la interfaz. Todas las pantallas cuelgan de StarterGui.MainGui
-- (copiado a PlayerGui). Cada pantalla futura tendrá su propio controlador y usará GetRoot().

local Players = game:GetService("Players")

local UIController = {}

local root: ScreenGui? = nil

function UIController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	root = playerGui:WaitForChild("MainGui") :: ScreenGui
end

-- ScreenGui principal (espera a que exista).
function UIController:GetRoot(): ScreenGui
	while not root do
		task.wait()
	end
	return root :: ScreenGui
end

return UIController

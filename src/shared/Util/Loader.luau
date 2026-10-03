--!strict
-- Carga los ModuleScripts de una carpeta (servicios o controladores) y los arranca en dos fases:
--   1. Init(): preparación síncrona (crear estado, conectar remotos). No debe esperar (yield).
--   2. Start(): lógica en marcha. Cada Start corre en su propio hilo.

local Loader = {}

export type Module = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
	[any]: any,
}

function Loader.LoadChildren(folder: Instance): { [string]: Module }
	local modules: { [string]: Module } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			modules[child.Name] = require(child) :: any
		end
	end
	return modules
end

function Loader.Run(modules: { [string]: Module }, label: string)
	local names = {}
	for name in modules do
		table.insert(names, name)
	end
	table.sort(names)

	for _, name in names do
		local module = modules[name]
		if type(module.Init) == "function" then
			local ok, err = pcall(module.Init, module)
			if not ok then
				warn(`[{label}] Error en Init de {name}: {err}`)
			end
		end
	end

	for _, name in names do
		local module = modules[name]
		if type(module.Start) == "function" then
			task.spawn(function()
				local ok, err = pcall(module.Start, module)
				if not ok then
					warn(`[{label}] Error en Start de {name}: {err}`)
				end
			end)
		end
	end
end

return Loader

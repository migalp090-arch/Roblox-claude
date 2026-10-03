--!strict
-- Copia local (solo lectura) de los datos del jugador, enviada por DataService.
-- Las interfaces leen de aquí y se actualizan con OnChanged. Cambiar estos datos en el cliente
-- no tiene efecto en el servidor.

local Net = require(script.Parent.Parent.Net)

local DataController = {}

local data: { [string]: any }? = nil
local listeners: { [string]: { (value: any) -> () } } = {}
local readyCallbacks: { () -> () } = {}

local function notify(key: string, value: any)
	local callbacks = listeners[key]
	if callbacks then
		for _, callback in callbacks do
			task.spawn(callback, value)
		end
	end
end

function DataController:Init()
	Net.On("DataSnapshot", function(snapshot: { [string]: any })
		data = snapshot
		for key, value in snapshot do
			notify(key, value)
		end
		for _, callback in readyCallbacks do
			task.spawn(callback)
		end
		table.clear(readyCallbacks)
	end)

	Net.On("DataChanged", function(key: string, value: any)
		if data then
			data[key] = value
		end
		notify(key, value)
	end)
end

-- Valor actual (nil si los datos aún no han llegado).
function DataController:Get(key: string): any
	return data and data[key]
end

-- Llama a `callback` con el valor actual (si ya lo hay) y cada vez que cambie.
function DataController:OnChanged(key: string, callback: (value: any) -> ())
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], callback)
	if data and data[key] ~= nil then
		task.spawn(callback, data[key])
	end
end

-- Llama a `callback` cuando lleguen los datos por primera vez (o ya mismo si ya llegaron).
function DataController:OnReady(callback: () -> ())
	if data then
		task.spawn(callback)
	else
		table.insert(readyCallbacks, callback)
	end
end

return DataController

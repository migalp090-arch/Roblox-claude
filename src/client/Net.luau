--!strict
-- Acceso del cliente a los remotos declarados en Shared/Net/Definitions.
-- El cliente solo pide cosas; el servidor decide y valida.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = require(ReplicatedStorage.Shared.Net.Definitions)

local Net = {}

local folder = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name: string, direction: string): Instance
	local definition = Definitions[name]
	assert(definition, `[Net] El remoto "{name}" no existe en Net/Definitions`)
	assert(definition.direction == direction, `[Net] "{name}" no es {direction}`)
	return folder:WaitForChild(name)
end

-- Escucha un aviso del servidor.
function Net.On(name: string, handler: (...any) -> ()): RBXScriptConnection
	return (getRemote(name, "ToClient") :: RemoteEvent).OnClientEvent:Connect(handler)
end

-- Envía una petición al servidor (sin respuesta).
function Net.Fire(name: string, ...: any)
	(getRemote(name, "ToServer") :: RemoteEvent):FireServer(...)
end

-- Envía una petición al servidor y espera su respuesta.
function Net.Invoke(name: string, ...: any): ...any
	return (getRemote(name, "ToServer") :: RemoteFunction):InvokeServer(...)
end

return Net

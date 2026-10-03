--!strict
-- Única puerta de entrada de la red. Crea los remotos declarados en Shared/Net/Definitions
-- y valida en el servidor todo lo que envía el cliente (nombre, nº de argumentos, tipos, límite de uso).
-- Los demás servicios usan NetService:On / :Fire en lugar de tocar RemoteEvents directamente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = require(ReplicatedStorage.Shared.Net.Definitions)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local NetService = {}

local folder: Folder? = nil
local remotes: { [string]: RemoteEvent | RemoteFunction } = {}
local limiters: { [string]: RateLimiter.RateLimiter } = {}
local handled: { [string]: boolean } = {}

local function getFolder(): Folder
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		folder = created
		return created
	end
	return folder
end

local function getDefinition(name: string): Definitions.Definition
	local definition = Definitions[name]
	assert(definition, `[NetService] El remoto "{name}" no existe en Net/Definitions`)
	return definition
end

local function getRemote(name: string): RemoteEvent | RemoteFunction
	local remote = remotes[name]
	if not remote then
		local definition = getDefinition(name)
		local created = Instance.new(if definition.kind == "Function" then "RemoteFunction" else "RemoteEvent")
		created.Name = name
		created.Parent = getFolder()
		remote = created :: any
		remotes[name] = remote
	end
	return remote
end

-- Comprueba un mensaje del cliente. Devuelve false si debe ignorarse.
local function accept(
	name: string,
	definition: Definitions.Definition,
	player: Player,
	args: { any },
	count: number
): boolean
	local limiter = limiters[name]
	if limiter and not limiter:Check(player) then
		return false
	end

	local validators = definition.args or {}
	if count ~= #validators then
		return false
	end
	for index, validator in validators do
		if not validator(args[index]) then
			return false
		end
	end
	return true
end

function NetService:Init()
	for name in Definitions do
		getRemote(name)
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:Remove(player)
		end
	end)
end

-- Escucha un remoto Cliente -> Servidor. El handler solo se llama con argumentos ya validados.
-- Para kind = "Function", lo que devuelva el handler se envía como respuesta.
function NetService:On(name: string, handler: (player: Player, ...any) -> ...any)
	local definition = getDefinition(name)
	assert(definition.direction == "ToServer", `[NetService] "{name}" no es un remoto Cliente -> Servidor`)
	local rateLimit = definition.rateLimit
	assert(definition.args and rateLimit, `[NetService] "{name}" necesita args y rateLimit`)
	assert(not handled[name], `[NetService] "{name}" ya tiene un handler`)
	handled[name] = true

	limiters[name] = RateLimiter.new(rateLimit.count, rateLimit.per)
	local remote = getRemote(name)

	if remote:IsA("RemoteFunction") then
		remote.OnServerInvoke = function(player: Player, ...)
			if not accept(name, definition, player, { ... }, select("#", ...)) then
				return nil
			end
			return handler(player, ...)
		end
	else
		(remote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, ...)
			if accept(name, definition, player, { ... }, select("#", ...)) then
				handler(player, ...)
			end
		end)
	end
end

-- Envía un remoto Servidor -> Cliente a un jugador.
function NetService:Fire(name: string, player: Player, ...: any)
	assert(getDefinition(name).direction == "ToClient", `[NetService] "{name}" no es Servidor -> Cliente`);
	(getRemote(name) :: RemoteEvent):FireClient(player, ...)
end

-- Envía un remoto Servidor -> Cliente a todos los jugadores.
function NetService:FireAll(name: string, ...: any)
	assert(getDefinition(name).direction == "ToClient", `[NetService] "{name}" no es Servidor -> Cliente`);
	(getRemote(name) :: RemoteEvent):FireAllClients(...)
end

return NetService

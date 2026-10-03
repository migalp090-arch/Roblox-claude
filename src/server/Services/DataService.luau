--!strict
-- Carga, guarda y protege el progreso de cada jugador (DataStoreService).
--
-- - Bloqueo de sesión: un jugador solo puede tener sus datos abiertos en un servidor a la vez,
--   para evitar duplicados o pérdidas al cambiar de servidor.
-- - Reintentos con espera creciente si DataStore falla.
-- - Autoguardado periódico solo si los datos han cambiado, guardado al salir y al cerrar el servidor.
-- - En Studio sin acceso a la API funciona con datos temporales (no se guarda nada).
--
-- Los demás servicios NO deben escribir en los datos directamente: usan Set / Increment,
-- que marcan los datos como modificados y avisan al cliente.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataTemplate: { [string]: any } = require(ReplicatedStorage.Shared.Config.DataTemplate) :: any
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)
local NetService = require(script.Parent.NetService)

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 60 -- segundos
local LOCK_EXPIRY = 300 -- un bloqueo sin renovar durante este tiempo se considera abandonado
local LOCK_WAIT_ATTEMPTS = 10
local LOCK_WAIT_SECONDS = 3
local MAX_RETRIES = 4

type Profile = {
	data: { [string]: any },
	dirty: boolean,
	canSave: boolean, -- false si los datos son temporales (Studio sin acceso a la API)
	released: boolean, -- true cuando el bloqueo ya se ha liberado; no se vuelve a guardar
	lastWrite: number,
}

local DataService = {}

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, { [string]: any }) -> () } = {}
local loadedEvent = Instance.new("BindableEvent")
local activeSaves = 0

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

local function withRetries(label: string, fn: () -> ()): boolean
	for attempt = 1, MAX_RETRIES do
		local ok, err = pcall(fn)
		if ok then
			return true
		end
		warn(`[DataService] {label} falló (intento {attempt}/{MAX_RETRIES}): {err}`)
		if attempt < MAX_RETRIES then
			task.wait(2 ^ attempt)
		end
	end
	return false
end

-- Cambios de formato entre versiones de datos. Ejemplo:
--   if data.Version < 2 then data.Coins = data.Gold; data.Gold = nil; data.Version = 2 end
local function migrate(data: { [string]: any })
	data.Version = math.max(data.Version or 1, DataTemplate.Version)
end

-- Intenta abrir los datos con bloqueo de sesión.
-- Devuelve: "ok" + datos guardados (o nil si es nuevo), "locked" si otro servidor los tiene, o "error".
local function acquire(player: Player): (string, { [string]: any }?)
	local dataStore = store :: DataStore
	local status = "error"
	local loaded: { [string]: any }? = nil

	local ok = withRetries(`Cargar {player.UserId}`, function()
		dataStore:UpdateAsync(keyFor(player), function(stored)
			stored = stored or {}
			local lock = stored.Lock
			if lock and lock.JobId ~= game.JobId and os.time() - lock.Time < LOCK_EXPIRY then
				status = "locked"
				return nil -- no escribe nada
			end
			status = "ok"
			loaded = stored.Data
			stored.Lock = { JobId = game.JobId, Time = os.time() }
			return stored
		end)
	end)

	if not ok then
		return "error", nil
	end
	return status, loaded
end

-- Guarda los datos. Con release = true libera el bloqueo (el jugador se va o el servidor cierra).
local function save(player: Player, profile: Profile, release: boolean)
	if not profile.canSave or profile.released or not store then
		return
	end
	-- Sin cambios: solo se escribe de vez en cuando para renovar el bloqueo.
	if not release and not profile.dirty and os.clock() - profile.lastWrite < LOCK_EXPIRY / 3 then
		return
	end
	if release then
		profile.released = true
	end

	local dataStore = store :: DataStore
	local snapshot = TableUtil.DeepCopy(profile.data)
	local wasDirty = profile.dirty
	profile.dirty = false
	profile.lastWrite = os.clock()
	activeSaves += 1

	local ok = withRetries(`Guardar {player.UserId}`, function()
		dataStore:UpdateAsync(keyFor(player), function(stored)
			stored = stored or {}
			local lock = stored.Lock
			-- Solo escribe si el bloqueo es nuestro. Si es de otro servidor (o ya se liberó),
			-- no se pisan los datos.
			if lock and lock.JobId ~= game.JobId then
				return nil
			end
			if not lock and not release then
				return nil
			end
			stored.Data = snapshot
			stored.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
			return stored
		end)
	end)

	activeSaves -= 1
	if not ok and wasDirty and not release then
		profile.dirty = true -- se reintentará en el próximo autoguardado
	end
end

local function onPlayerAdded(player: Player)
	local profile: Profile
	if store then
		local status, stored = acquire(player)
		for _ = 1, LOCK_WAIT_ATTEMPTS do
			if status ~= "locked" or not player.Parent then
				break
			end
			task.wait(LOCK_WAIT_SECONDS)
			status, stored = acquire(player)
		end

		if status ~= "ok" then
			if player.Parent then
				player:Kick("No se pudieron cargar tus datos. Vuelve a entrar en unos segundos.")
			end
			return
		end

		local data = stored or TableUtil.DeepCopy(DataTemplate)
		TableUtil.Reconcile(data, DataTemplate)
		migrate(data)
		profile = { data = data, dirty = stored == nil, canSave = true, released = false, lastWrite = os.clock() }
	else
		profile = {
			data = TableUtil.DeepCopy(DataTemplate),
			dirty = false,
			canSave = false,
			released = false,
			lastWrite = os.clock(),
		}
	end

	if not player.Parent then
		-- Salió mientras cargaba: libera el bloqueo y termina.
		save(player, profile, true)
		return
	end

	profiles[player] = profile
	NetService:Fire("DataSnapshot", player, profile.data)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile.data)
	end
	loadedEvent:Fire(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	loadedEvent:Fire(player) -- despierta a quien esté en WaitForData
	if profile then
		save(player, profile, true)
	end
end

function DataService:Init()
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
	if ok then
		store = result
	elseif not RunService:IsStudio() then
		error(`[DataService] No se pudo abrir el DataStore: {result}`)
	end
end

function DataService:Start()
	-- En Studio el DataStore solo funciona si el juego está publicado y tiene activado el acceso a la API.
	if store and RunService:IsStudio() then
		local dataStore = store :: DataStore
		local ok = pcall(function()
			dataStore:GetAsync("__studio_check")
		end)
		if not ok then
			store = nil
		end
	end
	if not store then
		warn("[DataService] DataStore no disponible en Studio: se usan datos temporales que NO se guardan.")
		warn(
			"[DataService] Para probar guardado: publica el juego y activa Game Settings > Security > Enable Studio Access to API Services."
		)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		for player, profile in profiles do
			profiles[player] = nil
			task.spawn(save, player, profile, true)
		end
		local deadline = os.clock() + 25
		while activeSaves > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player, profile in profiles do
			task.spawn(save, player, profile, false)
		end
	end
end

-- Datos de un jugador (solo lectura para otros servicios). nil si aún no han cargado.
function DataService:Get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.data
end

-- Espera a que carguen los datos. Devuelve nil si el jugador sale antes.
function DataService:WaitForData(player: Player): { [string]: any }?
	while player.Parent and not profiles[player] do
		loadedEvent.Event:Wait()
	end
	return self:Get(player)
end

-- Registra una función que se llama cada vez que se cargan los datos de un jugador.
function DataService:OnLoaded(callback: (Player, { [string]: any }) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.data)
	end
end

-- Cambia un valor de primer nivel y avisa al cliente.
function DataService:Set(player: Player, key: string, value: any)
	local profile = profiles[player]
	assert(profile, `[DataService] Datos de {player.Name} no cargados`)
	assert(DataTemplate[key] ~= nil, `[DataService] "{key}" no existe en DataTemplate`)
	profile.data[key] = value
	profile.dirty = true
	NetService:Fire("DataChanged", player, key, value)
end

-- Suma (o resta) a un valor numérico. Devuelve el nuevo valor.
function DataService:Increment(player: Player, key: string, amount: number): number
	local profile = profiles[player]
	assert(profile, `[DataService] Datos de {player.Name} no cargados`)
	local current = profile.data[key]
	assert(type(current) == "number", `[DataService] "{key}" no es numérico`)
	local newValue = current + amount
	self:Set(player, key, newValue)
	return newValue
end

return DataService

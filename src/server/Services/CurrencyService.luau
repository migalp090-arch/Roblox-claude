--!strict
-- Coins de cada jugador. El servidor es el único que puede cambiarlas.
-- Por ahora viven en memoria (se pierden al salir); al conectarlas a DataService solo cambian
-- los puntos marcados con "Guardado".
--
-- Uso desde otros servicios:
--   CurrencyService:AddCoins(player, 50)          -> true / false
--   CurrencyService:SpendCoins(player, 20)        -> true si tenía suficientes y se cobraron
--   CurrencyService:GetCoins(player)              -> número

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local NetService = require(script.Parent.NetService)

local CurrencyService = {}

local balances: { [Player]: number } = {}

-- Cantidad válida: entero positivo y finito.
local function isValidAmount(amount: any): boolean
	return type(amount) == "number"
		and amount == amount
		and amount > 0
		and amount <= GameConfig.MaxCoins
		and amount % 1 == 0
end

local function setBalance(player: Player, value: number)
	balances[player] = value
	NetService:Fire("CoinsChanged", player, value)
end

local function onPlayerAdded(player: Player)
	-- Guardado: aquí se cargaría el valor desde DataService.
	setBalance(player, GameConfig.StartingCoins)
end

function CurrencyService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		balances[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if balances[player] == nil then
			onPlayerAdded(player)
		end
	end
end

function CurrencyService:GetCoins(player: Player): number
	return balances[player] or 0
end

function CurrencyService:AddCoins(player: Player, amount: number): boolean
	local current = balances[player]
	if current == nil or not isValidAmount(amount) then
		warn(`[CurrencyService] AddCoins rechazado para {player.Name}: {amount}`)
		return false
	end
	setBalance(player, math.min(current + amount, GameConfig.MaxCoins))
	return true
end

function CurrencyService:SpendCoins(player: Player, amount: number): boolean
	local current = balances[player]
	if current == nil or not isValidAmount(amount) then
		warn(`[CurrencyService] SpendCoins rechazado para {player.Name}: {amount}`)
		return false
	end
	if current < amount then
		return false
	end
	setBalance(player, current - amount)
	return true
end

return CurrencyService

--!strict
-- Partida de ajedrez 1v1 (autoridad total). Un único tablero por servidor:
--   - asientos (blancas / negras), turnos, relojes con incremento
--   - validación de cada movimiento con Chess/Rules (el cliente solo propone origen/destino)
--   - jaque mate, ahogado, tablas (acuerdo, repetición, 50 jugadas, material), abandono, tiempo, desconexión
--   - revancha (alterna colores)
-- El cliente recibe el estado completo con ChessUpdate; los efectos visuales los pone el cliente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Rules = require(ReplicatedStorage.Shared.Chess.Rules)
local NetService = require(script.Parent.NetService)

local MatchService = {}

type Seat = string -- "w" | "b"

local config = GameConfig.Chess

local state: Rules.State = Rules.new()
local legal: { Rules.Move } = {}
local seats: { [string]: Player? } = {}
local solo = false
local status = "waiting" -- "waiting" | "playing" | "over"
local clocks: { [string]: number } = { w = config.TimeSeconds, b = config.TimeSeconds }
local turnStart = 0
local history: { string } = {}
local repeats: { [string]: number } = {}
local captured: { w: { string }, b: { string } } = { w = {}, b = {} } -- piezas perdidas por cada bando
local lastMove: Rules.Move? = nil
local moveSeq = 0
local drawOffer: Seat? = nil
local rematchVotes: { [string]: boolean } = { w = false, b = false }
local result: { winner: string, reason: string }? = nil
local generation = 0

local function other(seat: Seat): Seat
	return if seat == "w" then "b" else "w"
end

local function seatOf(player: Player): Seat?
	if seats.w == player then
		return "w"
	elseif seats.b == player then
		return "b"
	end
	return nil
end

local function playerInfo(player: Player?): { id: number, name: string }?
	if not player then
		return nil
	end
	return { id = player.UserId, name = string.sub(player.DisplayName, 1, config.MaxNameLength) }
end

local function hasMatingMaterial(board: { string }, white: boolean): boolean
	local minors = 0
	for _, piece in board do
		if piece ~= "" and Rules.isWhitePiece(piece) == white then
			local kind = string.upper(piece)
			if kind == "P" or kind == "R" or kind == "Q" then
				return true
			elseif kind == "N" or kind == "B" then
				minors += 1
			end
		end
	end
	return minors >= 2
end

local function remaining(seat: Seat): number
	local time = clocks[seat]
	if status == "playing" and state.turn == seat then
		time -= workspace:GetServerTimeNow() - turnStart
	end
	return time
end

local function snapshot(withMove: boolean): { [string]: any }
	local moves = table.create(#legal)
	if status == "playing" then
		for index, move in legal do
			moves[index] = move.from * 64 + move.to
		end
	end

	local check = -1
	if Rules.inCheck(state) then
		for sq = 0, 63 do
			if state.board[sq + 1] == (if state.turn == "w" then "K" else "k") then
				check = sq
				break
			end
		end
	end

	local data: { [string]: any } = {
		board = Rules.boardString(state),
		turn = state.turn,
		status = status,
		solo = solo,
		seats = { w = playerInfo(seats.w), b = playerInfo(seats.b) },
		clocks = { w = clocks.w, b = clocks.b },
		turnStart = turnStart,
		timeSeconds = config.TimeSeconds,
		moves = moves,
		history = history,
		check = check,
		result = result,
		drawOffer = drawOffer,
		rematch = { w = rematchVotes.w, b = rematchVotes.b },
		seq = moveSeq,
		captured = captured,
		canSolo = config.AllowSoloInStudio and RunService:IsStudio(),
		last = if lastMove then { from = lastMove.from, to = lastMove.to } else nil,
	}
	if withMove and lastMove then
		data.move = {
			from = lastMove.from,
			to = lastMove.to,
			piece = lastMove.piece,
			captured = lastMove.captured,
			promo = lastMove.promo,
			flag = lastMove.flag,
		}
	end
	return data
end

local function broadcast(withMove: boolean)
	NetService:FireAll("ChessUpdate", snapshot(withMove))
end

local function resetBoard()
	state = Rules.new()
	legal = Rules.legalMoves(state)
	history = {}
	repeats = { [Rules.positionKey(state)] = 1 }
	lastMove = nil
	captured = { w = {}, b = {} }
	moveSeq = 0
	drawOffer = nil
	result = nil
	rematchVotes = { w = false, b = false }
	clocks = { w = config.TimeSeconds, b = config.TimeSeconds }
	generation += 1
end

local function finish(winner: string, reason: string)
	if status ~= "playing" then
		return
	end
	-- Congela el reloj de quien tenía el turno.
	local mover: Seat = state.turn
	clocks[mover] = math.max(0, remaining(mover))
	status = "over"
	result = { winner = winner, reason = reason }
	drawOffer = nil
	generation += 1
end

local scheduleTimeout: () -> ()

local function onTimeout(token: number)
	if token ~= generation or status ~= "playing" then
		return
	end
	local mover: Seat = state.turn
	if remaining(mover) > 0.02 then
		scheduleTimeout()
		return
	end
	if hasMatingMaterial(state.board, mover == "b") then
		finish(other(mover), "timeout")
	else
		finish("draw", "timeout_insufficient")
	end
	broadcast(false)
end

function scheduleTimeout()
	local mover: Seat = state.turn
	local token = generation
	task.delay(math.max(0.05, remaining(mover) + 0.05), onTimeout, token)
end

local function startGame()
	resetBoard()
	status = "playing"
	turnStart = workspace:GetServerTimeNow()
	scheduleTimeout()
end

local function clearSeats()
	seats = {}
	solo = false
	status = "waiting"
	resetBoard()
end

local function sit(player: Player, choice: string)
	if status == "playing" or seatOf(player) then
		return
	end
	if status == "over" then
		return -- hay que salir primero (leave) o esperar a la revancha
	end

	if choice == "solo" then
		if not (config.AllowSoloInStudio and RunService:IsStudio()) or seats.w or seats.b then
			return
		end
		seats.w, seats.b, solo = player, player, true
		startGame()
	else
		local seat: Seat = if choice == "white" then "w" else "b"
		if seats[seat] then
			return
		end
		seats[seat] = player
		if seats.w and seats.b then
			startGame()
		end
	end
	broadcast(false)
end

local function handleMove(player: Player, from: number, to: number, promoLetter: string)
	if status ~= "playing" then
		return
	end
	local seat = seatOf(player)
	if not seat or seats[state.turn] ~= player then
		return
	end

	-- Si el reloj ya se agotó, la jugada no cuenta.
	local mover: Seat = state.turn
	if remaining(mover) <= 0 then
		onTimeout(generation)
		return
	end

	local chosen: Rules.Move? = nil
	for _, move in legal do
		if move.from == from and move.to == to then
			if move.promo == "" then
				chosen = move
				break
			elseif string.lower(move.promo) == promoLetter then
				chosen = move
				break
			end
		end
	end
	if not chosen then
		return
	end
	local move = chosen :: Rules.Move

	-- Reloj: descuenta el tiempo usado y suma el incremento.
	local now = workspace:GetServerTimeNow()
	clocks[mover] = math.max(0, clocks[mover] - (now - turnStart)) + config.IncrementSeconds

	table.insert(history, Rules.notation(state, move, legal))
	if move.captured ~= "" then
		table.insert(if mover == "w" then captured.b else captured.w, move.captured)
	end
	state = Rules.apply(state, move)
	legal = Rules.legalMoves(state)
	lastMove = move
	moveSeq += 1
	drawOffer = nil
	turnStart = now
	generation += 1

	local key = Rules.positionKey(state)
	repeats[key] = (repeats[key] or 0) + 1

	local outcome = Rules.getStatus(state, #legal)
	if outcome == "checkmate" then
		finish(mover, "checkmate")
	elseif outcome ~= "playing" then
		finish("draw", outcome)
	elseif repeats[key] >= 3 then
		finish("draw", "repetition")
	else
		scheduleTimeout()
	end
	broadcast(true)
end

local function handleAction(player: Player, action: string)
	local seat = seatOf(player)
	if not seat then
		return
	end

	if action == "resign" then
		if status == "playing" then
			finish(if solo then other(state.turn) else other(seat), "resign")
			broadcast(false)
		end
	elseif action == "offerDraw" then
		if status == "playing" and drawOffer == nil then
			if solo then
				finish("draw", "agreement")
			else
				drawOffer = seat
			end
			broadcast(false)
		end
	elseif action == "acceptDraw" then
		if status == "playing" and drawOffer == other(seat) then
			finish("draw", "agreement")
			broadcast(false)
		end
	elseif action == "declineDraw" then
		if status == "playing" and drawOffer == other(seat) then
			drawOffer = nil
			broadcast(false)
		end
	elseif action == "rematch" then
		if status ~= "over" or not (solo or (seats.w and seats.b)) then
			return
		end
		rematchVotes[seat] = true
		if solo or (rematchVotes.w and rematchVotes.b) then
			-- Alterna colores entre los dos jugadores.
			seats.w, seats.b = seats.b, seats.w
			startGame()
		end
		broadcast(false)
	elseif action == "leave" then
		if status == "playing" then
			finish(if solo then "draw" else other(seat), "abandon")
		end
		if solo then
			clearSeats()
		else
			-- El rival que se queda sigue viendo el resultado hasta que él también salga.
			seats[seat] = nil
			rematchVotes = { w = false, b = false }
			if not (seats.w or seats.b) then
				clearSeats()
			end
		end
		broadcast(false)
	end
end

local function onPlayerRemoving(player: Player)
	local seat = seatOf(player)
	if seat then
		handleAction(player, "leave")
	end
end

function MatchService:Init()
	resetBoard()

	NetService:On("ChessSync", function(player: Player)
		NetService:Fire("ChessUpdate", player, snapshot(false))
	end)
	NetService:On("ChessSit", sit)
	NetService:On("ChessMove", handleMove)
	NetService:On("ChessAction", handleAction)

	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return MatchService

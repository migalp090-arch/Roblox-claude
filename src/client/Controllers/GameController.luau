--!strict
-- Estado de la partida en el cliente (solo lectura: lo decide el servidor) y envío de peticiones.
-- El resto de controladores se suscriben con OnUpdate para reaccionar a cada ChessUpdate.

local Players = game:GetService("Players")

local Net = require(script.Parent.Parent.Net)

local GameController = {}

export type Snapshot = { [string]: any }

local state: Snapshot? = nil
local listeners: { (snapshot: Snapshot) -> () } = {}
local legalByFrom: { [number]: { number } } = {}
local boardCells: { string } = table.create(64, "")

local function decodeBoard(text: string): { string }
	local cells: { string } = table.create(64, "")
	local rank, file = 7, 0
	for char in string.gmatch(text, ".") do
		if char == "/" then
			rank -= 1
			file = 0
		elseif string.match(char, "%d") then
			file += tonumber(char) :: number
		else
			cells[rank * 8 + file + 1] = char
			file += 1
		end
	end
	return cells
end

function GameController:Init()
	Net.On("ChessUpdate", function(snapshot: Snapshot)
		state = snapshot
		boardCells = decodeBoard(snapshot.board)
		legalByFrom = {}
		for _, packed in snapshot.moves do
			local from, to = packed // 64, packed % 64
			local list = legalByFrom[from]
			if not list then
				list = {}
				legalByFrom[from] = list
			end
			if not table.find(list, to) then
				table.insert(list, to)
			end
		end
		for _, listener in listeners do
			task.spawn(listener, snapshot)
		end
	end)
end

function GameController:Start()
	-- Pide el estado actual por si la partida ya estaba en marcha al entrar.
	Net.Fire("ChessSync")
end

-- Suscribe una función a cada actualización. Devuelve una función para cancelar.
function GameController:OnUpdate(listener: (snapshot: Snapshot) -> ()): () -> ()
	table.insert(listeners, listener)
	if state then
		task.spawn(listener, state)
	end
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function GameController:GetState(): Snapshot?
	return state
end

-- "w" | "b" | nil (espectador)
function GameController:MySeat(): string?
	if not state then
		return nil
	end
	local userId = Players.LocalPlayer.UserId
	local seats = state.seats
	if seats.w and seats.w.id == userId then
		return "w"
	elseif seats.b and seats.b.id == userId then
		return "b"
	end
	return nil
end

function GameController:IsMyTurn(): boolean
	local seat = self:MySeat()
	return state ~= nil and state.status == "playing" and seat ~= nil and state.turn == seat
end

function GameController:PieceAt(sq: number): string
	return boardCells[sq + 1]
end

-- ¿La pieza de esa casilla es del color con el que juego?
function GameController:IsMyPiece(sq: number): boolean
	local piece = boardCells[sq + 1]
	local seat = self:MySeat()
	if piece == "" or not seat then
		return false
	end
	local white = piece == string.upper(piece)
	return white == (seat == "w")
end

function GameController:LegalFrom(sq: number): { number }
	return legalByFrom[sq] or {}
end

function GameController:IsPromotion(from: number, to: number): boolean
	local piece = boardCells[from + 1]
	if piece ~= "P" and piece ~= "p" then
		return false
	end
	local rank = to // 8
	return (piece == "P" and rank == 7) or (piece == "p" and rank == 0)
end

function GameController:SendMove(from: number, to: number, promo: string)
	Net.Fire("ChessMove", from, to, promo)
end

function GameController:Sit(choice: string)
	Net.Fire("ChessSit", choice)
end

function GameController:Action(action: string)
	Net.Fire("ChessAction", action)
end

return GameController

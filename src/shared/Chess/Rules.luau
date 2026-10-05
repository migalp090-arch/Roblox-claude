--!strict
-- Motor de reglas del ajedrez (puro, sin Roblox): generación de movimientos legales, jaque,
-- mate, ahogado, enroque, al paso, promoción, tablas y notación.
-- Casillas 0..63: columna = sq % 8 (0 = a), fila = sq // 8 (0 = fila 1). a1 = 0, h8 = 63.
-- Piezas: mayúscula = blancas, minúscula = negras ("PNBRQK" / "pnbrqk"), "" = vacío.

local Rules = {}

export type Move = {
	from: number,
	to: number,
	piece: string,
	captured: string,
	promo: string, -- pieza resultante ("" si no hay promoción)
	flag: string, -- "" | "double" | "ep" | "castleK" | "castleQ"
}

export type State = {
	board: { string }, -- 64 entradas, índice = casilla + 1
	turn: string, -- "w" | "b"
	castling: number, -- bits: 1 = K, 2 = Q, 4 = k, 8 = q
	ep: number, -- casilla objetivo de captura al paso, o -1
	halfmove: number,
	fullmove: number,
}

local CASTLE_K, CASTLE_Q, CASTLE_k, CASTLE_q = 1, 2, 4, 8

local KNIGHT_STEPS = { { 1, 2 }, { 2, 1 }, { -1, 2 }, { -2, 1 }, { 1, -2 }, { 2, -1 }, { -1, -2 }, { -2, -1 } }
local KING_STEPS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
local BISHOP_DIRS = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
local ROOK_DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local PROMO_ORDER = { "q", "r", "b", "n" }

-- Máscara de derechos de enroque que se conservan al tocar una casilla.
local RIGHTS_MASK: { [number]: number } = {
	[0] = 15 - CASTLE_Q,
	[7] = 15 - CASTLE_K,
	[4] = 15 - CASTLE_K - CASTLE_Q,
	[56] = 15 - CASTLE_q,
	[63] = 15 - CASTLE_k,
	[60] = 15 - CASTLE_k - CASTLE_q,
}

local function isWhitePiece(piece: string): boolean
	return piece ~= "" and piece == string.upper(piece)
end

function Rules.isWhitePiece(piece: string): boolean
	return isWhitePiece(piece)
end

-- ¿Está la casilla `sq` atacada por el bando indicado?
local function isAttacked(board: { string }, sq: number, byWhite: boolean): boolean
	local file, rank = sq % 8, sq // 8

	-- Peones: un peón blanco ataca hacia arriba, así que estaría una fila por debajo.
	local pawnRank = if byWhite then rank - 1 else rank + 1
	if pawnRank >= 0 and pawnRank <= 7 then
		local pawn = if byWhite then "P" else "p"
		if file > 0 and board[pawnRank * 8 + file - 1 + 1] == pawn then
			return true
		end
		if file < 7 and board[pawnRank * 8 + file + 1 + 1] == pawn then
			return true
		end
	end

	local knight = if byWhite then "N" else "n"
	for _, step in KNIGHT_STEPS do
		local f, r = file + step[1], rank + step[2]
		if f >= 0 and f <= 7 and r >= 0 and r <= 7 and board[r * 8 + f + 1] == knight then
			return true
		end
	end

	local king = if byWhite then "K" else "k"
	for _, step in KING_STEPS do
		local f, r = file + step[1], rank + step[2]
		if f >= 0 and f <= 7 and r >= 0 and r <= 7 and board[r * 8 + f + 1] == king then
			return true
		end
	end

	local queen = if byWhite then "Q" else "q"
	local rook = if byWhite then "R" else "r"
	local bishop = if byWhite then "B" else "b"
	for _, dir in ROOK_DIRS do
		local f, r = file + dir[1], rank + dir[2]
		while f >= 0 and f <= 7 and r >= 0 and r <= 7 do
			local piece = board[r * 8 + f + 1]
			if piece ~= "" then
				if piece == rook or piece == queen then
					return true
				end
				break
			end
			f += dir[1]
			r += dir[2]
		end
	end
	for _, dir in BISHOP_DIRS do
		local f, r = file + dir[1], rank + dir[2]
		while f >= 0 and f <= 7 and r >= 0 and r <= 7 do
			local piece = board[r * 8 + f + 1]
			if piece ~= "" then
				if piece == bishop or piece == queen then
					return true
				end
				break
			end
			f += dir[1]
			r += dir[2]
		end
	end
	return false
end

local function findKing(board: { string }, white: boolean): number
	local king = if white then "K" else "k"
	for i = 1, 64 do
		if board[i] == king then
			return i - 1
		end
	end
	return -1
end

function Rules.inCheck(state: State, white: boolean?): boolean
	local isWhite = if white == nil then state.turn == "w" else white
	local kingSq = findKing(state.board, isWhite)
	return kingSq >= 0 and isAttacked(state.board, kingSq, not isWhite)
end

local function newMove(from: number, to: number, piece: string, captured: string, promo: string, flag: string): Move
	return { from = from, to = to, piece = piece, captured = captured, promo = promo, flag = flag }
end

-- Movimientos pseudo-legales (sin comprobar que el rey quede en jaque).
local function pseudoMoves(state: State): { Move }
	local board = state.board
	local white = state.turn == "w"
	local moves: { Move } = {}

	for sq = 0, 63 do
		local piece = board[sq + 1]
		if piece == "" or isWhitePiece(piece) ~= white then
			continue
		end
		local file, rank = sq % 8, sq // 8
		local kind = string.upper(piece)

		if kind == "P" then
			local dir = if white then 1 else -1
			local startRank = if white then 1 else 6
			local lastRank = if white then 7 else 0
			local nextRank = rank + dir

			local function add(to: number, captured: string, flag: string)
				if nextRank == lastRank then
					for _, letter in PROMO_ORDER do
						local promo = if white then string.upper(letter) else letter
						table.insert(moves, newMove(sq, to, piece, captured, promo, flag))
					end
				else
					table.insert(moves, newMove(sq, to, piece, captured, "", flag))
				end
			end

			local forward = nextRank * 8 + file
			if board[forward + 1] == "" then
				add(forward, "", "")
				if rank == startRank then
					local twoForward = (rank + 2 * dir) * 8 + file
					if board[twoForward + 1] == "" then
						table.insert(moves, newMove(sq, twoForward, piece, "", "", "double"))
					end
				end
			end
			for _, df in { -1, 1 } do
				local f = file + df
				if f >= 0 and f <= 7 then
					local target = nextRank * 8 + f
					local occupant = board[target + 1]
					if occupant ~= "" and isWhitePiece(occupant) ~= white then
						add(target, occupant, "")
					elseif occupant == "" and target == state.ep then
						table.insert(moves, newMove(sq, target, piece, if white then "p" else "P", "", "ep"))
					end
				end
			end
		elseif kind == "N" or kind == "K" then
			local steps: { { number } } = if kind == "N" then KNIGHT_STEPS else KING_STEPS
			for _, step in steps do
				local f, r = file + step[1], rank + step[2]
				if f >= 0 and f <= 7 and r >= 0 and r <= 7 then
					local target = r * 8 + f
					local occupant = board[target + 1]
					if occupant == "" or isWhitePiece(occupant) ~= white then
						table.insert(moves, newMove(sq, target, piece, occupant, "", ""))
					end
				end
			end
			if kind == "K" then
				local homeSq = if white then 4 else 60
				if sq == homeSq and not isAttacked(board, sq, not white) then
					local rook = if white then "R" else "r"
					local kingSide = if white then CASTLE_K else CASTLE_k
					local queenSide = if white then CASTLE_Q else CASTLE_q
					if
						bit32.band(state.castling, kingSide) ~= 0
						and board[sq + 4] == rook
						and board[sq + 2] == ""
						and board[sq + 3] == ""
						and not isAttacked(board, sq + 1, not white)
						and not isAttacked(board, sq + 2, not white)
					then
						table.insert(moves, newMove(sq, sq + 2, piece, "", "", "castleK"))
					end
					if
						bit32.band(state.castling, queenSide) ~= 0
						and board[sq - 3] == rook
						and board[sq] == ""
						and board[sq - 1] == ""
						and board[sq - 2] == ""
						and not isAttacked(board, sq - 1, not white)
						and not isAttacked(board, sq - 2, not white)
					then
						table.insert(moves, newMove(sq, sq - 2, piece, "", "", "castleQ"))
					end
				end
			end
		else
			local dirs = if kind == "R" then ROOK_DIRS elseif kind == "B" then BISHOP_DIRS else nil
			local function slide(list: { { number } })
				for _, dir in list do
					local f, r = file + dir[1], rank + dir[2]
					while f >= 0 and f <= 7 and r >= 0 and r <= 7 do
						local target = r * 8 + f
						local occupant = board[target + 1]
						if occupant == "" then
							table.insert(moves, newMove(sq, target, piece, "", "", ""))
						else
							if isWhitePiece(occupant) ~= white then
								table.insert(moves, newMove(sq, target, piece, occupant, "", ""))
							end
							break
						end
						f += dir[1]
						r += dir[2]
					end
				end
			end
			if dirs then
				slide(dirs)
			else
				slide(ROOK_DIRS)
				slide(BISHOP_DIRS)
			end
		end
	end
	return moves
end

-- Aplica un movimiento (asumido legal) y devuelve el nuevo estado.
function Rules.apply(state: State, move: Move): State
	local board = table.clone(state.board)
	local white = state.turn == "w"
	local piece = move.piece

	board[move.from + 1] = ""
	if move.flag == "ep" then
		local capturedSq = if white then move.to - 8 else move.to + 8
		board[capturedSq + 1] = ""
	elseif move.flag == "castleK" then
		board[move.to + 1 + 1] = "" -- torre en h
		board[move.to - 1 + 1] = if white then "R" else "r"
	elseif move.flag == "castleQ" then
		board[move.to - 2 + 1] = "" -- torre en a
		board[move.to + 1 + 1] = if white then "R" else "r"
	end
	board[move.to + 1] = if move.promo ~= "" then move.promo else piece

	local castling = state.castling
	castling = bit32.band(castling, RIGHTS_MASK[move.from] or 15)
	castling = bit32.band(castling, RIGHTS_MASK[move.to] or 15)

	-- La casilla de captura al paso solo se registra si algún peón rival puede usarla.
	local ep = -1
	if move.flag == "double" then
		local target = (move.from + move.to) // 2
		local enemyPawn = if white then "p" else "P"
		local file = move.to % 8
		if (file > 0 and board[move.to - 1 + 1] == enemyPawn) or (file < 7 and board[move.to + 1 + 1] == enemyPawn) then
			ep = target
		end
	end

	return {
		board = board,
		turn = if white then "b" else "w",
		castling = castling,
		ep = ep,
		halfmove = if string.upper(piece) == "P" or move.captured ~= "" then 0 else state.halfmove + 1,
		fullmove = if white then state.fullmove else state.fullmove + 1,
	}
end

-- Movimientos legales del bando que mueve.
function Rules.legalMoves(state: State): { Move }
	local white = state.turn == "w"
	local legal: { Move } = {}
	for _, move in pseudoMoves(state) do
		local after = Rules.apply(state, move)
		local kingSq = findKing(after.board, white)
		if kingSq >= 0 and not isAttacked(after.board, kingSq, not white) then
			table.insert(legal, move)
		end
	end
	return legal
end

local function insufficientMaterial(board: { string }): boolean
	local minors: { number } = {} -- casillas de alfiles/caballos
	local bishopColors: { [number]: boolean } = {}
	local minorCount = 0
	for sq = 0, 63 do
		local piece = board[sq + 1]
		local kind = string.upper(piece)
		if kind == "P" or kind == "R" or kind == "Q" then
			return false
		elseif kind == "N" or kind == "B" then
			minorCount += 1
			table.insert(minors, sq)
			if kind == "B" then
				bishopColors[(sq % 8 + sq // 8) % 2] = true
			end
		end
	end
	if minorCount <= 1 then
		return true
	end
	-- Solo alfiles, todos del mismo color de casilla.
	for _, sq in minors do
		if string.upper(board[sq + 1]) ~= "B" then
			return false
		end
	end
	local colors = 0
	for _ in bishopColors do
		colors += 1
	end
	return colors == 1
end

-- "playing" | "checkmate" | "stalemate" | "fifty" | "insufficient"
function Rules.getStatus(state: State, legalCount: number): string
	if legalCount == 0 then
		return if Rules.inCheck(state) then "checkmate" else "stalemate"
	end
	if insufficientMaterial(state.board) then
		return "insufficient"
	end
	if state.halfmove >= 100 then
		return "fifty"
	end
	return "playing"
end

-- Clave de posición para la repetición (misma posición, turno, enroques y captura al paso posible).
function Rules.positionKey(state: State): string
	return table.concat(state.board, ",") .. state.turn .. state.castling .. state.ep
end

function Rules.new(): State
	return Rules.fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") :: State
end

function Rules.fromFEN(fen: string): State?
	local m1, m2, m3, m4, m5, m6 = string.match(fen, "^(%S+)%s+([wb])%s+(%S+)%s+(%S+)%s*(%d*)%s*(%d*)")
	if not m1 then
		return nil
	end
	local placement, turn, castlingText, epText = m1 :: string, m2 :: string, m3 :: string, m4 :: string
	local half, full = m5 :: string, m6 :: string
	local board: { string } = table.create(64, "")
	local rank, file = 7, 0
	for char in string.gmatch(placement, ".") do
		if char == "/" then
			rank -= 1
			file = 0
		elseif string.match(char, "%d") then
			file += tonumber(char) :: number
		else
			board[rank * 8 + file + 1] = char
			file += 1
		end
	end
	local castling = 0
	if string.find(castlingText, "K", 1, true) then
		castling += CASTLE_K
	end
	if string.find(castlingText, "Q", 1, true) then
		castling += CASTLE_Q
	end
	if string.find(castlingText, "k", 1, true) then
		castling += CASTLE_k
	end
	if string.find(castlingText, "q", 1, true) then
		castling += CASTLE_q
	end
	local ep = -1
	if epText ~= "-" then
		ep = (string.byte(epText, 1) - 97) + (tonumber(string.sub(epText, 2, 2)) :: number - 1) * 8
	end
	return {
		board = board,
		turn = turn,
		castling = castling,
		ep = ep,
		halfmove = tonumber(half) or 0,
		fullmove = tonumber(full) or 1,
	}
end

-- Placement tipo FEN (sin el resto) para enviarlo al cliente.
function Rules.boardString(state: State): string
	local rows = {}
	for rank = 7, 0, -1 do
		local row, empty = "", 0
		for file = 0, 7 do
			local piece = state.board[rank * 8 + file + 1]
			if piece == "" then
				empty += 1
			else
				if empty > 0 then
					row ..= tostring(empty)
					empty = 0
				end
				row ..= piece
			end
		end
		if empty > 0 then
			row ..= tostring(empty)
		end
		table.insert(rows, row)
	end
	return table.concat(rows, "/")
end

function Rules.squareName(sq: number): string
	return string.char(97 + sq % 8) .. tostring(sq // 8 + 1)
end

local SAN_LETTERS: { [string]: string } = { K = "R", Q = "D", R = "T", B = "A", N = "C" } -- notación en español

-- Notación algebraica en español (R rey, D dama, T torre, A alfil, C caballo).
-- `legal` son los movimientos legales de `state` (antes de jugar `move`).
function Rules.notation(state: State, move: Move, legal: { Move }): string
	local text: string
	local kind = string.upper(move.piece)
	if move.flag == "castleK" then
		text = "O-O"
	elseif move.flag == "castleQ" then
		text = "O-O-O"
	elseif kind == "P" then
		text = ""
		if move.captured ~= "" then
			text = string.char(97 + move.from % 8) .. "x"
		end
		text ..= Rules.squareName(move.to)
		if move.promo ~= "" then
			text ..= "=" .. SAN_LETTERS[string.upper(move.promo)]
		end
	else
		text = SAN_LETTERS[kind]
		local sameFile, sameRank, ambiguous = false, false, false
		for _, other in legal do
			if other.to == move.to and other.piece == move.piece and other.from ~= move.from then
				ambiguous = true
				if other.from % 8 == move.from % 8 then
					sameFile = true
				end
				if other.from // 8 == move.from // 8 then
					sameRank = true
				end
			end
		end
		if ambiguous then
			if not sameFile then
				text ..= string.char(97 + move.from % 8)
			elseif not sameRank then
				text ..= tostring(move.from // 8 + 1)
			else
				text ..= Rules.squareName(move.from)
			end
		end
		if move.captured ~= "" then
			text ..= "x"
		end
		text ..= Rules.squareName(move.to)
	end

	local after = Rules.apply(state, move)
	if Rules.inCheck(after) then
		text ..= if #Rules.legalMoves(after) == 0 then "#" else "+"
	end
	return text
end

-- Perft para pruebas: número de posiciones alcanzables a profundidad `depth`.
function Rules.perft(state: State, depth: number): number
	if depth == 0 then
		return 1
	end
	local moves = Rules.legalMoves(state)
	if depth == 1 then
		return #moves
	end
	local total = 0
	for _, move in moves do
		total += Rules.perft(Rules.apply(state, move), depth - 1)
	end
	return total
end

return Rules

--!strict
-- Medidas, colores y materiales del tablero, las piezas y la interfaz (servidor y cliente).
-- Cambiar un valor aquí cambia el aspecto de todo el juego.

local Theme = {}

-- Geometría (studs). Casilla de 4 studs: el tablero mide 32 y las piezas 3-6,5 studs.
Theme.SquareSize = 4
Theme.BoardTopY = 5 -- altura de la superficie de las casillas
Theme.PieceScale = 1

Theme.Colors = {
	LightSquare = Color3.fromRGB(205, 178, 138),
	DarkSquare = Color3.fromRGB(108, 72, 52),
	Frame = Color3.fromRGB(46, 30, 24),
	Plinth = Color3.fromRGB(58, 38, 30),
	PlinthBase = Color3.fromRGB(22, 20, 24),
	Floor = Color3.fromRGB(20, 20, 25),
	Gold = Color3.fromRGB(212, 175, 98),
	Felt = Color3.fromRGB(34, 44, 40),
	White = Color3.fromRGB(246, 241, 229),
	Black = Color3.fromRGB(34, 33, 40),
	-- Resaltados (cliente)
	Select = Color3.fromRGB(120, 200, 255),
	Move = Color3.fromRGB(255, 255, 255),
	Capture = Color3.fromRGB(235, 80, 80),
	LastMove = Color3.fromRGB(255, 205, 90),
	Check = Color3.fromRGB(255, 60, 60),
	Hover = Color3.fromRGB(255, 255, 255),
}

Theme.Materials = {
	LightSquare = Enum.Material.Marble,
	DarkSquare = Enum.Material.Wood,
	Frame = Enum.Material.Wood,
	Plinth = Enum.Material.Wood,
	WhitePiece = Enum.Material.Marble,
	BlackPiece = Enum.Material.Slate,
	Gold = Enum.Material.Metal,
}

-- Tipos de pieza -> nombre (para la interfaz).
Theme.PieceNames = {
	P = "Peón",
	N = "Caballo",
	B = "Alfil",
	R = "Torre",
	Q = "Dama",
	K = "Rey",
}

-- Valor material (para mostrar la ventaja en la interfaz).
Theme.PieceValues = { P = 1, N = 3, B = 3, R = 5, Q = 9, K = 0 }

-- Centro de una casilla (0..63) sobre la superficie del tablero.
-- Blancas en +Z (fila 1), negras en -Z (fila 8); columna a en -X, h en +X.
function Theme.squareCenter(sq: number): Vector3
	local file, rank = sq % 8, sq // 8
	return Vector3.new((file - 3.5) * Theme.SquareSize, Theme.BoardTopY, (3.5 - rank) * Theme.SquareSize)
end

-- Casilla que contiene un punto del mundo, o nil si cae fuera del tablero.
function Theme.squareFromPoint(point: Vector3): number?
	local file = math.floor(point.X / Theme.SquareSize + 4)
	local rank = math.floor(3.5 - point.Z / Theme.SquareSize + 0.5)
	if file < 0 or file > 7 or rank < 0 or rank > 7 then
		return nil
	end
	return rank * 8 + file
end

-- Bandejas laterales donde se depositan las piezas capturadas.
-- Las piezas blancas capturadas van a la bandeja oeste (-X), las negras a la este (+X).
Theme.TrayX = 22.1
Theme.TrayPieceScale = 0.55

function Theme.traySlot(capturedIsWhite: boolean, index: number): Vector3
	local column = (index - 1) % 2
	local row = (index - 1) // 2
	local side = if capturedIsWhite then -1 else 1
	local x = side * (Theme.TrayX + (column - 0.5) * 1.7)
	local z = 14.2 - row * 3.9
	return Vector3.new(x, 4.62, z)
end

return Theme

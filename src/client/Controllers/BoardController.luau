--!strict
-- Pinta la partida: piezas 3D sobre el tablero (creado por el servidor), resaltados, bandejas de capturas
-- y todas las animaciones (movimiento en arco, captura hacia la bandeja, enroque, promoción, rey que cae).
-- Solo lee el estado que manda el servidor (GameController); no decide nada de las reglas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Config.ChessTheme)
local PieceFactory = require(ReplicatedStorage.Shared.Chess.PieceFactory)
local Animator = require(script.Parent.Parent.Chess.Animator)
local EffectsController = require(script.Parent.EffectsController)
local GameController = require(script.Parent.GameController)

local BoardController = {}

type Snapshot = GameController.Snapshot

local MARKER_Y = Theme.BoardTopY + 0.04
local DOT_POOL = 28
local RING_POOL = 10

local piecesFolder: Folder
local markersFolder: Folder
local squaresFolder: Folder? = nil

local prototypes: { [string]: Model } = {}
local models: { [number]: Model } = {} -- casilla -> pieza visible
local display: { string } = table.create(64, "") -- lo que se está mostrando (64 letras)
local tray: { w: { Model }, b: { Model } } = { w = {}, b = {} }

local pending: { Snapshot } = {}
local processing = false
local lastSeq = -1
local lastStatus = ""
local started = false

local selectMarker: Part
local hoverMarker: Part
local lastMarkers: { Part } = {}
local checkMarker: Part
local checkTween: Tween? = nil
local dots: { Part } = {}
local rings: { Part } = {}
local shownDots = 0
local shownRings = 0
local raycastParams = RaycastParams.new()

local function isWhite(letter: string): boolean
	return letter == string.upper(letter)
end

local function yawFor(letter: string): number
	return if isWhite(letter) then 0 else math.pi
end

local function pieceCFrame(position: Vector3, yaw: number): CFrame
	return CFrame.new(position) * CFrame.Angles(0, yaw, 0)
end

local function getPrototype(letter: string): Model
	local proto = prototypes[letter]
	if not proto then
		proto = PieceFactory.build(letter)
		prototypes[letter] = proto
	end
	return proto
end

local function newPiece(letter: string, sq: number): Model
	local model = getPrototype(letter):Clone()
	model:SetAttribute("Sq", sq)
	model:PivotTo(pieceCFrame(Theme.squareCenter(sq), yawFor(letter)))
	model.Parent = piecesFolder
	return model
end

-- ¿Se está viendo la partida desde las blancas? Solo afecta al giro de los caballos en la bandeja.
local function trayYaw(capturedIsWhite: boolean): number
	return if capturedIsWhite then -math.pi / 2 else math.pi / 2
end

local function placeInTray(model: Model, letter: string, index: number)
	local white = isWhite(letter)
	model:SetAttribute("Sq", -1)
	model:ScaleTo(Theme.TrayPieceScale)
	model:PivotTo(pieceCFrame(Theme.traySlot(white, index), trayYaw(white)))
	table.insert(if white then tray.w else tray.b, model)
end

------------------------------------------------------------------------------------------------
-- Marcadores de casilla (resaltados)
------------------------------------------------------------------------------------------------

local function squareMarker(name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 1
	part.Size = Vector3.new(Theme.SquareSize - 0.16, 0.05, Theme.SquareSize - 0.16)
	part.Position = Vector3.new(0, MARKER_Y, 0)
	part.Parent = markersFolder
	return part
end

local function moveMarker(marker: Part, sq: number, transparency: number)
	local center = Theme.squareCenter(sq)
	marker.Position = Vector3.new(center.X, MARKER_Y, center.Z)
	TweenService:Create(marker, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Transparency = transparency }):Play()
end

local function hideMarker(marker: Part)
	marker.Transparency = 1
end

-- Marcador con SurfaceGui (punto o aro) para movimientos legales.
local function guiMarker(isRing: boolean): Part
	local part = Instance.new("Part")
	part.Name = if isRing then "Ring" else "Dot"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(Theme.SquareSize - 0.2, 0.05, Theme.SquareSize - 0.2)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(200, 200)
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = part

	local shape = Instance.new("Frame")
	shape.AnchorPoint = Vector2.new(0.5, 0.5)
	shape.Position = UDim2.fromScale(0.5, 0.5)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = shape
	local scale = Instance.new("UIScale")
	scale.Parent = shape
	if isRing then
		shape.Size = UDim2.fromScale(0.9, 0.9)
		shape.BackgroundTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Colors.Capture
		stroke.Thickness = 12
		stroke.Transparency = 0.1
		stroke.Parent = shape
	else
		shape.Size = UDim2.fromScale(0.3, 0.3)
		shape.BackgroundColor3 = Theme.Colors.Move
		shape.BackgroundTransparency = 0.3
	end
	shape.Parent = gui
	return part
end

local function showGuiMarker(pool: { Part }, index: number, isRing: boolean, sq: number)
	local part = pool[index]
	if not part then
		part = guiMarker(isRing)
		pool[index] = part
	end
	local center = Theme.squareCenter(sq)
	part.Position = Vector3.new(center.X, MARKER_Y + 0.01, center.Z)
	part.Parent = markersFolder
	local scale = part:FindFirstChildWhichIsA("UIScale", true)
	if scale then
		scale.Scale = 0.4
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
end

local function hideGuiMarkers()
	for i = 1, shownDots do
		dots[i].Parent = nil
	end
	for i = 1, shownRings do
		rings[i].Parent = nil
	end
	shownDots, shownRings = 0, 0
end

-- Selecciona una casilla y muestra sus movimientos legales (nil = quitar selección).
function BoardController:ShowSelection(sq: number?)
	hideGuiMarkers()
	if not sq then
		hideMarker(selectMarker)
		return
	end
	moveMarker(selectMarker, sq, 0.5)
	local piece = GameController:PieceAt(sq)
	local isPawn = piece == "P" or piece == "p"
	for _, to in GameController:LegalFrom(sq) do
		local capture = GameController:PieceAt(to) ~= "" or (isPawn and to % 8 ~= sq % 8)
		if capture then
			shownRings += 1
			showGuiMarker(rings, shownRings, true, to)
		else
			shownDots += 1
			showGuiMarker(dots, shownDots, false, to)
		end
	end
end

function BoardController:SetHover(sq: number?)
	if sq then
		moveMarker(hoverMarker, sq, 0.88)
	else
		hideMarker(hoverMarker)
	end
end

local function updateHighlights(snapshot: Snapshot)
	local last = snapshot.last
	if last then
		moveMarker(lastMarkers[1], last.from, 0.62)
		moveMarker(lastMarkers[2], last.to, 0.55)
	else
		hideMarker(lastMarkers[1])
		hideMarker(lastMarkers[2])
	end

	if checkTween then
		checkTween:Cancel()
		checkTween = nil
	end
	if snapshot.check >= 0 then
		local center = Theme.squareCenter(snapshot.check)
		checkMarker.Position = Vector3.new(center.X, MARKER_Y + 0.01, center.Z)
		checkMarker.Transparency = 0.7
		local tween = TweenService:Create(
			checkMarker,
			TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.25 }
		)
		tween:Play()
		checkTween = tween
	else
		hideMarker(checkMarker)
	end
end

------------------------------------------------------------------------------------------------
-- Piezas: reconstrucción instantánea y animaciones
------------------------------------------------------------------------------------------------

local function decode(text: string): { string }
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

local function popIn(model: Model, delay: number)
	model:ScaleTo(0.05)
	task.delay(delay, function()
		if not model.Parent then
			return
		end
		local yaw = (model:GetPivot() - model:GetPivot().Position)
		local position = model:GetPivot().Position
		Animator.run(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function(alpha)
			model:ScaleTo(0.05 + 0.95 * alpha)
			model:PivotTo(CFrame.new(position) * yaw)
		end)
	end)
end

local function clearTray()
	for _, list in { tray.w, tray.b } do
		for _, model in list do
			model:Destroy()
		end
		table.clear(list)
	end
end

local function rebuildTray(captured: { w: { string }, b: { string } })
	if #tray.w == #captured.w and #tray.b == #captured.b then
		return
	end
	clearTray()
	for _, letter in captured.w do
		placeInTray(getPrototype(letter):Clone(), letter, #tray.w + 1)
		tray.w[#tray.w].Parent = piecesFolder
	end
	for _, letter in captured.b do
		placeInTray(getPrototype(letter):Clone(), letter, #tray.b + 1)
		tray.b[#tray.b].Parent = piecesFolder
	end
end

-- Deja el tablero exactamente como indica el servidor (sin animar movimientos).
local function reconcile(snapshot: Snapshot, force: boolean?)
	if force then
		for sq, model in models do
			model:Destroy()
			models[sq] = nil
		end
		display = table.create(64, "")
	end
	local target = decode(snapshot.board)
	local created = 0
	local order: { number } = {}
	for sq = 0, 63 do
		local want, have = target[sq + 1], display[sq + 1]
		if want ~= have then
			local model = models[sq]
			if model then
				model:Destroy()
				models[sq] = nil
			end
			display[sq + 1] = want
			if want ~= "" then
				models[sq] = newPiece(want, sq)
				created += 1
				table.insert(order, sq)
			end
		end
	end
	-- Aparición escalonada cuando se coloca el tablero entero (inicio de partida).
	if created >= 16 then
		for index, sq in order do
			local model = models[sq]
			if model then
				popIn(model, (sq % 8) * 0.04 + (index % 3) * 0.03)
			end
		end
	end
	rebuildTray(snapshot.captured)
	lastSeq = snapshot.seq
end

local function mismatch(snapshot: Snapshot): boolean
	local target = decode(snapshot.board)
	for i = 1, 64 do
		if target[i] ~= display[i] then
			return true
		end
	end
	return false
end

-- Anima una pieza de A a B con arco y ligera inclinación en la dirección del movimiento.
local function slide(
	model: Model,
	from: Vector3,
	to: Vector3,
	yaw: number,
	lift: number,
	duration: number,
	onProgress: ((number) -> ())?
): Animator.Handle
	local delta = to - from
	local direction = if delta.Magnitude > 0.01 then delta.Unit else Vector3.zAxis
	local axis = Vector3.yAxis:Cross(direction)
	return Animator.run(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, function(alpha)
		local height = math.sin(alpha * math.pi) * lift
		local lean = CFrame.fromAxisAngle(axis, math.sin(alpha * math.pi) * 0.1)
		model:PivotTo(CFrame.new(from:Lerp(to, alpha) + Vector3.new(0, height, 0)) * lean * CFrame.Angles(0, yaw, 0))
		if onProgress then
			onProgress(alpha)
		end
	end)
end

-- Lleva una pieza capturada a su hueco en la bandeja con un salto y un giro.
local function sendToTray(model: Model, letter: string, from: Vector3)
	local white = isWhite(letter)
	local list = if white then tray.w else tray.b
	local index = #list + 1
	local slot = Theme.traySlot(white, index)
	local startYaw = yawFor(letter)
	local endYaw = trayYaw(white)
	model:SetAttribute("Sq", -1)
	table.insert(list, model) -- se reserva el hueco enseguida
	Animator.run(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, function(alpha)
		local height = math.sin(alpha * math.pi) * 5
		model:ScaleTo(1 - (1 - Theme.TrayPieceScale) * alpha)
		model:PivotTo(
			CFrame.new(from:Lerp(slot, alpha) + Vector3.new(0, height, 0))
				* CFrame.Angles(0, startYaw + (endYaw - startYaw) * alpha + alpha * math.pi * 2, 0)
		)
	end, function()
		model:ScaleTo(Theme.TrayPieceScale)
		model:PivotTo(pieceCFrame(slot, endYaw))
	end)
end

local function animateMove(move: { [string]: any })
	local fromSq, toSq = move.from :: number, move.to :: number
	local piece: string = move.piece
	local white = isWhite(piece)
	local kind = string.upper(piece)
	local model = models[fromSq]
	if not model then
		return
	end

	local capSq = toSq
	if move.flag == "ep" then
		capSq = if white then toSq - 8 else toSq + 8
	end
	local capModel = if move.captured ~= "" then models[capSq] else nil
	if capModel then
		models[capSq] = nil
		display[capSq + 1] = ""
	end

	local rookModel: Model? = nil
	local rookFrom, rookTo = -1, -1
	if move.flag == "castleK" then
		rookFrom, rookTo = toSq + 1, toSq - 1
	elseif move.flag == "castleQ" then
		rookFrom, rookTo = toSq - 2, toSq + 1
	end
	if rookFrom >= 0 then
		rookModel = models[rookFrom]
		models[rookFrom] = nil
	end

	models[fromSq] = nil
	display[fromSq + 1] = ""
	local startPos, endPos = Theme.squareCenter(fromSq), Theme.squareCenter(toSq)
	local distance = (endPos - startPos).Magnitude
	local duration = math.min(0.85, 0.34 + distance * 0.022)
	local lift = if kind == "N" then 3.4 else 1.0

	EffectsController:Play("Select", 0.04)

	local impacted = false
	local finished = false
	local thread = coroutine.running()

	if rookModel and rookFrom >= 0 then
		local rookPiece = display[rookFrom + 1]
		local rookYaw = yawFor(rookPiece)
		display[rookTo + 1] = rookPiece
		display[rookFrom + 1] = ""
		slide(rookModel, Theme.squareCenter(rookFrom), Theme.squareCenter(rookTo), rookYaw, 0.8, duration, nil)
	end

	slide(model, startPos, endPos, yawFor(piece), lift, duration, function(alpha)
		if not impacted and capModel and alpha >= 0.7 then
			impacted = true
			EffectsController:Burst("Capture", endPos + Vector3.new(0, 1.2, 0), 22)
			sendToTray(capModel :: Model, move.captured, Theme.squareCenter(capSq))
		end
		if alpha >= 1 and not finished then
			finished = true
			task.spawn(thread)
		end
	end)
	coroutine.yield()

	if rookModel then
		rookModel:SetAttribute("Sq", rookTo)
		models[rookTo] = rookModel
	end

	-- Aterrizaje (promoción: el peón se sustituye por la nueva pieza con un destello).
	local landedLetter = piece
	if move.promo ~= "" then
		model:Destroy()
		landedLetter = move.promo
		model = newPiece(landedLetter, toSq)
		popIn(model, 0)
		EffectsController:Burst("Promote", endPos + Vector3.new(0, 2.5, 0), 30)
		EffectsController:Play("Promote")
	else
		model:SetAttribute("Sq", toSq)
	end
	models[toSq] = model
	display[toSq + 1] = landedLetter

	if move.flag == "castleK" or move.flag == "castleQ" then
		EffectsController:Play("Castle")
	elseif move.captured ~= "" then
		EffectsController:Play("Capture", 0.08)
	else
		EffectsController:Play("Move")
	end
end

-- El rey derrotado cae de lado (jaque mate).
local function toppleKing(sq: number)
	local model = models[sq]
	if not model then
		return
	end
	local letter = display[sq + 1]
	local radius = 1.0
	local base = Theme.squareCenter(sq)
	local edge = base + Vector3.new(radius, 0, 0)
	local yaw = CFrame.Angles(0, yawFor(letter), 0)
	task.delay(0.35, function()
		Animator.run(0.9, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, function(alpha)
			model:PivotTo(
				CFrame.new(edge) * CFrame.Angles(0, 0, -alpha * math.pi / 2) * CFrame.new(-radius, 0, 0) * yaw
			)
		end)
	end)
end

local function findKing(white: boolean): number?
	local letter = if white then "K" else "k"
	for i = 1, 64 do
		if display[i] == letter then
			return i - 1
		end
	end
	return nil
end

local function onResult(snapshot: Snapshot)
	local result = snapshot.result
	if not result then
		return
	end
	local seat = GameController:MySeat()
	if result.winner == "draw" then
		EffectsController:Play("Draw")
	elseif seat == nil or result.winner == seat then
		EffectsController:Play("Win")
		EffectsController:Burst("Victory", Vector3.new(0, Theme.BoardTopY + 2, 0), 60)
	else
		EffectsController:Play("Lose")
	end
	if result.reason == "checkmate" then
		local loserIsWhite = result.winner == "b"
		local kingSq = findKing(loserIsWhite)
		if kingSq then
			toppleKing(kingSq)
		end
	end
end

local function process(snapshot: Snapshot)
	BoardController:ShowSelection(nil)
	local move = snapshot.move
	if move and snapshot.seq == lastSeq + 1 then
		animateMove(move)
		lastSeq = snapshot.seq
		if mismatch(snapshot) then
			reconcile(snapshot)
		end
	else
		-- Partida nueva (revancha) o salto en la secuencia: se reconstruye todo desde cero.
		reconcile(snapshot, snapshot.seq < lastSeq or (lastStatus == "over" and snapshot.status ~= "over"))
	end
	updateHighlights(snapshot)

	if snapshot.check >= 0 and snapshot.status == "playing" then
		EffectsController:Play("Check")
	end
	if snapshot.status == "over" and lastStatus ~= "over" then
		onResult(snapshot)
	end
	lastStatus = snapshot.status
end

local function drain()
	processing = true
	while #pending > 0 do
		local snapshot = table.remove(pending, 1) :: Snapshot
		local ok, err = pcall(process, snapshot)
		if not ok then
			warn("[BoardController] Error al pintar el estado: " .. tostring(err))
			pcall(reconcile, snapshot)
		end
	end
	processing = false
end

local function onUpdate(snapshot: Snapshot)
	if not started then
		return
	end
	table.insert(pending, snapshot)
	if not processing then
		task.spawn(drain)
	end
end

------------------------------------------------------------------------------------------------
-- API pública
------------------------------------------------------------------------------------------------

-- Devuelve la casilla (0..63) bajo un rayo, o nil. Usa piezas y casillas como objetivo.
function BoardController:Pick(origin: Vector3, direction: Vector3): number?
	local result = workspace:Raycast(origin, direction, raycastParams)
	if not result then
		return nil
	end
	local instance: Instance? = result.Instance
	local fromSquare = instance and instance:GetAttribute("Square")
	if type(fromSquare) == "number" then
		return fromSquare
	end
	while instance and instance.Parent ~= piecesFolder do
		instance = instance.Parent
	end
	if instance then
		local sq = instance:GetAttribute("Sq")
		if type(sq) == "number" and sq >= 0 then
			return sq
		end
	end
	return nil
end

-- Mientras una jugada se anima no se aceptan más clics.
function BoardController:IsBusy(): boolean
	return processing
end

function BoardController:Init()
	local runtime = workspace:FindFirstChild("Runtime")
	piecesFolder = Instance.new("Folder")
	piecesFolder.Name = "ChessPieces"
	piecesFolder.Parent = runtime or workspace
	markersFolder = Instance.new("Folder")
	markersFolder.Name = "ChessMarkers"
	markersFolder.Parent = runtime or workspace
end

function BoardController:Start()
	local board = workspace:WaitForChild("Map"):WaitForChild("ChessBoard")
	squaresFolder = board:WaitForChild("Squares") :: Folder
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { squaresFolder :: Folder, piecesFolder }

	selectMarker = squareMarker("Select", Theme.Colors.Select)
	hoverMarker = squareMarker("Hover", Theme.Colors.Hover)
	checkMarker = squareMarker("Check", Theme.Colors.Check)
	lastMarkers = { squareMarker("LastFrom", Theme.Colors.LastMove), squareMarker("LastTo", Theme.Colors.LastMove) }
	for i = 1, DOT_POOL do
		dots[i] = guiMarker(false)
	end
	for i = 1, RING_POOL do
		rings[i] = guiMarker(true)
	end

	-- Precarga los 12 modelos para que la primera partida no tenga tirones.
	for _, letter in { "P", "N", "B", "R", "Q", "K", "p", "n", "b", "r", "q", "k" } do
		getPrototype(letter)
	end

	started = true
	GameController:OnUpdate(onUpdate)
end

return BoardController

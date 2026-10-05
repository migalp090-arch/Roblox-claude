--!strict
-- Interfaz del ajedrez: turno, relojes, jugadores y capturas, historial, vistas de cámara, abandonar / tablas,
-- sala de espera, promoción y pantalla de resultado. Se adapta a PC (paneles laterales) y móvil (barras).
-- Solo muestra lo que dice el servidor; los botones únicamente envían peticiones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Theme = require(ReplicatedStorage.Shared.Config.ChessTheme)
local Kit = require(script.Parent.Parent.UI.Kit)
local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local GameController = require(script.Parent.GameController)
local UIController = require(script.Parent.UIController)

local ChessUIController = {}

type Snapshot = GameController.Snapshot

type Card = {
	frame: Frame,
	avatar: ImageLabel,
	name: TextLabel,
	role: TextLabel,
	captured: TextLabel,
	clockFrame: Frame,
	clock: TextLabel,
	stroke: UIStroke,
}

local Colors = Kit.Colors
local WIDE_MIN_WIDTH = 1000

local GLYPH = { P = "♟", N = "♞", B = "♝", R = "♜", Q = "♛", K = "♚" }
local REASONS: { [string]: string } = {
	checkmate = "Jaque mate",
	stalemate = "Rey ahogado",
	timeout = "Por tiempo",
	timeout_insufficient = "Tiempo agotado, material insuficiente",
	resign = "Por abandono",
	abandon = "El rival abandonó la partida",
	agreement = "Tablas por acuerdo",
	repetition = "Triple repetición",
	fifty = "Regla de las 50 jugadas",
	insufficient = "Material insuficiente",
}
local SIDE_NAMES: { [string]: string } = { w = "Blancas", b = "Negras" }

local root: Frame
local container: Frame
local uiScale: UIScale
local cards: { [string]: Card } = {}
local compact = false
local snapshot: Snapshot? = nil

local pill: Frame
local pillDot: Frame
local pillText: TextLabel
local historyPanel: Frame
local historyList: ScrollingFrame
local historyTitle: TextLabel
local viewRow: Frame
local viewButtons: { [string]: TextButton } = {}
local viewCycle: TextButton
local actionRow: Frame
local drawButton: TextButton
local resignButton: TextButton
local historyToggle: TextButton
local lobby: Frame
local lobbyButtons: { [string]: TextButton } = {}
local lobbySub: { [string]: TextLabel } = {}
local lobbyStatus: TextLabel
local lobbySolo: TextButton
local lobbyLeave: TextButton
local endCard: Frame
local endTitle: TextLabel
local endReason: TextLabel
local endRematch: TextButton
local endLeave: TextButton
local endView: TextButton
local drawBanner: Frame
local drawText: TextLabel
local promotion: Frame
local promotionDim: TextButton
local spectator: TextLabel

local historyRows = 0
local historyOpen = false
local endToken = 0
local endDismissed = false
local resignArmedUntil = 0
local promotionOpen = false
local promotionCallback: ((letter: string) -> ())? = nil
local avatarCache: { [number]: string } = {}
local clockAccumulator = 0

------------------------------------------------------------------------------------------------
-- Utilidades
------------------------------------------------------------------------------------------------

local function formatClock(seconds: number): string
	seconds = math.max(0, seconds)
	if seconds < 20 then
		return string.format("0:%04.1f", math.floor(seconds * 10) / 10)
	end
	local whole = math.ceil(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function remainingFor(data: Snapshot, seat: string): number
	local time: number = data.clocks[seat]
	if data.status == "playing" and data.turn == seat then
		time -= workspace:GetServerTimeNow() - data.turnStart
	end
	return math.max(0, time)
end

local function playerName(data: Snapshot, seat: string): string
	local info = data.seats[seat]
	return if info then info.name else "—"
end

local function loadAvatar(userId: number, target: ImageLabel)
	if avatarCache[userId] then
		target.Image = avatarCache[userId]
		return
	end
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and content then
			avatarCache[userId] = content
			target.Image = content
		end
	end)
end

------------------------------------------------------------------------------------------------
-- Construcción
------------------------------------------------------------------------------------------------

local function buildCard(seat: string): Card
	local frame = Kit.panel(container, "Card" .. seat, { Size = UDim2.fromOffset(280, 92) })
	local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundColor3 = Colors.PanelLight
	avatar.BorderSizePixel = 0
	avatar.Size = UDim2.fromOffset(54, 54)
	avatar.Position = UDim2.fromOffset(12, 19)
	Kit.corner(avatar, 27)
	Kit.stroke(avatar, if seat == "w" then Theme.Colors.White else Color3.fromRGB(90, 90, 100), 2, 0.2)
	avatar.Parent = frame

	local name = Kit.label(frame, "Name", "—", {
		Font = Kit.Fonts.Bold,
		TextSize = 17,
		Size = UDim2.fromOffset(110, 20),
		Position = UDim2.fromOffset(76, 14),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local role = Kit.label(frame, "Role", SIDE_NAMES[seat], {
		TextSize = 13,
		TextColor3 = Colors.Muted,
		Size = UDim2.fromOffset(110, 16),
		Position = UDim2.fromOffset(76, 35),
	})
	local captured = Kit.label(frame, "Captured", "", {
		TextSize = 18,
		RichText = true,
		Size = UDim2.fromOffset(190, 24),
		Position = UDim2.fromOffset(76, 58),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local clockFrame = Kit.frame(frame, "Clock", {
		Size = UDim2.fromOffset(86, 36),
		Position = UDim2.fromOffset(184, 14),
		BackgroundTransparency = 0.3,
		BackgroundColor3 = Color3.fromRGB(10, 10, 14),
	})
	Kit.corner(clockFrame, 8)
	local clock = Kit.label(clockFrame, "Time", "10:00", {
		Font = Kit.Fonts.Mono,
		TextSize = 22,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	return {
		frame = frame,
		avatar = avatar,
		name = name,
		role = role,
		captured = captured,
		clockFrame = clockFrame,
		clock = clock,
		stroke = stroke,
	}
end

local function layoutCard(card: Card, width: number, height: number)
	card.frame.Size = UDim2.fromOffset(width, height)
	card.avatar.Visible = not compact
	if compact then
		card.name.Position = UDim2.fromOffset(10, 6)
		card.name.Size = UDim2.fromOffset(width - 106, 18)
		card.name.TextSize = 15
		card.role.Position = UDim2.fromOffset(10, 25)
		card.role.Size = UDim2.fromOffset(width - 106, 14)
		card.captured.Position = UDim2.fromOffset(10, 40)
		card.captured.Size = UDim2.fromOffset(width - 20, 20)
		card.captured.TextSize = 15
		card.clockFrame.Position = UDim2.fromOffset(width - 92, 8)
		card.clockFrame.Size = UDim2.fromOffset(84, 30)
		card.clock.TextSize = 19
	else
		card.name.Position = UDim2.fromOffset(76, 14)
		card.name.Size = UDim2.fromOffset(width - 170, 20)
		card.name.TextSize = 17
		card.role.Position = UDim2.fromOffset(76, 35)
		card.role.Size = UDim2.fromOffset(width - 170, 16)
		card.captured.Position = UDim2.fromOffset(76, 58)
		card.captured.Size = UDim2.fromOffset(width - 88, 24)
		card.captured.TextSize = 18
		card.clockFrame.Position = UDim2.fromOffset(width - 96, 14)
		card.clockFrame.Size = UDim2.fromOffset(86, 36)
		card.clock.TextSize = 22
	end
end

local function buildPill()
	pill = Kit.panel(container, "TurnPill", {
		Size = UDim2.fromOffset(250, 40),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0.1,
	})
	Kit.corner(pill, 20)
	pillDot = Kit.frame(pill, "Dot", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(16, 13),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Colors.White,
	})
	Kit.corner(pillDot, 7)
	Kit.stroke(pillDot, Colors.Gold, 1.5, 0.1)
	pillText = Kit.label(pill, "Text", "", {
		Font = Kit.Fonts.Bold,
		TextSize = 16,
		Size = UDim2.new(1, -44, 1, 0),
		Position = UDim2.fromOffset(38, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

local function buildHistory()
	historyPanel = Kit.panel(container, "History", { Size = UDim2.fromOffset(300, 400) })
	historyTitle = Kit.label(historyPanel, "Title", "PARTIDA", {
		Font = Kit.Fonts.Title,
		TextSize = 15,
		TextColor3 = Colors.Gold,
		Size = UDim2.new(1, -28, 0, 40),
		Position = UDim2.fromOffset(16, 0),
	})
	Kit.frame(historyPanel, "Divider", {
		Size = UDim2.new(1, -32, 0, 1),
		Position = UDim2.fromOffset(16, 40),
		BackgroundTransparency = 0.6,
		BackgroundColor3 = Colors.Stroke,
	})

	historyList = Instance.new("ScrollingFrame")
	historyList.Name = "List"
	historyList.BackgroundTransparency = 1
	historyList.BorderSizePixel = 0
	historyList.Size = UDim2.new(1, -16, 1, -52)
	historyList.Position = UDim2.fromOffset(8, 46)
	historyList.ScrollBarThickness = 3
	historyList.ScrollBarImageColor3 = Colors.Gold
	historyList.CanvasSize = UDim2.new()
	historyList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	historyList.Parent = historyPanel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = historyList
end

local function addHistoryRow(index: number, white: string, black: string?)
	local row = Kit.frame(historyList, "Row" .. index, {
		Size = UDim2.new(1, -8, 0, 30),
		LayoutOrder = index,
		BackgroundTransparency = if index % 2 == 0 then 1 else 0.88,
		BackgroundColor3 = Colors.PanelLight,
	})
	Kit.corner(row, 6)
	Kit.label(row, "Number", `{index}.`, {
		TextColor3 = Colors.Muted,
		TextSize = 14,
		Size = UDim2.fromOffset(40, 30),
		Position = UDim2.fromOffset(8, 0),
	})
	Kit.label(
		row,
		"White",
		white,
		{ Font = Kit.Fonts.Body, TextSize = 16, Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromOffset(50, 0) }
	)
	Kit.label(
		row,
		"Black",
		black or "",
		{ Font = Kit.Fonts.Body, TextSize = 16, Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0.5, 24, 0, 0) }
	)
end

local function buildControls()
	viewRow = Kit.frame(container, "Views", { Size = UDim2.fromOffset(300, 40) })
	local views: { { id: CameraController.View, text: string } } = {
		{ id = "play", text = "Juego" },
		{ id = "cinematic", text = "Cine" },
		{ id = "top", text = "Cenital" },
	}
	for index, entry in views do
		local id = (entry.id :: any) :: CameraController.View
		local button = Kit.button(viewRow, id, entry.text, "soft", {
			Size = UDim2.new(1 / 3, -6, 1, 0),
			Position = UDim2.new((index - 1) / 3, if index == 1 then 0 else 4, 0, 0),
			TextSize = 14,
		}, function()
			CameraController:SetView(id)
		end)
		viewButtons[id] = button
	end
	viewCycle = Kit.button(
		container,
		"ViewCycle",
		"Vista",
		"soft",
		{ Size = UDim2.fromOffset(100, 40), TextSize = 14 },
		function()
			CameraController:CycleView()
		end
	)

	actionRow = Kit.frame(container, "Actions", { Size = UDim2.fromOffset(300, 46) })
	drawButton = Kit.button(actionRow, "Draw", "Ofrecer tablas", "ghost", {
		Size = UDim2.new(0.5, -4, 1, 0),
		TextSize = 14,
	}, function()
		GameController:Action("offerDraw")
	end)
	resignButton = Kit.button(actionRow, "Resign", "Abandonar", "danger", {
		Size = UDim2.new(0.5, -4, 1, 0),
		Position = UDim2.new(0.5, 4, 0, 0),
		TextSize = 14,
	}, function()
		if os.clock() < resignArmedUntil then
			resignArmedUntil = 0
			resignButton.Text = "Abandonar"
			GameController:Action("resign")
		else
			resignArmedUntil = os.clock() + 3
			resignButton.Text = "¿Seguro?"
			task.delay(3.05, function()
				if os.clock() >= resignArmedUntil then
					resignButton.Text = "Abandonar"
				end
			end)
		end
	end)

	historyToggle = Kit.button(
		container,
		"HistoryToggle",
		"Jugadas",
		"soft",
		{ Size = UDim2.fromOffset(100, 40), TextSize = 14 },
		function()
			historyOpen = not historyOpen
			historyPanel.Visible = historyOpen
		end
	)

	CameraController:OnViewChanged(function(view)
		for id, button in viewButtons do
			local active = id == view
			button.BackgroundColor3 = if active then Colors.Gold else Colors.PanelLight
			button.TextColor3 = if active then Color3.fromRGB(28, 22, 12) else Colors.Text
			button.BackgroundTransparency = if active then 0 else 0.2
		end
		viewCycle.Text = (
			{ play = "Vista: Juego", cinematic = "Vista: Cine", top = "Vista: Cenital" } :: { [string]: string }
		)[view]
	end)
end

local function buildLobby()
	lobby = Kit.panel(container, "Lobby", {
		Size = UDim2.fromOffset(440, 330),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	Kit.corner(lobby, 18)
	Kit.label(lobby, "Title", "AJEDREZ", {
		Font = Kit.Fonts.Title,
		TextSize = 38,
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromOffset(0, 22),
	})
	local minutes = GameConfig.Chess.TimeSeconds // 60
	Kit.label(lobby, "Subtitle", `Partida 1 contra 1 · {minutes} min + {GameConfig.Chess.IncrementSeconds} s`, {
		TextColor3 = Colors.Muted,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 78),
	})

	for index, seat in { "w", "b" } do
		local button = Kit.button(lobby, "Sit" .. seat, SIDE_NAMES[seat], if seat == "w" then "primary" else "ghost", {
			Size = UDim2.fromOffset(188, 84),
			Position = UDim2.fromOffset(24 + (index - 1) * 204, 120),
			TextSize = 22,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, function()
			GameController:Sit(if seat == "w" then "white" else "black")
		end)
		Kit.padding(button, 0, 14, 0, 0)
		lobbyButtons[seat] = button
		lobbySub[seat] = Kit.label(button, "Sub", "Libre", {
			Font = Kit.Fonts.Body,
			TextSize = 14,
			TextColor3 = if seat == "w" then Color3.fromRGB(70, 52, 20) else Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 40),
		})
	end

	lobbyStatus = Kit.label(lobby, "Status", "", {
		TextSize = 16,
		TextColor3 = Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 220),
	})
	lobbySolo = Kit.button(lobby, "Solo", "Practicar solo (Studio)", "soft", {
		Size = UDim2.fromOffset(250, 38),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 262),
		TextSize = 14,
	}, function()
		GameController:Sit("solo")
	end)
	lobbyLeave = Kit.button(lobby, "Leave", "Salir del asiento", "ghost", {
		Size = UDim2.fromOffset(200, 38),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 262),
		TextSize = 14,
	}, function()
		GameController:Action("leave")
	end)
end

local function buildEndCard()
	endCard = Kit.panel(container, "EndCard", {
		Size = UDim2.fromOffset(400, 250),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		BackgroundTransparency = 0.04,
		Visible = false,
	})
	Kit.corner(endCard, 18)
	endTitle = Kit.label(endCard, "Title", "", {
		Font = Kit.Fonts.Title,
		TextSize = 40,
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 26),
	})
	endReason = Kit.label(endCard, "Reason", "", {
		TextSize = 17,
		TextColor3 = Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -40, 0, 24),
		Position = UDim2.fromOffset(20, 90),
	})
	endRematch = Kit.button(endCard, "Rematch", "Revancha", "primary", {
		Size = UDim2.fromOffset(170, 46),
		Position = UDim2.fromOffset(20, 140),
		TextSize = 17,
	}, function()
		GameController:Action("rematch")
	end)
	endLeave = Kit.button(endCard, "Leave", "Salir", "ghost", {
		Size = UDim2.fromOffset(170, 46),
		Position = UDim2.fromOffset(210, 140),
		TextSize = 17,
	}, function()
		GameController:Action("leave")
	end)
	endView = Kit.button(endCard, "View", "Ver tablero", "soft", {
		Size = UDim2.fromOffset(180, 34),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 200),
		TextSize = 14,
	}, function()
		endDismissed = true
		endCard.Visible = false
	end)
end

local function buildBanners()
	drawBanner = Kit.panel(container, "DrawBanner", {
		Size = UDim2.fromOffset(340, 100),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
	})
	drawText = Kit.label(drawBanner, "Text", "El rival ofrece tablas", {
		Font = Kit.Fonts.Bold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 6),
	})
	Kit.button(drawBanner, "Accept", "Aceptar", "primary", {
		Size = UDim2.fromOffset(150, 38),
		Position = UDim2.fromOffset(14, 48),
		TextSize = 15,
	}, function()
		GameController:Action("acceptDraw")
	end)
	Kit.button(drawBanner, "Decline", "Rechazar", "ghost", {
		Size = UDim2.fromOffset(150, 38),
		Position = UDim2.fromOffset(176, 48),
		TextSize = 15,
	}, function()
		GameController:Action("declineDraw")
	end)

	spectator = Kit.label(container, "Spectator", "Estás espectando la partida", {
		TextSize = 14,
		TextColor3 = Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(300, 20),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
	})
end

local function buildPromotion()
	promotionDim = Instance.new("TextButton")
	promotionDim.Name = "PromotionDim"
	promotionDim.Text = ""
	promotionDim.AutoButtonColor = false
	promotionDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	promotionDim.BackgroundTransparency = 0.55
	promotionDim.BorderSizePixel = 0
	promotionDim.Size = UDim2.fromScale(1, 1)
	promotionDim.Visible = false
	promotionDim.ZIndex = 20
	promotionDim.Activated:Connect(function()
		ChessUIController:CancelPromotion()
	end)
	promotionDim.Parent = container

	promotion = Kit.panel(promotionDim, "Promotion", {
		Size = UDim2.fromOffset(440, 150),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 21,
	})
	Kit.label(promotion, "Title", "Promociona tu peón", {
		Font = Kit.Fonts.Title,
		TextSize = 17,
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 6),
		ZIndex = 22,
	})
	local choices = { { "q", "Dama", "Q" }, { "r", "Torre", "R" }, { "b", "Alfil", "B" }, { "n", "Caballo", "N" } }
	for index, entry in choices do
		local button = Kit.button(promotion, "Choose" .. entry[1], "", "ghost", {
			Size = UDim2.fromOffset(94, 92),
			Position = UDim2.fromOffset(14 + (index - 1) * 104, 44),
			ZIndex = 22,
		}, function()
			local callback = promotionCallback
			ChessUIController:CancelPromotion()
			if callback then
				callback(entry[1])
			end
		end)
		Kit.label(button, "Glyph", GLYPH[entry[3]], {
			Font = Kit.Fonts.Bold,
			TextSize = 44,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 56),
			Position = UDim2.fromOffset(0, 4),
			ZIndex = 23,
			Name = "Glyph",
		})
		Kit.label(button, "Name", entry[2], {
			Font = Kit.Fonts.Bold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 62),
			ZIndex = 23,
		})
	end
end

------------------------------------------------------------------------------------------------
-- Diseño adaptable
------------------------------------------------------------------------------------------------

local function layout()
	local camera = workspace.CurrentCamera
	local size = camera.ViewportSize
	compact = size.X < WIDE_MIN_WIDTH
	local scale = if compact
		then math.clamp(math.min(size.X / 760, size.Y / 480), 0.75, 1.15)
		else math.clamp(size.Y / 860, 0.85, 1.3)
	uiScale.Scale = scale
	container.Size = UDim2.fromScale(1 / scale, 1 / scale)
	local width, height = size.X / scale, size.Y / scale

	if not compact then
		local margin = 24
		layoutCard(cards.top, 290, 92)
		layoutCard(cards.bottom, 290, 92)
		cards.top.frame.AnchorPoint = Vector2.new(0, 0)
		cards.top.frame.Position = UDim2.fromOffset(margin, margin)
		cards.bottom.frame.AnchorPoint = Vector2.new(0, 1)
		cards.bottom.frame.Position = UDim2.fromOffset(margin, height - margin)

		pill.Position = UDim2.fromOffset(width / 2, margin)
		spectator.Position = UDim2.fromOffset(width / 2, margin + 46)

		local panelWidth = 300
		local x = width - margin - panelWidth
		local actionsHeight, viewsHeight = 46, 40
		local gap = 10
		actionRow.Size = UDim2.fromOffset(panelWidth, actionsHeight)
		actionRow.Position = UDim2.fromOffset(x, height - margin - actionsHeight)
		viewRow.Size = UDim2.fromOffset(panelWidth, viewsHeight)
		viewRow.Position = UDim2.fromOffset(x, height - margin - actionsHeight - gap - viewsHeight)
		local historyHeight = height - margin * 2 - actionsHeight - viewsHeight - gap * 2
		historyPanel.Size = UDim2.fromOffset(panelWidth, historyHeight)
		historyPanel.Position = UDim2.fromOffset(x, margin)
		historyPanel.AnchorPoint = Vector2.new(0, 0)
		historyPanel.Visible = true
		viewRow.Visible = true
		viewCycle.Visible = false
		historyToggle.Visible = false
		drawBanner.Position = UDim2.fromOffset(width / 2, margin + 52)
	else
		local margin = 8
		local cardWidth = (width - margin * 3) / 2
		layoutCard(cards.top, cardWidth, 66)
		layoutCard(cards.bottom, cardWidth, 66)
		cards.top.frame.AnchorPoint = Vector2.new(0, 0)
		cards.top.frame.Position = UDim2.fromOffset(margin, margin)
		cards.bottom.frame.AnchorPoint = Vector2.new(0, 0)
		cards.bottom.frame.Position = UDim2.fromOffset(margin * 2 + cardWidth, margin)

		pill.Position = UDim2.fromOffset(width / 2, margin + 72)
		spectator.Position = UDim2.fromOffset(width / 2, margin + 118)
		drawBanner.Position = UDim2.fromOffset(width / 2, margin + 120)

		-- Barra inferior: Jugadas | Vista | Tablas | Abandonar
		local barHeight = 42
		local y = height - margin - barHeight
		local slot = (width - margin * 5) / 4
		historyToggle.Size = UDim2.fromOffset(slot, barHeight)
		historyToggle.Position = UDim2.fromOffset(margin, y)
		viewCycle.Size = UDim2.fromOffset(slot, barHeight)
		viewCycle.Position = UDim2.fromOffset(margin * 2 + slot, y)
		actionRow.Size = UDim2.fromOffset(slot * 2 + margin, barHeight)
		actionRow.Position = UDim2.fromOffset(margin * 3 + slot * 2, y)
		viewRow.Visible = false
		viewCycle.Visible = true
		historyToggle.Visible = true
		historyPanel.AnchorPoint = Vector2.new(0.5, 1)
		historyPanel.Size = UDim2.fromOffset(math.min(width - margin * 2, 420), math.min(height * 0.5, 320))
		historyPanel.Position = UDim2.fromOffset(width / 2, y - margin)
		historyPanel.Visible = historyOpen
	end
	lobby.Size = UDim2.fromOffset(math.min(440, width - 24), 330)
end

------------------------------------------------------------------------------------------------
-- Actualización según el estado del servidor
------------------------------------------------------------------------------------------------

local function glyphs(list: { string }): string
	local sorted = table.clone(list)
	table.sort(sorted, function(a, b)
		return (Theme.PieceValues[string.upper(a)] or 0) > (Theme.PieceValues[string.upper(b)] or 0)
	end)
	local parts = {}
	for _, letter in sorted do
		local white = letter == string.upper(letter)
		local hex = if white then "F2EDE3" else "8E8EA0"
		table.insert(parts, `<font color="#{hex}">{GLYPH[string.upper(letter)]}</font>`)
	end
	return table.concat(parts)
end

local function materialValue(list: { string }): number
	local total = 0
	for _, letter in list do
		total += Theme.PieceValues[string.upper(letter)] or 0
	end
	return total
end

local function updateCards(data: Snapshot)
	local mySeat = GameController:MySeat()
	local bottomSeat = mySeat or "w"
	local topSeat = if bottomSeat == "w" then "b" else "w"
	local mapping: { [string]: string } = { bottom = bottomSeat, top = topSeat }

	for slot, seat in mapping do
		local card = cards[slot]
		local info = data.seats[seat]
		card.name.Text = if info then info.name else "Esperando…"
		card.name.TextColor3 = if info then Colors.Text else Colors.Muted
		card.role.Text = (if seat == mySeat then "Tú · " else "") .. SIDE_NAMES[seat]
		if info then
			loadAvatar(info.id, card.avatar)
		else
			card.avatar.Image = ""
		end

		-- Piezas capturadas por este jugador (las que perdió el rival) y ventaja material.
		local lost: { string } = if seat == "w" then data.captured.b else data.captured.w
		local mine: { string } = if seat == "w" then data.captured.w else data.captured.b
		local diff = materialValue(lost) - materialValue(mine)
		local text = glyphs(lost)
		if diff > 0 then
			text ..= `  <font color="#74C488">+{diff}</font>`
		end
		card.captured.Text = text

		local active = data.status == "playing" and data.turn == seat
		TweenService:Create(
			card.stroke,
			TweenInfo.new(0.2),
			{ Color = if active then Colors.Gold else Colors.Stroke, Thickness = if active then 2 else 1 }
		):Play()
		card.clock.Text = formatClock(remainingFor(data, seat))
	end
end

local function updatePill(data: Snapshot)
	local mySeat = GameController:MySeat()
	local text: string
	local dotColor = if data.turn == "w" then Theme.Colors.White else Theme.Colors.Black
	local textColor = Colors.Text

	if data.status == "waiting" then
		text = if mySeat then "Esperando rival…" else "Elige un bando para jugar"
		dotColor = Colors.Muted
	elseif data.status == "over" then
		local result = data.result
		if result.winner == "draw" then
			text = "Tablas"
		else
			text = `Ganan {SIDE_NAMES[result.winner]}`
			dotColor = if result.winner == "w" then Theme.Colors.White else Theme.Colors.Black
		end
		textColor = Colors.Gold
	else
		local mine = mySeat ~= nil and data.turn == mySeat
		if data.check >= 0 then
			text = if mine then "¡Estás en jaque!" else "¡Jaque!"
			textColor = Color3.fromRGB(255, 120, 110)
		elseif mySeat then
			text = if mine then "Tu turno" else "Turno del rival"
			textColor = if mine then Colors.Gold else Colors.Text
		else
			text = `Turno de {SIDE_NAMES[data.turn]}`
		end
	end
	pillText.Text = text
	pillText.TextColor3 = textColor
	pillDot.BackgroundColor3 = dotColor
end

local function updateHistory(data: Snapshot)
	local history: { string } = data.history
	local rows = math.ceil(#history / 2)
	if rows < historyRows or (#history == 0 and historyRows > 0) then
		for _, child in historyList:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		historyRows = 0
	end
	-- Actualiza la última fila (si cambió) y añade las que falten.
	for index = math.max(historyRows, 1), rows do
		local existing = historyList:FindFirstChild("Row" .. index)
		if existing then
			existing:Destroy()
		end
		addHistoryRow(index, history[index * 2 - 1], history[index * 2])
	end
	historyRows = rows
	for _, child in historyList:GetChildren() do
		if child:IsA("Frame") then
			for _, label in child:GetChildren() do
				if label:IsA("TextLabel") and label.Name ~= "Number" then
					label.TextColor3 = Colors.Text
					label.Font = Kit.Fonts.Body
				end
			end
		end
	end
	local lastRow = historyList:FindFirstChild("Row" .. rows)
	if lastRow then
		local label = lastRow:FindFirstChild(if #history % 2 == 1 then "White" else "Black") :: TextLabel?
		if label then
			label.TextColor3 = Colors.Gold
			label.Font = Kit.Fonts.Bold
		end
	end
	historyTitle.Text = if #history == 0
		then "PARTIDA"
		else `PARTIDA · {rows} {if rows == 1 then "JUGADA" else "JUGADAS"}`
	task.defer(function()
		historyList.CanvasPosition =
			Vector2.new(0, math.max(0, historyList.AbsoluteCanvasSize.Y - historyList.AbsoluteWindowSize.Y))
	end)
end

local function updateLobby(data: Snapshot)
	local mySeat = GameController:MySeat()
	local show = data.status == "waiting"
	lobby.Visible = show
	if not show then
		return
	end
	for _, seat in { "w", "b" } do
		local info = data.seats[seat]
		local button = lobbyButtons[seat]
		lobbySub[seat].Text = if info then info.name else "Libre"
		Kit.setEnabled(button, info == nil and mySeat == nil)
	end
	lobbyStatus.Text = if mySeat then "Esperando a que se una otro jugador…" else "Elige con qué color quieres jugar"
	lobbySolo.Visible = data.canSolo and mySeat == nil and data.seats.w == nil and data.seats.b == nil
	lobbyLeave.Visible = mySeat ~= nil
end

local function updateActions(data: Snapshot)
	local mySeat = GameController:MySeat()
	local playing = data.status == "playing" and mySeat ~= nil
	actionRow.Visible = playing
	if not playing then
		resignArmedUntil = 0
		resignButton.Text = "Abandonar"
	end
	spectator.Visible = mySeat == nil and data.status == "playing"

	local offered = data.drawOffer
	local fromOpponent = playing and offered ~= nil and offered ~= mySeat
	drawBanner.Visible = fromOpponent
	if fromOpponent then
		drawText.Text = `{playerName(data, offered)} ofrece tablas`
	end
	drawButton.Text = if offered ~= nil and offered == mySeat then "Tablas ofrecidas" else "Ofrecer tablas"
	Kit.setEnabled(drawButton, offered == nil)
end

local function showEnd(data: Snapshot)
	local result = data.result
	if not result then
		return
	end
	local mySeat = GameController:MySeat()
	if result.winner == "draw" then
		endTitle.Text = "Tablas"
		endTitle.TextColor3 = Colors.Text
	elseif mySeat == nil then
		endTitle.Text = `Ganan {SIDE_NAMES[result.winner]}`
		endTitle.TextColor3 = Colors.Gold
	elseif result.winner == mySeat then
		endTitle.Text = "¡Victoria!"
		endTitle.TextColor3 = Colors.Gold
	else
		endTitle.Text = "Derrota"
		endTitle.TextColor3 = Color3.fromRGB(226, 120, 112)
	end
	endReason.Text = REASONS[result.reason] or result.reason

	local seated = mySeat ~= nil
	endRematch.Visible = seated
	endLeave.Visible = seated
	endView.Position = if seated then UDim2.new(0.5, 0, 0, 200) else UDim2.new(0.5, 0, 0, 150)
	endCard.Size = UDim2.fromOffset(400, if seated then 250 else 210)

	local votes = data.rematch
	local other = if mySeat == "w" then "b" else "w"
	if seated and not data.solo and not (data.seats.w and data.seats.b) then
		endRematch.Text = "Rival ausente"
		Kit.setEnabled(endRematch, false)
	elseif seated and votes[mySeat] then
		endRematch.Text = "Esperando rival…"
		Kit.setEnabled(endRematch, false)
	elseif seated and votes[other] and not data.solo then
		endRematch.Text = "Revancha (rival listo)"
		Kit.setEnabled(endRematch, true)
	else
		endRematch.Text = "Revancha"
		Kit.setEnabled(endRematch, true)
	end
end

local function updateEnd(data: Snapshot, previousStatus: string)
	if data.status ~= "over" then
		endToken += 1
		endDismissed = false
		endCard.Visible = false
		return
	end
	if previousStatus ~= "over" then
		endDismissed = false
		endToken += 1
		local token = endToken
		-- Pequeña pausa para ver la jugada final (más larga si cae el rey).
		local delay = if data.result.reason == "checkmate" then 2.4 else 1.2
		showEnd(data)
		task.delay(delay, function()
			if token == endToken and not endDismissed then
				endCard.Visible = true
			end
		end)
	else
		showEnd(data)
	end
end

local function render(data: Snapshot, previousStatus: string)
	updateCards(data)
	updatePill(data)
	updateHistory(data)
	updateLobby(data)
	updateActions(data)
	updateEnd(data, previousStatus)
end

-- Relojes: se refrescan a ~10 Hz solo mientras hay partida en juego.
local function tickClocks(dt: number)
	local data = snapshot
	if not data or data.status ~= "playing" then
		return
	end
	clockAccumulator += dt
	local mySeat = GameController:MySeat() or "w"
	local bottom, top = mySeat, if mySeat == "w" then "b" else "w"
	local running: string = data.turn
	local low = remainingFor(data, running) < 20
	if clockAccumulator < (if low then 0.05 else 0.2) then
		return
	end
	clockAccumulator = 0
	local slots: { [string]: string } = { bottom = bottom, top = top }
	for slot, seat in slots do
		local time = remainingFor(data, seat)
		local card = cards[slot]
		card.clock.Text = formatClock(time)
		card.clock.TextColor3 = if time < 20 and seat == running then Color3.fromRGB(255, 120, 110) else Colors.Text
	end
end

------------------------------------------------------------------------------------------------
-- API pública
------------------------------------------------------------------------------------------------

function ChessUIController:IsBlocking(): boolean
	return promotionOpen
end

function ChessUIController:AskPromotion(callback: (letter: string) -> ())
	promotionCallback = callback
	promotionOpen = true
	promotionDim.Visible = true
	EffectsController:Play("Select")
end

function ChessUIController:CancelPromotion()
	promotionCallback = nil
	promotionOpen = false
	if promotionDim then
		promotionDim.Visible = false
	end
end

function ChessUIController:Start()
	local gui = UIController:GetRoot()
	root = Kit.frame(gui, "ChessUI", { Size = UDim2.fromScale(1, 1) })
	container = Kit.frame(root, "Container", { Size = UDim2.fromScale(1, 1) })
	uiScale = Instance.new("UIScale")
	uiScale.Parent = container

	cards.top = buildCard("b")
	cards.bottom = buildCard("w")
	buildPill()
	buildHistory()
	buildControls()
	buildLobby()
	buildEndCard()
	buildBanners()
	buildPromotion()

	layout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)

	-- Los botones de vista reflejan la vista inicial.
	CameraController:SetView(CameraController:GetView())

	local previousStatus = ""
	GameController:OnUpdate(function(data)
		snapshot = data
		render(data, previousStatus)
		previousStatus = data.status
		ChessUIController:CancelPromotion()
	end)
	RunService.Heartbeat:Connect(tickClocks)
end

return ChessUIController

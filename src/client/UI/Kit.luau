--!strict
-- Piezas de interfaz reutilizables con el estilo del juego (paneles de cristal oscuro, detalles dorados).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Config.ChessTheme)

local Kit = {}

Kit.Colors = {
	Panel = Color3.fromRGB(18, 18, 24),
	PanelLight = Color3.fromRGB(34, 34, 43),
	Gold = Theme.Colors.Gold,
	GoldDark = Color3.fromRGB(150, 118, 60),
	Text = Color3.fromRGB(242, 237, 227),
	Muted = Color3.fromRGB(150, 148, 160),
	Danger = Color3.fromRGB(196, 74, 74),
	Good = Color3.fromRGB(116, 196, 136),
	Stroke = Color3.fromRGB(72, 68, 64),
}

Kit.Fonts = {
	Title = Enum.Font.Merriweather,
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Mono = Enum.Font.RobotoMono,
}

local TWEEN_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function apply(instance: Instance, props: { [string]: any }?)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
end

function Kit.corner(parent: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function Kit.stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Kit.padding(parent: Instance, left: number, top: number, right: number?, bottom: number?)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, left)
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingRight = UDim.new(0, right or left)
	padding.PaddingBottom = UDim.new(0, bottom or top)
	padding.Parent = parent
end

-- Panel de cristal oscuro con borde fino.
function Kit.panel(parent: Instance, name: string, props: { [string]: any }?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Kit.Colors.Panel
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Active = true -- absorbe los clics para que no lleguen al tablero de detrás
	apply(frame, props)
	Kit.corner(frame, 14)
	Kit.stroke(frame, Kit.Colors.Stroke, 1, 0.35)
	frame.Parent = parent
	return frame
end

function Kit.frame(parent: Instance, name: string, props: { [string]: any }?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	apply(frame, props)
	frame.Parent = parent
	return frame
end

function Kit.label(parent: Instance, name: string, text: string, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = text
	label.Font = Kit.Fonts.Body
	label.TextSize = 16
	label.TextColor3 = Kit.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.RichText = false
	apply(label, props)
	label.Parent = parent
	return label
end

export type ButtonStyle = "primary" | "ghost" | "danger" | "soft"

local STYLES: { [string]: { bg: Color3, bgAlpha: number, text: Color3, hover: Color3, stroke: Color3? } } = {
	primary = {
		bg = Kit.Colors.Gold,
		bgAlpha = 0,
		text = Color3.fromRGB(28, 22, 12),
		hover = Color3.fromRGB(232, 200, 128),
		stroke = nil,
	},
	ghost = {
		bg = Kit.Colors.PanelLight,
		bgAlpha = 0.35,
		text = Kit.Colors.Text,
		hover = Color3.fromRGB(58, 58, 70),
		stroke = Kit.Colors.Stroke,
	},
	soft = {
		bg = Kit.Colors.PanelLight,
		bgAlpha = 0.2,
		text = Kit.Colors.Text,
		hover = Color3.fromRGB(62, 62, 76),
		stroke = nil,
	},
	danger = {
		bg = Color3.fromRGB(70, 30, 32),
		bgAlpha = 0.1,
		text = Color3.fromRGB(255, 190, 186),
		hover = Color3.fromRGB(104, 40, 44),
		stroke = Kit.Colors.Danger,
	},
}

export type Button = TextButton

-- Botón con estilo, efecto al pasar el ratón y pulsación (escala). `onClick` se llama al soltar dentro.
function Kit.button(
	parent: Instance,
	name: string,
	text: string,
	style: ButtonStyle,
	props: { [string]: any }?,
	onClick: (() -> ())?
): TextButton
	local def = STYLES[style]
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Font = Kit.Fonts.Bold
	button.TextSize = 16
	button.TextColor3 = def.text
	button.BackgroundColor3 = def.bg
	button.BackgroundTransparency = def.bgAlpha
	apply(button, props)
	Kit.corner(button, 10)
	if def.stroke then
		Kit.stroke(button, def.stroke, 1, 0.3)
	end
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.Parent = parent

	button.MouseEnter:Connect(function()
		if button.Active then
			TweenService:Create(button, TWEEN_FAST, { BackgroundColor3 = def.hover }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TWEEN_FAST, { BackgroundColor3 = def.bg }):Play()
		TweenService:Create(scale, TWEEN_FAST, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		if button.Active then
			TweenService:Create(scale, TWEEN_FAST, { Scale = 0.96 }):Play()
		end
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TWEEN_FAST, { Scale = 1 }):Play()
	end)
	if onClick then
		button.Activated:Connect(function()
			if button.Active then
				onClick()
			end
		end)
	end
	return button
end

-- Activa o desactiva un botón (se ve atenuado y no responde).
function Kit.setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.TextTransparency = if enabled then 0 else 0.55
end

return Kit

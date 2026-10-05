--!strict
-- Muestra las Coins del jugador. Solo lee lo que envía el servidor (CoinsChanged).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(script.Parent.Parent.Net)
local UIController = require(script.Parent.UIController)

local CoinsController = {}

local coins = 0
local label: TextLabel? = nil
local scale: UIScale? = nil

local BUMP_IN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUMP_OUT = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function format(value: number): string
	local text = string.format("%d", math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return (formatted:gsub("^%.", ""))
end

local function render(animate: boolean)
	if not label then
		return
	end
	label.Text = `🪙 {format(coins)}`
	if animate and scale then
		local grow = TweenService:Create(scale, BUMP_IN, { Scale = 1.12 })
		grow.Completed:Once(function()
			TweenService:Create(scale :: UIScale, BUMP_OUT, { Scale = 1 }):Play()
		end)
		grow:Play()
	end
end

local function build(root: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "CoinsDisplay"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.new(0, 16, 0, 56)
	frame.Size = UDim2.fromOffset(180, 44)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
	frame.BackgroundTransparency = 0.2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 60)
	stroke.Thickness = 2
	stroke.Parent = frame

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = frame
	scale = uiScale

	local text = Instance.new("TextLabel")
	text.Name = "Amount"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 220, 90)
	text.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = text

	frame.Parent = root
	label = text
end

function CoinsController:Init()
	Net.On("CoinsChanged", function(value: number)
		local increased = value > coins
		coins = value
		render(increased)
	end)
end

function CoinsController:Start()
	if not GameConfig.ShowCoins then
		return
	end
	build(UIController:GetRoot())
	render(false)
end

-- Coins actuales según el servidor (solo para mostrar; el servidor decide).
function CoinsController:Get(): number
	return coins
end

return CoinsController

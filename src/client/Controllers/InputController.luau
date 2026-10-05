--!strict
-- Selección de piezas con clic / toque. Distingue un toque de un arrastre (que gira la cámara).
-- Solo propone movimientos al servidor: la validación real ocurre allí.

local UserInputService = game:GetService("UserInputService")

local BoardController = require(script.Parent.BoardController)
local ChessUIController = require(script.Parent.ChessUIController)
local EffectsController = require(script.Parent.EffectsController)
local GameController = require(script.Parent.GameController)

local InputController = {}

local TAP_MAX_DISTANCE = 12 -- píxeles
local TAP_MAX_TIME = 0.5 -- segundos
local HOVER_INTERVAL = 0.04

local selected: number? = nil
local downPosition: Vector2? = nil
local downTime = 0
local lastHover = 0
local hoverSquare: number? = nil

local function setSelected(sq: number?)
	selected = sq
	BoardController:ShowSelection(sq)
end

local function clickSquare(sq: number?)
	if BoardController:IsBusy() or not GameController:IsMyTurn() or ChessUIController:IsBlocking() then
		return
	end
	if sq == nil then
		setSelected(nil)
		return
	end

	local from = selected
	if from then
		if sq == from then
			setSelected(nil)
			return
		end
		if table.find(GameController:LegalFrom(from), sq) then
			setSelected(nil)
			if GameController:IsPromotion(from, sq) then
				ChessUIController:AskPromotion(function(letter: string)
					GameController:SendMove(from, sq, letter)
				end)
			else
				GameController:SendMove(from, sq, "")
			end
			return
		end
	end

	if GameController:IsMyPiece(sq) then
		setSelected(sq)
		if #GameController:LegalFrom(sq) == 0 then
			EffectsController:Play("Error")
		else
			EffectsController:Play("Select")
		end
	else
		setSelected(nil)
	end
end

local function pickAt(x: number, y: number, viewport: boolean): number?
	local camera = workspace.CurrentCamera
	local ray = if viewport then camera:ViewportPointToRay(x, y) else camera:ScreenPointToRay(x, y)
	return BoardController:Pick(ray.Origin, ray.Direction * 600)
end

function InputController:Start()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			downPosition = Vector2.new(input.Position.X, input.Position.Y)
			downTime = os.clock()
		elseif kind == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Escape then
			setSelected(nil)
			ChessUIController:CancelPromotion()
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local start = downPosition
		downPosition = nil
		if not start then
			return
		end
		local finish = Vector2.new(input.Position.X, input.Position.Y)
		if (finish - start).Magnitude <= TAP_MAX_DISTANCE and os.clock() - downTime <= TAP_MAX_TIME then
			clickSquare(pickAt(finish.X, finish.Y, false))
		end
	end)

	-- Resaltado al pasar el ratón (solo con ratón; limitado a ~25 comprobaciones por segundo).
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement or processed then
			return
		end
		local now = os.clock()
		if now - lastHover < HOVER_INTERVAL then
			return
		end
		lastHover = now
		local sq: number? = nil
		if GameController:IsMyTurn() and not BoardController:IsBusy() then
			local location = UserInputService:GetMouseLocation()
			local candidate = pickAt(location.X, location.Y, true)
			if candidate then
				local from = selected
				if
					GameController:IsMyPiece(candidate)
					or (from and table.find(GameController:LegalFrom(from), candidate))
				then
					sq = candidate
				end
			end
		end
		if sq ~= hoverSquare then
			hoverSquare = sq
			BoardController:SetHover(sq)
		end
	end)

	GameController:OnUpdate(function()
		selected = nil
		if hoverSquare then
			hoverSquare = nil
			BoardController:SetHover(nil)
		end
	end)
end

return InputController

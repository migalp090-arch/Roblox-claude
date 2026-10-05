--!strict
-- Cámara orbital sobre el tablero: arrastrar para girar (limitado), rueda / pellizco para zoom suave,
-- tres vistas (Juego, Cine, Cenital) y encuadre automático según la pantalla. El objetivo está fijo en el
-- centro del tablero y el zoom/pitch están limitados, así que el tablero nunca se sale de la vista.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage.Shared.Config.ChessTheme)
local GameController = require(script.Parent.GameController)

local CameraController = {}

export type View = string -- "play" | "cinematic" | "top"

local FOV = 40
local MIN_PITCH, MAX_PITCH = math.rad(22), math.rad(84)
local MIN_ZOOM, MAX_ZOOM = 0.62, 1.55
local WIDE_MIN_WIDTH = 1000 -- por encima, la interfaz ocupa los laterales

local VIEWS: { [string]: { pitch: number, zoom: number, drift: boolean } } = {
	play = { pitch = math.rad(56), zoom = 1, drift = false },
	cinematic = { pitch = math.rad(31), zoom = 0.92, drift = true },
	top = { pitch = math.rad(82), zoom = 1, drift = false },
}

local target = Vector3.new(0, Theme.BoardTopY + 0.5, 0)

local camera: Camera = workspace.CurrentCamera
local yaw, pitch, zoom = 0, VIEWS.play.pitch, 1 -- valores suavizados (los que se ven)
local goalYaw, goalPitch, goalZoom = 0, VIEWS.play.pitch, 1 -- valores objetivo
local baseYaw = 0
local view: View = "cinematic"
local driftTime = 0
local dragging = false
local touchRotating = false
local viewListeners: { (View) -> () } = {}

-- Distancia a la que el tablero cabe en pantalla para la vista y proporción actuales.
local function fitDistance(): number
	local size = camera.ViewportSize
	local aspect = math.max(size.X / math.max(size.Y, 1), 0.2)
	local halfTan = math.tan(math.rad(FOV) / 2)
	local wide = size.X >= WIDE_MIN_WIDTH
	-- Mitad de la profundidad visible del tablero (+ altura de piezas) según el pitch.
	local halfDepth = 21 * math.sin(goalPitch) + 5 * math.cos(goalPitch) + 1
	local vertical = halfDepth / (halfTan * (if wide then 0.9 else 0.62))
	-- Ancho: en pantallas anchas deja libres los laterales para la interfaz.
	local horizontal = 22 / (halfTan * aspect * (if wide then 0.55 else 0.94))
	return math.max(vertical, horizontal, 40)
end

local function setView(newView: View, instant: boolean?)
	local def = VIEWS[newView]
	view = newView
	goalPitch = def.pitch
	goalZoom = def.zoom
	if newView == "cinematic" then
		goalYaw = baseYaw + math.rad(24)
	else
		goalYaw = baseYaw
	end
	driftTime = 0
	if instant then
		yaw, pitch, zoom = goalYaw, goalPitch, goalZoom
	end
	for _, listener in viewListeners do
		listener(newView)
	end
end

-- Elige el lado desde el que se mira (0 = blancas, π = negras) acercando el ángulo al actual.
local function setSide(side: number)
	local delta = (side - baseYaw + math.pi) % (math.pi * 2) - math.pi
	baseYaw += delta
	goalYaw += delta
end

function CameraController:SetView(newView: View)
	setView(newView)
end

function CameraController:GetView(): View
	return view
end

function CameraController:CycleView()
	local order: { View } = { "play", "cinematic", "top" }
	local index = table.find(order, view) or 1
	setView(order[index % #order + 1])
end

function CameraController:OnViewChanged(listener: (View) -> ()): () -> ()
	table.insert(viewListeners, listener)
	return function()
		local index = table.find(viewListeners, listener)
		if index then
			table.remove(viewListeners, index)
		end
	end
end

-- Vuelve al encuadre de la vista actual (cancela giros y zoom manuales).
function CameraController:Reset()
	setView(view)
end

local function rotate(deltaX: number, deltaY: number)
	goalYaw -= deltaX * 0.0085
	goalPitch = math.clamp(goalPitch + deltaY * 0.0065, MIN_PITCH, MAX_PITCH)
end

local function zoomBy(factor: number)
	goalZoom = math.clamp(goalZoom * factor, MIN_ZOOM, MAX_ZOOM)
end

local function render(dt: number)
	if camera ~= workspace.CurrentCamera then
		camera = workspace.CurrentCamera
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	camera.FieldOfView = FOV

	-- Deriva suave de la vista cinematográfica (oscila alrededor del ángulo base, nunca da vueltas).
	local driftYaw = 0
	if VIEWS[view].drift and not dragging and not touchRotating then
		driftTime += dt
		driftYaw = math.sin(driftTime * 0.18) * math.rad(18)
	end

	local alpha = 1 - math.exp(-dt * 7)
	yaw += (goalYaw + driftYaw - yaw) * alpha
	pitch += (goalPitch - pitch) * alpha
	zoom += (goalZoom - zoom) * alpha

	local distance = fitDistance() * zoom
	local horizontal = math.cos(pitch)
	local offset = Vector3.new(math.sin(yaw) * horizontal, math.sin(pitch), math.cos(yaw) * horizontal) * distance
	camera.CFrame = CFrame.lookAt(target + offset, target)
end

function CameraController:Init()
	camera = workspace.CurrentCamera
end

function CameraController:Start()
	camera.CameraType = Enum.CameraType.Scriptable
	setView("cinematic", true)
	RunService:BindToRenderStep("ChessCamera", Enum.RenderPriority.Camera.Value + 1, render)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
		then
			dragging = true
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.One then
				setView("play")
			elseif input.KeyCode == Enum.KeyCode.Two then
				setView("cinematic")
			elseif input.KeyCode == Enum.KeyCode.Three then
				setView("top")
			elseif input.KeyCode == Enum.KeyCode.R then
				CameraController:Reset()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
		then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if dragging then
				rotate(input.Delta.X, input.Delta.Y)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			zoomBy(1 - input.Position.Z * 0.08)
		end
	end)
	-- Táctil: un dedo gira, pellizco = zoom.
	local lastPinch = 1
	UserInputService.TouchPan:Connect(function(positions, translation: Vector2, _velocity, state, processed)
		if processed or #positions ~= 1 then
			return
		end
		touchRotating = state ~= Enum.UserInputState.End
		if state == Enum.UserInputState.Change then
			rotate(translation.X * 0.25, translation.Y * 0.25)
		end
	end)
	UserInputService.TouchPinch:Connect(function(_positions, scale, _velocity, state, processed)
		if processed then
			return
		end
		if state == Enum.UserInputState.Begin then
			touchRotating = true
			lastPinch = 1
		elseif state == Enum.UserInputState.Change then
			-- `scale` es acumulado desde el inicio del gesto: se aplica solo el cambio desde el evento anterior.
			zoomBy(lastPinch / math.max(scale, 0.2))
			lastPinch = math.max(scale, 0.2)
		else
			touchRotating = false
		end
	end)

	-- Al sentarse se pasa a la vista de juego desde el lado del jugador; al terminar, a la cinematográfica.
	local lastSeat: string? = nil
	local lastStatus: string = ""
	GameController:OnUpdate(function(snapshot)
		local seat = GameController:MySeat()
		local status: string = snapshot.status
		local started = status == "playing" and lastStatus ~= "playing"
		local backToLobby = status == "waiting" and lastStatus == "over"
		if seat ~= lastSeat or started then
			if seat then
				setSide(if seat == "b" then math.pi else 0)
				if status == "playing" then
					setView("play")
				end
			elseif status ~= "playing" then
				setSide(0)
				setView("cinematic")
			end
		elseif backToLobby then
			setSide(0)
			setView("cinematic")
		end
		lastSeat, lastStatus = seat, status
	end)
end

return CameraController

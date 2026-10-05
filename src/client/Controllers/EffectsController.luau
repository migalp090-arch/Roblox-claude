--!strict
-- Sonido y partículas del juego. Todo se crea una vez y se reutiliza (nada se instancia por jugada).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local Theme = require(ReplicatedStorage.Shared.Config.ChessTheme)

local EffectsController = {}

local sounds: { [string]: Sound } = {}
local emitterPart: Part? = nil
local emitters: { [string]: ParticleEmitter } = {}

local function makeEmitter(name: string, config: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.LightEmission = 0.7
	emitter.LightInfluence = 0
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	for key, value in config do
		(emitter :: any)[key] = value
	end
	return emitter
end

function EffectsController:Init()
	local group = Instance.new("SoundGroup")
	group.Name = "ChessSFX"
	group.Volume = 1
	group.Parent = SoundService

	for name, def in AudioConfig do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = def.Id
		sound.Volume = def.Volume
		sound.PlaybackSpeed = def.Speed
		sound.SoundGroup = group
		sound.Parent = group
		sounds[name] = sound
	end
end

function EffectsController:Start()
	local folder = workspace:WaitForChild("Runtime")
	local part = Instance.new("Part")
	part.Name = "EffectsEmitter"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = Vector3.new(0, Theme.BoardTopY, 0)
	part.Parent = folder
	emitterPart = part

	emitters.Capture = makeEmitter("Capture", {
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -22, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Theme.Colors.Gold, Color3.fromRGB(255, 240, 200)),
	})
	emitters.Promote = makeEmitter("Promote", {
		Lifetime = NumberRange.new(0.7, 1.2),
		Speed = NumberRange.new(3, 8),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 2, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 255, 255)),
	})
	emitters.Victory = makeEmitter("Victory", {
		Lifetime = NumberRange.new(1.4, 2.4),
		Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -14, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Theme.Colors.Gold, Color3.fromRGB(255, 255, 255)),
	})
	for _, emitter in emitters do
		emitter.Parent = part
	end
end

-- Reproduce un sonido con una pequeña variación de tono (para que no suene repetitivo).
function EffectsController:Play(name: string, variation: number?)
	local sound = sounds[name]
	local def = AudioConfig[name]
	if not sound or not def then
		return
	end
	local jitter = variation or 0.06
	sound.PlaybackSpeed = def.Speed * (1 + (math.random() * 2 - 1) * jitter)
	sound:Play()
end

-- Ráfaga de partículas ("Capture" | "Promote" | "Victory") en una posición del mundo.
function EffectsController:Burst(kind: string, position: Vector3, count: number)
	local part, emitter = emitterPart, emitters[kind]
	if not part or not emitter then
		return
	end
	part.Position = position
	emitter:Emit(count)
end

return EffectsController

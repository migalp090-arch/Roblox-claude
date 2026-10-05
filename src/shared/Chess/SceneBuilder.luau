--!strict
-- Construye la escena estática del ajedrez (la llama el servidor una vez): peana, marco, casillas,
-- bandejas de capturas, suelo, luces localizadas y ambiente. Todo anclado, sin scripts ni bucles.
-- Estructura: <parent>/ChessBoard/{Squares, Frame, Decor, Lights}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.ChessTheme)

local SceneBuilder = {}

local Colors = Theme.Colors

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.CanTouch = false
	p.CastShadow = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material
	p.Parent = parent
	return p
end

local function cylinder(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local p = part(parent, name, Vector3.new(height, diameter, diameter), position, color, material)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Etiquetas de coordenadas (a-h, 1-8) sobre las barras del marco.
local function coordinateBar(bar: Part, labels: { string }, horizontal: boolean)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = bar
	for i, text in labels do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Text = text
		label.Font = Enum.Font.Merriweather
		label.TextColor3 = Colors.Gold
		label.TextScaled = true
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		if horizontal then
			label.Size = UDim2.fromScale(0.07, 0.5)
			label.Position = UDim2.fromScale((i - 0.5) / 8 * (32 / bar.Size.X) + (1 - 32 / bar.Size.X) / 2, 0.5)
		else
			label.Size = UDim2.fromScale(0.6, 0.07)
			label.Position = UDim2.fromScale(0.5, (i - 0.5) / 8 * (32 / bar.Size.Z) + (1 - 32 / bar.Size.Z) / 2)
		end
		label.Parent = gui
	end
end

local function buildBoard(root: Folder)
	local squares = folder(root, "Squares")
	local frame = folder(root, "Frame")
	local decor = folder(root, "Decor")
	local top = Theme.BoardTopY

	-- Peana (base oscura + cuerpo de madera) sobre el suelo (Y = 0).
	part(decor, "PlinthBase", Vector3.new(57, 1.2, 57), Vector3.new(0, 0.6, 0), Colors.PlinthBase, Enum.Material.Metal).Reflectance =
		0.1
	part(
		decor,
		"PlinthInlay",
		Vector3.new(50.6, 0.18, 50.6),
		Vector3.new(0, 1.29, 0),
		Colors.Gold,
		Theme.Materials.Gold
	)
	part(decor, "Plinth", Vector3.new(50, 3.2, 50), Vector3.new(0, 2.9, 0), Colors.Plinth, Theme.Materials.Plinth)
	part(decor, "PlinthTop", Vector3.new(50.4, 0.3, 50.4), Vector3.new(0, 4.35, 0), Colors.Frame, Theme.Materials.Frame)

	-- Casillas. Cada una guarda su índice (0..63) para el picking del cliente.
	for sq = 0, 63 do
		local file, rank = sq % 8, sq // 8
		local light = (file + rank) % 2 == 1
		local center = Theme.squareCenter(sq)
		local square = part(
			squares,
			tostring(sq),
			Vector3.new(Theme.SquareSize, 0.5, Theme.SquareSize),
			center - Vector3.new(0, 0.25, 0),
			if light then Colors.LightSquare else Colors.DarkSquare,
			if light then Theme.Materials.LightSquare else Theme.Materials.DarkSquare
		)
		square:SetAttribute("Square", sq)
		square.Reflectance = if light then 0.05 else 0.03
	end

	-- Marco: cuatro barras con el tope ligeramente elevado y filete dorado interior.
	local frameTop = top + 0.35
	local height = frameTop - 4.5
	local mid = (frameTop + 4.5) / 2
	local half = 19.2
	local function bar(name: string, size: Vector3, position: Vector3): Part
		return part(frame, name, size, position, Colors.Frame, Theme.Materials.Frame)
	end
	local north = bar("North", Vector3.new(half * 2, height, 3.2), Vector3.new(0, mid, -17.6))
	local south = bar("South", Vector3.new(half * 2, height, 3.2), Vector3.new(0, mid, 17.6))
	local west = bar("West", Vector3.new(3.2, height, 32), Vector3.new(-17.6, mid, 0))
	local east = bar("East", Vector3.new(3.2, height, 32), Vector3.new(17.6, mid, 0))
	north.CFrame = north.CFrame * CFrame.Angles(0, math.pi, 0) -- etiquetas legibles desde el lado negro
	-- En la cara superior el "arriba" del texto apunta a -Z: los números van de 8 (arriba) a 1.
	local files = { "a", "b", "c", "d", "e", "f", "g", "h" }
	local filesFlipped = { "h", "g", "f", "e", "d", "c", "b", "a" } -- la barra norte está girada 180º
	local ranks = { "8", "7", "6", "5", "4", "3", "2", "1" }
	coordinateBar(south, files, true)
	coordinateBar(north, filesFlipped, true)
	coordinateBar(west, ranks, false)
	coordinateBar(east, ranks, false)

	local inlayY = frameTop + 0.02
	local function inlay(name: string, size: Vector3, position: Vector3)
		local p = part(frame, name, size, position, Colors.Gold, Theme.Materials.Gold)
		p.Reflectance = 0.15
		p.CanCollide = false
	end
	inlay("InlayN", Vector3.new(32.7, 0.06, 0.3), Vector3.new(0, inlayY, -16.15))
	inlay("InlayS", Vector3.new(32.7, 0.06, 0.3), Vector3.new(0, inlayY, 16.15))
	inlay("InlayW", Vector3.new(0.3, 0.06, 32.1), Vector3.new(-16.15, inlayY, 0))
	inlay("InlayE", Vector3.new(0.3, 0.06, 32.1), Vector3.new(16.15, inlayY, 0))
	-- Contorno exterior dorado fino
	inlay("OuterN", Vector3.new(38.4, 0.06, 0.14), Vector3.new(0, inlayY, -19.0))
	inlay("OuterS", Vector3.new(38.4, 0.06, 0.14), Vector3.new(0, inlayY, 19.0))
	inlay("OuterW", Vector3.new(0.14, 0.06, 38.4), Vector3.new(-19.0, inlayY, 0))
	inlay("OuterE", Vector3.new(0.14, 0.06, 38.4), Vector3.new(19.0, inlayY, 0))

	-- Remaches dorados en las esquinas del marco y pies de la peana.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			cylinder(
				frame,
				"Stud",
				0.16,
				0.9,
				Vector3.new(sx * 17.9, frameTop + 0.08, sz * 17.9),
				Colors.Gold,
				Theme.Materials.Gold
			)
			cylinder(
				decor,
				"Foot",
				0.5,
				2.6,
				Vector3.new(sx * 27, 0.25, sz * 27),
				Colors.PlinthBase,
				Enum.Material.Metal
			)
		end
	end

	-- Bandejas de capturas (fieltro oscuro con borde de madera).
	for _, side in { -1, 1 } do
		local x = side * Theme.TrayX
		part(decor, "TrayRim", Vector3.new(4.6, 0.2, 31.2), Vector3.new(x, 4.6, 0), Colors.Frame, Theme.Materials.Frame).CanCollide =
			false
		part(
			decor,
			"TrayFelt",
			Vector3.new(4.0, 0.22, 30.6),
			Vector3.new(x, 4.62, 0),
			Colors.Felt,
			Enum.Material.Fabric
		).CanCollide =
			false
	end

	root:SetAttribute("BoardTopY", top)
end

local function buildEnvironment(root: Folder)
	local decor = root:FindFirstChild("Decor") :: Folder

	-- Suelo oscuro y aro dorado fino (sin saturar).
	local floor =
		part(decor, "Floor", Vector3.new(600, 1, 600), Vector3.new(0, -0.5, 0), Colors.Floor, Enum.Material.Slate)
	floor.Reflectance = 0.04
	local ringOuter =
		cylinder(decor, "RingOuter", 0.08, 130, Vector3.new(0, 0.04, 0), Colors.Gold, Theme.Materials.Gold)
	ringOuter.CanCollide = false
	local ringInner = cylinder(decor, "RingInner", 0.1, 129, Vector3.new(0, 0.05, 0), Colors.Floor, Enum.Material.Slate)
	ringInner.CanCollide = false

	-- Motas de polvo en el aire, muy sutiles, sobre el tablero.
	local dust = Instance.new("Part")
	dust.Name = "DustVolume"
	dust.Anchored = true
	dust.CanCollide = false
	dust.CanQuery = false
	dust.CanTouch = false
	dust.CastShadow = false
	dust.Transparency = 1
	dust.Size = Vector3.new(60, 30, 60)
	dust.Position = Vector3.new(0, 22, 0)
	dust.Parent = decor
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 5
	emitter.Lifetime = NumberRange.new(9, 14)
	emitter.Speed = NumberRange.new(0.1, 0.35)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.1)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.82),
		NumberSequenceKeypoint.new(0.8, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 232, 190))
	emitter.LightEmission = 0.6
	emitter.LightInfluence = 0
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Parent = dust
end

-- Luces localizadas: foco principal cálido con sombras suaves + dos contraluces fríos/cálidos sin sombra.
local function buildLights(root: Folder)
	local lights = folder(root, "Lights")

	local function spot(
		name: string,
		position: Vector3,
		color: Color3,
		brightness: number,
		angle: number,
		range: number,
		shadows: boolean
	)
		local anchor = Instance.new("Part")
		anchor.Name = name
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		anchor.CFrame = CFrame.lookAt(position, Vector3.new(0, Theme.BoardTopY, 0))
		anchor.Parent = lights
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Color = color
		light.Brightness = brightness
		light.Angle = angle
		light.Range = range
		light.Shadows = shadows
		light.Parent = anchor
	end

	spot("Key", Vector3.new(6, 62, 14), Color3.fromRGB(255, 236, 208), 5, 52, 110, true)
	spot("RimCool", Vector3.new(-42, 26, -34), Color3.fromRGB(150, 185, 255), 2.2, 55, 100, false)
	spot("RimWarm", Vector3.new(42, 22, -30), Color3.fromRGB(255, 190, 120), 1.8, 55, 100, false)
	spot("Fill", Vector3.new(0, 30, 52), Color3.fromRGB(255, 225, 200), 1.2, 60, 100, false)
end

local function configureLighting()
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(34, 34, 44)
	Lighting.OutdoorAmbient = Color3.fromRGB(34, 34, 44)
	Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0.3
	Lighting.ShadowSoftness = 0.25
	Lighting.FogColor = Color3.fromRGB(10, 10, 14)
	Lighting.FogStart = 220
	Lighting.FogEnd = 600

	for _, name in { "ChessAtmosphere", "ChessSky", "ChessBloom", "ChessGrade" } do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.Name = "ChessSky"
	sky.StarCount = 0
	sky.CelestialBodiesShown = false
	sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = "", "", ""
	sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = "", "", ""
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "ChessAtmosphere"
	atmosphere.Density = 0.22
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(26, 28, 38)
	atmosphere.Decay = Color3.fromRGB(10, 10, 16)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "ChessBloom"
	bloom.Intensity = 0.28
	bloom.Size = 22
	bloom.Threshold = 1.05
	bloom.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "ChessGrade"
	grade.Contrast = 0.08
	grade.Saturation = 0.06
	grade.Brightness = 0
	grade.TintColor = Color3.fromRGB(255, 249, 240)
	grade.Parent = Lighting
end

-- Crea la escena dentro de `parent` (reemplaza una anterior si existe). Devuelve la carpeta raíz.
function SceneBuilder.build(parent: Instance): Folder
	local old = parent:FindFirstChild("ChessBoard")
	if old then
		old:Destroy()
	end
	local root = folder(parent, "ChessBoard")
	buildBoard(root)
	buildEnvironment(root)
	buildLights(root)
	configureLighting()
	return root
end

return SceneBuilder

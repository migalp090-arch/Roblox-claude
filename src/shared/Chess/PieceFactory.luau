--!strict
-- Genera los modelos 3D de las piezas por código: perfiles de revolución (cilindros apilados con curvas
-- suavizadas), esferas y bloques con detalles (collarines dorados, almenas, corona, cruz, crin del caballo...).
-- Todas las piezas se construyen en el origen, de pie sobre Y = 0, mirando hacia -Z (hacia las negras).
-- El pivote del modelo (WorldPivot) está en el centro de la base, a nivel del suelo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.ChessTheme)

local PieceFactory = {}

type Ctx = {
	model: Model,
	body: Color3,
	bodyMaterial: Enum.Material,
	bodyReflectance: number,
	accent: Color3,
}

local TAU = math.pi * 2

local function newPart(ctx: Ctx, name: string, size: Vector3, cframe: CFrame, accent: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = true
	part.Size = size
	part.CFrame = cframe
	if accent then
		part.Color = ctx.accent
		part.Material = Theme.Materials.Gold
		part.Reflectance = 0.2
	else
		part.Color = ctx.body
		part.Material = ctx.bodyMaterial
		part.Reflectance = ctx.bodyReflectance
	end
	part.Parent = ctx.model
	return part
end

-- Disco vertical entre y0 e y1, centrado en (x, z).
local function disc(ctx: Ctx, y0: number, y1: number, radius: number, accent: boolean, x: number?, z: number?)
	local part = newPart(
		ctx,
		"Disc",
		Vector3.new(y1 - y0, radius * 2, radius * 2),
		CFrame.new(x or 0, (y0 + y1) / 2, z or 0) * CFrame.Angles(0, 0, math.pi / 2),
		accent
	)
	part.Shape = Enum.PartType.Cylinder
end

-- Esfera/elipsoide con diámetros (dx, dy, dz) centrada en `center`.
local function ellipsoid(ctx: Ctx, center: Vector3, size: Vector3, accent: boolean)
	local part = newPart(ctx, "Sphere", size, CFrame.new(center), accent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

local function block(ctx: Ctx, size: Vector3, cframe: CFrame, accent: boolean)
	newPart(ctx, "Block", size, cframe, accent)
end

local function wedge(ctx: Ctx, size: Vector3, cframe: CFrame, accent: boolean)
	local part = Instance.new("WedgePart")
	part.Name = "Wedge"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = if accent then ctx.accent else ctx.body
	part.Material = if accent then Theme.Materials.Gold else ctx.bodyMaterial
	part.Reflectance = if accent then 0.2 else ctx.bodyReflectance
	part.Parent = ctx.model
end

-- Puntos (y, r) intermedios entre dos radios con una curva r = r0 + (r1 - r0) * t^exp.
local function curve(points: { { number } }, y0: number, r0: number, y1: number, r1: number, steps: number, exp: number)
	for i = 0, steps do
		local t = i / steps
		table.insert(points, { y0 + (y1 - y0) * t, r0 + (r1 - r0) * t ^ exp })
	end
end

-- Revolución: apila cilindros siguiendo el perfil; añade subdivisiones donde el radio cambia deprisa.
local function lathe(ctx: Ctx, points: { { number } })
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local height = b[1] - a[1]
		if height > 0.001 then
			local count = math.max(1, math.ceil(math.max(math.abs(b[2] - a[2]) / 0.09, height / 0.5)))
			for k = 0, count - 1 do
				local y0 = a[1] + height * k / count
				local y1 = a[1] + height * (k + 1) / count + 0.01 -- solape para no dejar rendijas
				local mid = (k + 0.5) / count
				disc(ctx, y0, y1, a[2] + (b[2] - a[2]) * mid, false)
			end
		end
	end
end

-- Base común: pie ancho, escalón, aro dorado y transición hacia el cuerpo. Devuelve la altura final.
local function base(ctx: Ctx, radius: number, height: number, stemRadius: number): number
	local points: { { number } } = { { 0, radius }, { 0.18, radius }, { 0.18, radius * 0.9 }, { 0.34, radius * 0.88 } }
	curve(points, 0.34, radius * 0.88, height, stemRadius, 5, 0.6)
	lathe(ctx, points)
	disc(ctx, 0.34, 0.46, radius * 0.93, true)
	return height
end

-- Collarín con aro dorado.
local function collar(ctx: Ctx, y: number, stemRadius: number, radius: number)
	lathe(
		ctx,
		{
			{ y, stemRadius },
			{ y + 0.08, radius * 0.92 },
			{ y + 0.2, radius },
			{ y + 0.32, radius },
			{ y + 0.42, stemRadius * 1.3 },
		}
	)
	disc(ctx, y + 0.12, y + 0.26, radius + 0.03, true)
end

local builders: { [string]: (Ctx) -> () } = {}

function builders.P(ctx)
	base(ctx, 1.2, 0.9, 0.6)
	local points: { { number } } = {}
	curve(points, 0.9, 0.6, 1.5, 0.36, 5, 0.5)
	lathe(ctx, points)
	collar(ctx, 1.5, 0.36, 0.68)
	lathe(ctx, { { 1.92, 0.4 }, { 2.05, 0.4 } })
	ellipsoid(ctx, Vector3.new(0, 2.42, 0), Vector3.new(1.3, 1.3, 1.3), false)
end

function builders.R(ctx)
	base(ctx, 1.38, 0.95, 0.82)
	local points: { { number } } = {}
	curve(points, 0.95, 0.82, 2.2, 0.64, 6, 0.8)
	lathe(ctx, points)
	disc(ctx, 2.05, 2.17, 0.7, true)
	-- copa con almenas
	lathe(ctx, { { 2.2, 0.66 }, { 2.4, 1.0 }, { 2.62, 1.06 }, { 3.05, 1.06 } })
	disc(ctx, 2.42, 2.54, 1.08, true)
	disc(ctx, 3.0, 3.1, 0.82, false)
	for i = 0, 5 do
		local angle = i / 6 * TAU
		local cf = CFrame.new(math.sin(angle) * 0.82, 3.3, math.cos(angle) * 0.82) * CFrame.Angles(0, angle, 0)
		block(ctx, Vector3.new(0.62, 0.5, 0.34), cf, false)
	end
end

function builders.B(ctx)
	base(ctx, 1.38, 0.95, 0.8)
	local points: { { number } } = {}
	curve(points, 0.95, 0.8, 2.6, 0.36, 7, 0.45)
	lathe(ctx, points)
	collar(ctx, 2.6, 0.38, 0.72)
	ellipsoid(ctx, Vector3.new(0, 3.65, 0), Vector3.new(1.42, 2.0, 1.42), false)
	ellipsoid(ctx, Vector3.new(0, 4.78, 0), Vector3.new(0.5, 0.5, 0.5), true)
	-- hendidura diagonal de la mitra
	block(ctx, Vector3.new(0.95, 0.14, 0.3), CFrame.new(0, 3.85, -0.55) * CFrame.Angles(0, 0, math.rad(38)), true)
end

function builders.Q(ctx)
	base(ctx, 1.46, 1.0, 0.86)
	local points: { { number } } = {}
	curve(points, 1.0, 0.86, 3.2, 0.42, 8, 0.45)
	lathe(ctx, points)
	collar(ctx, 3.2, 0.42, 0.82)
	-- corona
	local crown: { { number } } = {}
	curve(crown, 3.62, 0.5, 4.45, 1.06, 6, 1.5)
	lathe(ctx, crown)
	disc(ctx, 4.22, 4.34, 1.1, true)
	lathe(ctx, { { 4.45, 1.08 }, { 4.62, 1.08 } })
	disc(ctx, 4.58, 4.66, 0.8, false)
	for i = 0, 7 do
		local angle = i / 8 * TAU
		ellipsoid(
			ctx,
			Vector3.new(math.sin(angle) * 0.9, 4.72, math.cos(angle) * 0.9),
			Vector3.new(0.32, 0.32, 0.32),
			true
		)
	end
	lathe(ctx, { { 4.62, 0.34 }, { 4.9, 0.22 } })
	ellipsoid(ctx, Vector3.new(0, 5.12, 0), Vector3.new(0.62, 0.62, 0.62), true)
end

function builders.K(ctx)
	base(ctx, 1.5, 1.05, 0.9)
	local points: { { number } } = {}
	curve(points, 1.05, 0.9, 3.5, 0.46, 8, 0.45)
	lathe(ctx, points)
	collar(ctx, 3.5, 0.46, 0.86)
	local body: { { number } } = {}
	curve(body, 3.92, 0.6, 4.75, 1.08, 6, 1.4)
	lathe(ctx, body)
	disc(ctx, 4.5, 4.62, 1.12, true)
	lathe(ctx, { { 4.75, 1.1 }, { 4.95, 1.1 }, { 4.95, 0.8 }, { 5.12, 0.55 }, { 5.3, 0.4 } })
	-- cruz
	block(ctx, Vector3.new(0.34, 1.25, 0.34), CFrame.new(0, 5.95, 0), true)
	block(ctx, Vector3.new(0.92, 0.3, 0.34), CFrame.new(0, 6.0, 0), true)
	ellipsoid(ctx, Vector3.new(0, 5.4, 0), Vector3.new(0.6, 0.5, 0.6), true)
end

function builders.N(ctx)
	base(ctx, 1.38, 0.95, 0.85)
	lathe(ctx, { { 0.95, 0.85 }, { 1.2, 0.8 }, { 1.35, 0.9 }, { 1.5, 0.9 } })
	disc(ctx, 1.22, 1.34, 0.93, true)

	local function tilt(deg: number): CFrame
		return CFrame.Angles(math.rad(deg), 0, 0)
	end
	-- Todo lo que está por encima de la base se baja un poco para que el caballo no supere al alfil.
	local dy = -0.3

	-- pecho (más ancho y adelantado) y cuello arqueado (inclinados hacia delante, -Z)
	block(ctx, Vector3.new(1.2, 1.05, 1.4), CFrame.new(0, 1.9 + dy, -0.1), false)
	block(ctx, Vector3.new(0.95, 0.9, 0.9), CFrame.new(0, 2.35 + dy, -0.65) * tilt(-18), false)
	block(ctx, Vector3.new(0.95, 1.9, 1.1), CFrame.new(0, 2.75 + dy, 0.08) * tilt(-14), false)
	-- cabeza, mejilla y hocico (morro hacia abajo)
	block(ctx, Vector3.new(0.9, 1.05, 1.7), CFrame.new(0, 3.6 + dy, -0.5) * tilt(-30), false)
	block(ctx, Vector3.new(0.94, 0.7, 0.8), CFrame.new(0, 3.3 + dy, -0.15) * tilt(-30), false)
	block(ctx, Vector3.new(0.72, 0.68, 0.84), CFrame.new(0, 3.08 + dy, -1.5) * tilt(-30), false)
	block(ctx, Vector3.new(0.76, 0.16, 0.3), CFrame.new(0, 2.82 + dy, -1.82) * tilt(-30), true) -- bocado
	-- orejas
	for _, side in { -1, 1 } do
		wedge(
			ctx,
			Vector3.new(0.18, 0.55, 0.32),
			CFrame.new(side * 0.26, 4.25 + dy, 0.12) * tilt(8) * CFrame.Angles(0, math.pi, 0),
			false
		)
	end
	-- crin dorada a lo largo de la nuca
	for i = 0, 4 do
		local t = i / 4
		block(
			ctx,
			Vector3.new(0.2, 0.5, 0.34),
			CFrame.new(0, 2.1 + dy + t * 1.9, 0.62 - t * 0.28) * tilt(-14 - t * 12),
			true
		)
	end
	-- ojos
	for _, side in { -1, 1 } do
		ellipsoid(ctx, Vector3.new(side * 0.47, 3.8 + dy, -0.62), Vector3.new(0.17, 0.17, 0.17), true)
	end
end

local function newContext(isWhite: boolean): Ctx
	local model = Instance.new("Model")
	return {
		model = model,
		body = if isWhite then Theme.Colors.White else Theme.Colors.Black,
		bodyMaterial = if isWhite then Theme.Materials.WhitePiece else Theme.Materials.BlackPiece,
		bodyReflectance = if isWhite then 0.04 else 0.1,
		accent = Theme.Colors.Gold,
	}
end

-- Crea el modelo de una pieza. `letter`: "PNBRQK" (blancas) o "pnbrqk" (negras).
function PieceFactory.build(letter: string): Model
	local isWhite = letter == string.upper(letter)
	local kind = string.upper(letter)
	local builder = builders[kind]
	assert(builder, `[PieceFactory] Pieza desconocida: {letter}`)

	local ctx = newContext(isWhite)
	builder(ctx)

	local model = ctx.model
	model.Name = (if isWhite then "White" else "Black") .. Theme.PieceNames[kind]
	model.WorldPivot = CFrame.new()
	model:SetAttribute("Piece", letter)
	-- Los modelos se construyen mirando a -Z; las negras giran 180º al colocarse.
	return model
end

-- Altura aproximada de cada tipo de pieza (para animaciones y cámara).
PieceFactory.Heights = { P = 3.1, N = 4.3, B = 5.0, R = 3.6, Q = 5.5, K = 6.5 } :: { [string]: number }

return PieceFactory

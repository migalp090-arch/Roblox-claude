--!strict
-- Animador ligero: una sola conexión a Heartbeat que existe solo mientras hay animaciones activas.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Animator = {}

type Anim = {
	start: number,
	duration: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection,
	update: (alpha: number) -> (),
	done: (() -> ())?,
	cancelled: boolean,
}

export type Handle = { Cancel: (self: Handle) -> () }

local active: { Anim } = {}
local connection: RBXScriptConnection? = nil

local function step()
	local now = os.clock()
	local i = 1
	while i <= #active do
		local anim = active[i]
		if anim.cancelled then
			table.remove(active, i)
		else
			local raw = math.clamp((now - anim.start) / anim.duration, 0, 1)
			local alpha = if raw >= 1 then 1 else TweenService:GetValue(raw, anim.style, anim.direction)
			anim.update(alpha)
			if raw >= 1 then
				table.remove(active, i)
				if anim.done then
					task.spawn(anim.done)
				end
			else
				i += 1
			end
		end
	end
	if #active == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

-- Ejecuta update(alpha 0..1) durante `duration` segundos con la curva indicada.
function Animator.run(
	duration: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection,
	update: (alpha: number) -> (),
	done: (() -> ())?
): Handle
	local anim: Anim = {
		start = os.clock(),
		duration = math.max(duration, 0.001),
		style = style,
		direction = direction,
		update = update,
		done = done,
		cancelled = false,
	}
	table.insert(active, anim)
	update(0)
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
	return {
		Cancel = function()
			anim.cancelled = true
		end,
	} :: Handle
end

-- Espera bloqueante (en el hilo actual) a que termine una animación.
function Animator.wait(
	duration: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection,
	update: (number) -> ()
)
	local thread = coroutine.running()
	Animator.run(duration, style, direction, update, function()
		task.spawn(thread)
	end)
	coroutine.yield()
end

return Animator

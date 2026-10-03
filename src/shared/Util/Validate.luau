--!strict
-- Validadores para argumentos que llegan del cliente. Nunca confíes en el cliente:
-- cada remoto Cliente -> Servidor declara un validador por argumento en Net/Definitions.

local Validate = {}

export type Validator = (value: any) -> boolean

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

function Validate.number(min: number?, max: number?): Validator
	return function(value)
		if type(value) ~= "number" or not isFinite(value) then
			return false
		end
		if min and value < min then
			return false
		end
		if max and value > max then
			return false
		end
		return true
	end
end

function Validate.integer(min: number?, max: number?): Validator
	local checkNumber = Validate.number(min, max)
	return function(value)
		return checkNumber(value) and value % 1 == 0
	end
end

function Validate.string(maxLength: number): Validator
	return function(value)
		return type(value) == "string" and #value <= maxLength and utf8.len(value) ~= nil
	end
end

function Validate.boolean(): Validator
	return function(value)
		return type(value) == "boolean"
	end
end

function Validate.oneOf(options: { any }): Validator
	local set = {}
	for _, option in options do
		set[option] = true
	end
	return function(value)
		return value ~= nil and set[value] == true
	end
end

function Validate.vector3(maxMagnitude: number?): Validator
	return function(value)
		if typeof(value) ~= "Vector3" then
			return false
		end
		if not (isFinite(value.X) and isFinite(value.Y) and isFinite(value.Z)) then
			return false
		end
		return maxMagnitude == nil or value.Magnitude <= maxMagnitude
	end
end

function Validate.instanceOf(className: string): Validator
	return function(value)
		return typeof(value) == "Instance" and value:IsA(className)
	end
end

function Validate.optional(validator: Validator): Validator
	return function(value)
		return value == nil or validator(value)
	end
end

return Validate

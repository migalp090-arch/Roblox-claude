--!strict
-- Utilidades de tablas usadas por varios sistemas.

local TableUtil = {}

function TableUtil.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value :: any do
		copy[TableUtil.DeepCopy(key)] = TableUtil.DeepCopy(item)
	end
	return copy :: any
end

-- Añade a `target` las claves de `template` que falten (por ejemplo, campos nuevos en datos guardados antiguos).
function TableUtil.Reconcile(target: { [any]: any }, template: { [any]: any })
	for key, templateValue in template do
		local current = target[key]
		if current == nil then
			target[key] = TableUtil.DeepCopy(templateValue)
		elseif type(current) == "table" and type(templateValue) == "table" then
			TableUtil.Reconcile(current, templateValue)
		end
	end
end

return TableUtil

---------------------------------------------------------------------------------------
-- Vortex Meter
--- Maintained by Vim <Codex>
--- Original addon : Rift Meter by Vince (http://www.curse.com/addons/rift/rift-meter)

local VortexMeter = Apollo.GetAddon("VortexMeter")

table.empty = function(t) for k in pairs(t) do t[k] = nil end end
math.round = function(val) return math.floor(val + .5) end

function VortexMeter.formatSeconds(seconds)
	return ("%02d:%02d"):format(seconds / 60, seconds % 60)
end

function VortexMeter.numberShortFormat(num)
	if     math.round(num) > 1000000 then return ("%.1fm"):format(math.round(num) / 1000000)
	elseif math.round(num) > 1000    then return ("%.1fk"):format(math.round(num) / 1000)
	else                             return tostring(math.round(num)) end
end

function VortexMeter.numberFormat(num)
	local str = tostring(math.round(num))
	if VortexMeter.settings.showShortNumber then
		return VortexMeter.numberShortFormat(num)
	else
		local formatted = str:reverse():gsub("(%d%d%d)","%1,"):reverse()
		return str:len() % 3 == 0 and formatted:sub(2) or formatted
	end
end

function VortexMeter.BuildFormat(absolute, perSecond, percent)
	local args = {}
	local format = ""
	if VortexMeter.settings.showAbsolute then
		table.insert(args, absolute)
		format = format .. "%s" .. (VortexMeter.settings.showPercent and " (" or ", ") .. "%s"
	else
		format = format .. "%s"
	end
	
	table.insert(args, VortexMeter.numberFormat(perSecond))
	
	if VortexMeter.settings.showPercent then
		table.insert(args, percent)
		format = format .. (VortexMeter.settings.showAbsolute and ", " or " ") .. (not VortexMeter.settings.showAbsolute and "(" or "") .. "%.1f%%)"
	end
	
	return format:format(unpack(args))
end

function VortexMeter.colorize(text, fromHex, toHex)
	local colored = {}
	local len = text:len() - 1
	
	local from = {
		r = bit.rshift(fromHex, 16),
		g = bit.band(bit.rshift(fromHex, 8), 0xff),
		b = bit.band(fromHex, 0xff)
	}
	
	local to = {
		r = bit.rshift(toHex, 16),
		g = bit.band(bit.rshift(toHex, 8), 0xff),
		b = bit.band(toHex, 0xff)
	}
	
	local step = {
		r = (to.r - from.r) / len,
		g = (to.g - from.g) / len,
		b = (to.b - from.b) / len
	}
	
	for char in text:gmatch(".") do
		table.insert(colored, ("<P TextColor=\"ff%02x%02x%02x\">%s</P>"):format(from.r, from.g, from.b, char))
		from.r = from.r + step.r
		from.g = from.g + step.g
		from.b = from.b + step.b
	end
	
	return table.concat(colored)
end

function VortexMeter.deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[VortexMeter.deepcopy(orig_key)] = VortexMeter.deepcopy(orig_value)
		end
		setmetatable(copy, VortexMeter.deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

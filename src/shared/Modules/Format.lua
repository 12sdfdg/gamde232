local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 142660 -> "142.66K", 190.06 -> "190.06"
function Format.Number(n)
	n = tonumber(n) or 0
	local negative = n < 0
	n = math.abs(n)
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n = n / 1000
		index += 1
	end
	local text
	if index == 1 then
		if n == math.floor(n) then
			text = tostring(math.floor(n))
		else
			text = string.format("%.2f", n)
		end
	else
		text = string.format("%.2f", math.floor(n * 100) / 100) .. SUFFIXES[index]
	end
	text = text:gsub("%.00(%a*)$", "%1")
	return (negative and "-" or "") .. text
end

function Format.Int(n)
	return Format.Number(math.floor(tonumber(n) or 0))
end

-- 231 -> "03:51"
function Format.Clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

-- 3725 -> "1h 2m"
function Format.Duration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %ds", m, s)
	end
	return string.format("%ds", s)
end

function Format.Percent(fraction)
	return string.format("%d%%", math.floor(math.clamp(fraction, 0, 1) * 100))
end

return Format

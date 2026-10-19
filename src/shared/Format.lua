--!nonstrict
-- Форматування чисел і часу для UI.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.Number(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = if n == math.floor(n) then tostring(n) else string.format("%.1f", n)
		return (if negative then "-" else "") .. s
	end
	local index = math.floor(math.log10(n) / 3)
	if index >= #SUFFIXES then
		return (if negative then "-" else "") .. string.format("%.2e", n)
	end
	local scaled = n / 10 ^ (index * 3)
	local s = if scaled >= 100 then string.format("%d", math.floor(scaled)) else string.format("%.1f", math.floor(scaled * 10) / 10)
	s = s:gsub("%.0$", "")
	return (if negative then "-" else "") .. s .. SUFFIXES[index + 1]
end

function Format.Mult(n: number): string
	if n >= 100 then
		return "x" .. Format.Number(math.floor(n))
	end
	local s = string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
	return "x" .. s
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

return Format

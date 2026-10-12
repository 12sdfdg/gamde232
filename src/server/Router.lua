-- Validated dispatch for client requests. Every handler runs on the server and returns a result table.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Net = require(ReplicatedStorage.Modules.Net)

local Router = {}

local requestHandlers = {}
local actionHandlers = {}
local buckets = {} -- [player] = { [name] = {tokens, last} }

local function allow(player, name, rate)
	local now = os.clock()
	buckets[player] = buckets[player] or {}
	local bucket = buckets[player][name]
	if not bucket then
		bucket = { tokens = rate, last = now }
		buckets[player][name] = bucket
	end
	bucket.tokens = math.min(rate, bucket.tokens + (now - bucket.last) * rate)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

-- Request: RemoteFunction, returns { ok = bool, msg = string?, ... }
function Router.OnRequest(name, handler, rate)
	requestHandlers[name] = { fn = handler, rate = rate or 6 }
end

-- Action: RemoteEvent, no response.
function Router.OnAction(name, handler, rate)
	actionHandlers[name] = { fn = handler, rate = rate or 10 }
end

function Router.Start()
	local request = Net.Get("Request")
	local action = Net.Get("Action")

	request.OnServerInvoke = function(player, name, ...)
		if typeof(name) ~= "string" then
			return { ok = false, msg = "Bad request" }
		end
		local entry = requestHandlers[name]
		if not entry then
			return { ok = false, msg = "Unknown request" }
		end
		if not allow(player, "R:" .. name, entry.rate) then
			return { ok = false, msg = "Slow down!" }
		end
		local success, result = pcall(entry.fn, player, ...)
		if not success then
			warn("[Router] " .. name .. " failed: " .. tostring(result))
			return { ok = false, msg = "Something went wrong" }
		end
		return result or { ok = true }
	end

	action.OnServerEvent:Connect(function(player, name, ...)
		if typeof(name) ~= "string" then
			return
		end
		local entry = actionHandlers[name]
		if not entry or not allow(player, "A:" .. name, entry.rate) then
			return
		end
		local success, err = pcall(entry.fn, player, ...)
		if not success then
			warn("[Router] action " .. name .. " failed: " .. tostring(err))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

function Router.Notify(player, text, kind)
	Net.Get("Notify"):FireClient(player, text, kind or "info")
end

function Router.Fx(player, payload)
	Net.Get("Fx"):FireClient(player, payload)
end

function Router.FxAll(payload)
	Net.Get("Fx"):FireAllClients(payload)
end

return Router

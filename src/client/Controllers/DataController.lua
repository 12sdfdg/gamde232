-- Holds the latest server data snapshot and exposes request helpers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Modules.Net)

local DataController = {}
DataController.Data = nil
DataController.Payload = nil
DataController.ReceivedAt = 0

local changed = Instance.new("BindableEvent")
DataController.Changed = changed.Event

local requestRemote
local actionRemote

function DataController.Init()
	requestRemote = Net.Get("Request")
	actionRemote = Net.Get("Action")
	Net.Get("Sync").OnClientEvent:Connect(function(payload)
		DataController.Payload = payload
		DataController.Data = payload.Data
		DataController.ReceivedAt = os.clock()
		changed:Fire(payload.Data, payload)
	end)
end

function DataController.WaitForData()
	while not DataController.Data do
		task.wait(0.1)
	end
	return DataController.Data
end

-- RemoteFunction call; always returns a table.
function DataController.Request(name, ...)
	local ok, result = pcall(requestRemote.InvokeServer, requestRemote, name, ...)
	if not ok or type(result) ~= "table" then
		return { ok = false, msg = "Connection error" }
	end
	return result
end

function DataController.Action(name, ...)
	actionRemote:FireServer(name, ...)
end

function DataController.Derived()
	return DataController.Payload and DataController.Payload.Derived or {}
end

-- Seconds of session play time, extrapolated between syncs.
function DataController.SessionElapsed()
	local payload = DataController.Payload
	if not payload or not payload.Session then
		return 0
	end
	return payload.Session.Elapsed + (os.clock() - DataController.ReceivedAt)
end

function DataController.ServerTime()
	local payload = DataController.Payload
	if not payload then
		return os.time()
	end
	return payload.ServerTime + (os.clock() - DataController.ReceivedAt)
end

return DataController

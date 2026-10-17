--!strict
-- Creates (server) and resolves (client) the remote objects used for networking.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local EVENTS = { "StateChanged", "FireBeam", "Notify" }
local FUNCTIONS = { "Roll", "Place", "Sell" }

function Net.setupServer()
	local folder = Instance.new("Folder")
	folder.Name = "Net"

	local events, funcs = {}, {}
	for _, name in ipairs(EVENTS) do
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = folder
		events[name] = e
	end
	for _, name in ipairs(FUNCTIONS) do
		local f = Instance.new("RemoteFunction")
		f.Name = name
		f.Parent = folder
		funcs[name] = f
	end

	folder.Parent = ReplicatedStorage
	return { events = events, funcs = funcs, folder = folder }
end

function Net.waitClient()
	local folder = ReplicatedStorage:WaitForChild("Net")
	local events, funcs = {}, {}
	for _, name in ipairs(EVENTS) do
		events[name] = folder:WaitForChild(name)
	end
	for _, name in ipairs(FUNCTIONS) do
		funcs[name] = folder:WaitForChild(name)
	end
	return { events = events, funcs = funcs, folder = folder }
end

return Net

-- Remote access. The server creates the remotes, clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local DEFINITIONS = {
	Request = "RemoteFunction", -- client -> server, returns a result table
	Action = "RemoteEvent", -- client -> server, fire-and-forget (clicks, attacks)
	Sync = "RemoteEvent", -- server -> client, player data
	Fx = "RemoteEvent", -- server -> client, visual effects
	Notify = "RemoteEvent", -- server -> client, toast messages
}

local function folder()
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Remotes")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = ReplicatedStorage
		end
		return f
	end
	return ReplicatedStorage:WaitForChild("Remotes")
end

function Net.Get(name)
	local className = DEFINITIONS[name]
	assert(className, "Unknown remote " .. tostring(name))
	local f = folder()
	if RunService:IsServer() then
		local remote = f:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = f
		end
		return remote
	end
	return f:WaitForChild(name)
end

function Net.CreateAll()
	for name in pairs(DEFINITIONS) do
		Net.Get(name)
	end
end

return Net

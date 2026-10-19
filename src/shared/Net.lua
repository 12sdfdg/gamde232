--!nonstrict
-- Усі RemoteEvent/RemoteFunction створюються сервером тут і чекаються клієнтом.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Click", -- C→S: клік
	"State", -- S→C: повний стан гравця (дані + множники)
	"RoundState", -- S→C: { phase, endsAt }
	"RaceStart", -- S→C: { distance, duration, lane }
	"RaceResult", -- S→C: { zone, wins, upsell }
	"HatchResult", -- S→C: { eggId, pets = {...} }
	"Notify", -- S→C: text, kind
	"Action", -- C→S: name, args — меню, покупки, нагороди
}

local Net = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.Get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net

--!nonstrict
-- Щоденні нагороди, подарунки за час у грі та промокоди.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlayerState = require(script.Parent.PlayerState)

local RewardService = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

function RewardService.ClaimDaily(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local day = today()
	if data.daily.lastDay == day then
		PlayerState.Notify(player, "Come back tomorrow for the next reward! 📅", "warn")
		return
	end
	if data.daily.lastDay == day - 1 then
		data.daily.streak += 1
	else
		data.daily.streak = 1
	end
	data.daily.lastDay = day
	local index = (data.daily.streak - 1) % #Config.DailyRewards + 1
	local text = PlayerState.GrantReward(player, data, Config.DailyRewards[index], "Daily")
	PlayerState.Notify(player, string.format("Day %d reward: %s 🎁", data.daily.streak, text), "success")
	PlayerState.MarkDirty(player)
end

function RewardService.ClaimGift(player: Player, index: number)
	local data = DataService.Get(player)
	local session = PlayerState.GetSession(player)
	local gift = Config.PlaytimeGifts[index]
	if not data or not session or not gift or session.giftsClaimed[index] then
		return
	end
	if os.time() - session.joinTime < gift.time then
		return
	end
	session.giftsClaimed[index] = true
	local text = PlayerState.GrantReward(player, data, gift, "PlaytimeGift")
	PlayerState.Notify(player, "Gift: " .. text .. " 🎁", "success")
	PlayerState.MarkDirty(player)
end

function RewardService.RedeemCode(player: Player, code: string)
	local data = DataService.Get(player)
	if not data or type(code) ~= "string" then
		return
	end
	code = string.upper((string.gsub(code, "%s", "")))
	local reward = Config.Codes[code]
	if not reward then
		PlayerState.Notify(player, "Invalid code ❌", "error")
		return
	end
	if data.codes[code] then
		PlayerState.Notify(player, "You already used this code!", "warn")
		return
	end
	data.codes[code] = true
	local text = PlayerState.GrantReward(player, data, reward, "Code")
	PlayerState.Notify(player, "Code redeemed: " .. text .. " ✅", "success")
	PlayerState.MarkDirty(player)
end

return RewardService

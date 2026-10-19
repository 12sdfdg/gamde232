--!nonstrict
-- Останній стан гравця з сервера + сигнал змін.

local Store = {}

Store.state = nil :: any
Store.round = { phase = "Lobby", endsAt = 0 } :: any
Store.pendingClicks = 0

local changed = Instance.new("BindableEvent")
Store.Changed = changed.Event

function Store.Set(state: any)
	Store.state = state
	changed:Fire(state)
end

function Store.ServerNow(): number
	return workspace:GetServerTimeNow()
end

-- Скільки секунд лишилось бусту (0, якщо неактивний).
function Store.BoostRemaining(key: string): number
	local state = Store.state
	if not state or not state.boosts[key] then
		return 0
	end
	return math.max(0, state.boosts[key] - Store.ServerNow())
end

return Store

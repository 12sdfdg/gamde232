--!nonstrict
-- Завантаження/збереження даних гравця з блокуванням сесії,
-- щоб прогрес не дублювався і не губився при переходах між серверами.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local DataService = {}

local SESSION_LOCK_TIMEOUT = 300 -- секунд; лок старішого сервера вважається мертвим
local AUTOSAVE_INTERVAL = 60
local MAX_RECEIPTS = 50

local store: DataStore? = nil
local ok, result = pcall(function()
	return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
end)
if ok then
	store = result
else
	warn("[DataService] DataStore недоступний (увімкни API Services у Game Settings → Security):", result)
end

export type PetData = { uid: string, name: string, equipped: boolean }

local function defaultData()
	return {
		version = 1,
		speed = 0,
		wins = 0,
		totalWins = 0,
		rebirths = 0,
		bestZone = 0,
		races = 0,
		pets = {} :: { PetData },
		eggsHatched = 0,
		boosts = {} :: { [string]: number }, -- boostKey -> os.time() закінчення
		daily = { streak = 0, lastDay = -1 },
		codes = {} :: { [string]: boolean },
		receipts = {} :: { string },
		settings = { autoEquip = true, autoClick = true },
		firstJoin = os.time(),
		playTime = 0,
	}
end

export type Data = typeof(defaultData())

local profiles: { [Player]: Data } = {}
local sessionStart: { [Player]: number } = {}
-- Колбеки замість BindableEvent: Bindable копіює таблиці, а нам потрібне посилання на живі дані.
local loadedCallbacks: { (Player, Data) -> () } = {}

function DataService.OnLoaded(callback: (Player, Data) -> ())
	table.insert(loadedCallbacks, callback)
end

local function reconcile(data: any, template: any)
	for key, value in template do
		if data[key] == nil then
			data[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function loadAsync(player: Player): Data?
	if not store then
		return defaultData()
	end
	local jobId = if RunService:IsStudio() then "studio" else game.JobId
	for attempt = 1, 6 do
		local lockedByOther = false
		local success, value = pcall(function()
			return (store :: DataStore):UpdateAsync(keyFor(player), function(old)
				lockedByOther = false
				old = old or { data = defaultData() }
				local lock = old.lock
				if lock and lock.jobId ~= jobId and os.time() - (lock.time or 0) < SESSION_LOCK_TIMEOUT and attempt < 6 then
					lockedByOther = true
					return nil -- не змінюємо, спробуємо ще раз
				end
				old.lock = { jobId = jobId, time = os.time() }
				return old
			end)
		end)
		if success and not lockedByOther and value then
			local data = value.data or defaultData()
			reconcile(data, defaultData())
			return data
		end
		if not success then
			warn("[DataService] Помилка завантаження", player.Name, value)
			if RunService:IsStudio() then
				-- У Studio без доступу до API граємо без збереження.
				warn("[DataService] Studio: прогрес не зберігатиметься. Увімкни Enable Studio Access to API Services.")
				store = nil
				return defaultData()
			end
		end
		if not player.Parent then
			return nil
		end
		task.wait(if lockedByOther then 5 else 2 * attempt)
	end
	return nil
end

local function saveAsync(player: Player, release: boolean): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	if not store then
		return true -- Studio без доступу до API: зберігати нікуди
	end
	local start = sessionStart[player]
	if start then
		data.playTime += os.time() - start
		sessionStart[player] = os.time()
	end
	local jobId = if RunService:IsStudio() then "studio" else game.JobId
	local success, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			old = old or {}
			if old.lock and old.lock.jobId ~= jobId and os.time() - (old.lock.time or 0) < SESSION_LOCK_TIMEOUT then
				-- Інший сервер уже забрав сесію — не перезаписуємо його свіжі дані.
				return nil
			end
			old.data = data
			old.lock = if release then nil else { jobId = jobId, time = os.time() }
			return old
		end)
	end)
	if not success then
		warn("[DataService] Помилка збереження", player.Name, err)
	end
	return success
end

function DataService.Get(player: Player): Data?
	return profiles[player]
end

function DataService.WaitFor(player: Player): Data?
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.Save(player: Player): boolean
	return saveAsync(player, false)
end

-- Ідемпотентність покупок: true, якщо цей receipt уже оброблено.
function DataService.HasReceipt(data: Data, purchaseId: string): boolean
	return table.find(data.receipts, purchaseId) ~= nil
end

function DataService.AddReceipt(data: Data, purchaseId: string)
	table.insert(data.receipts, purchaseId)
	while #data.receipts > MAX_RECEIPTS do
		table.remove(data.receipts, 1)
	end
end

function DataService.NewUid(): string
	return HttpService:GenerateGUID(false)
end

local function onPlayerAdded(player: Player)
	local data = loadAsync(player)
	if not player.Parent then
		if data then
			-- Гравець вийшов під час завантаження — звільняємо лок сесії.
			profiles[player] = data
			saveAsync(player, true)
			profiles[player] = nil
		end
		return
	end
	if not data then
		player:Kick("Не вдалося завантажити твій прогрес. Перезайди, будь ласка.")
		return
	end
	profiles[player] = data
	sessionStart[player] = os.time()
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		saveAsync(player, true)
	end
	profiles[player] = nil
	sessionStart[player] = nil
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(saveAsync, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveAsync(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService

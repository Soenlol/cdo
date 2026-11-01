-- Profils joueurs : crédits, EXP, maîtrise, voitures, records, médailles, contrats (DataStore)

local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Rallye").Config)

local Data = {}
local store, bestStores = nil, {}
pcall(function() store = DataStoreService:GetDataStore("PistePoussiere_Profils_v1") end)

Data.profiles = {}

local function default()
	return {
		v = 1, cr = 500, exp = 0, tokens = 0,
		car = "moineau", owned = {moineau = true},
		paints = {}, ownedPaints = {["1"] = true}, medalTiers = {},
		gloves = "cuir", ownedGloves = {cuir = true},
		mastery = {},
		best = {}, medals = {}, coins = {}, runs = 0, km = 0,
		lastDay = "", contracts = nil,
		settings = {camera = 1, manual = false, sens = 1, hints = true, ghost = true, passengers = true},
	}
end

local function merge(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then dst[k] = v
		elseif type(v) == "table" and type(dst[k]) == "table" and k == "settings" then merge(dst[k], v) end
	end
	return dst
end

function Data.today()
	return os.date("!%Y-%m-%d")
end

function Data.load(player)
	local prof
	if store then
		for _ = 1, 3 do
			local ok, res = pcall(function() return store:GetAsync("p_" .. player.UserId) end)
			if ok then prof = res; break end
			task.wait(1)
		end
	end
	prof = merge(prof or {}, default())
	Data.profiles[player] = prof
	Data.refreshContracts(prof)
	return prof
end

function Data.save(player)
	local prof = Data.profiles[player]
	if not prof or not store then return end
	pcall(function() store:SetAsync("p_" .. player.UserId, prof) end)
end

function Data.release(player)
	Data.save(player)
	Data.profiles[player] = nil
end

-- contrats du jour (3 tirés selon la date)
function Data.refreshContracts(prof)
	local day = Data.today()
	if prof.contracts and prof.contracts.day == day then return end
	local seed = 0
	for i = 1, #day do seed = seed + string.byte(day, i) * i end
	local list, used = {}, {}
	local n = #Config.CONTRACTS
	local k = seed
	while #list < 3 do
		k = (k * 1103515245 + 12345) % 2147483648
		local idx = (k % n) + 1
		if not used[idx] then
			used[idx] = true
			local c = Config.CONTRACTS[idx]
			list[#list + 1] = {id = c.id, progress = 0, done = false, claimed = false}
		end
	end
	prof.contracts = {day = day, list = list}
end

function Data.contractProgress(prof, id, amount)
	Data.refreshContracts(prof)
	for _, c in ipairs(prof.contracts.list) do
		if c.id == id and not c.done then
			local def
			for _, d in ipairs(Config.CONTRACTS) do if d.id == id then def = d end end
			c.progress = math.min(def.goal, c.progress + amount)
			if c.progress >= def.goal then c.done = true end
		end
	end
end

function Data.level(prof)
	return math.floor(prof.exp / Config.LEVEL_EXP) + 1
end

function Data.masteryLevel(exp)
	local lvl = 1
	for i, need in ipairs(Config.MASTERY_EXP) do
		if exp >= need then lvl = i end
	end
	return lvl
end

-- classement mondial par étape (temps en millisecondes, plus petit = meilleur)
function Data.bestStore(stageId)
	if bestStores[stageId] == nil then
		local ok, s = pcall(function() return DataStoreService:GetOrderedDataStore("PistePoussiere_Temps_" .. stageId) end)
		bestStores[stageId] = ok and s or false
	end
	return bestStores[stageId] or nil
end

function Data.submitTime(player, stageId, t)
	local s = Data.bestStore(stageId)
	if not s then return end
	local ms = math.floor(t * 1000)
	pcall(function()
		s:UpdateAsync(tostring(player.UserId), function(old)
			if old == nil or ms < old then return ms end
			return nil
		end)
	end)
end

function Data.topTimes(stageId, n)
	local s = Data.bestStore(stageId)
	if not s then return {} end
	local out = {}
	local ok, pages = pcall(function() return s:GetSortedAsync(true, n or 10) end)
	if ok and pages then
		for _, e in ipairs(pages:GetCurrentPage()) do
			out[#out + 1] = {userId = tonumber(e.key), t = e.value / 1000}
		end
	end
	return out
end

return Data

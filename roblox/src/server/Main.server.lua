-- Piste Poussière : serveur principal
-- Construit le parc et les étapes, gère les profils, les courses, les récompenses, les défis et les passagers.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local PhysicsService = game:GetService("PhysicsService")
local MarketplaceService = game:GetService("MarketplaceService")
local Lighting = game:GetService("Lighting")

Players.CharacterAutoLoads = false

local Shared = RS:WaitForChild("Rallye")
local Config = require(Shared.Config)
local Track = require(Shared.Track)
local Cars = require(Shared.Cars)
local ServerMods = SSS:WaitForChild("RallyeServer")
local Builder = require(ServerMods.Builder)
local Data = require(ServerMods.Data)

local M = Config.M
workspace.Gravity = Config.G * M

-- groupes de collision : les voitures se traversent (courses fantômes)
pcall(function()
	PhysicsService:RegisterCollisionGroup("Cars")
	PhysicsService:CollisionGroupSetCollidable("Cars", "Cars", false)
	-- personnages assis dans les voitures : ne touchent rien
	PhysicsService:RegisterCollisionGroup("Riders")
	PhysicsService:CollisionGroupSetCollidable("Riders", "Default", false)
	PhysicsService:CollisionGroupSetCollidable("Riders", "Cars", false)
	PhysicsService:CollisionGroupSetCollidable("Riders", "Riders", false)
end)

-- éclairage doux
Lighting.ClockTime = 14
Lighting.Brightness = 2.2
Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 130)
Lighting.GlobalShadows = true
local atm = Instance.new("Atmosphere")
atm.Density = 0.28
atm.Haze = 1.2
atm.Parent = Lighting

-- communication
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local Request = Instance.new("RemoteFunction")
Request.Name = "Request"
Request.Parent = remotes
local Push = Instance.new("RemoteEvent")
Push.Name = "Push"
Push.Parent = remotes
remotes.Parent = Shared

local world = Instance.new("Folder")
world.Name = "Rallye"
world.Parent = workspace
local stagesFolder = Instance.new("Folder")
stagesFolder.Name = "Stages"
stagesFolder.Parent = world
local carsFolder = Instance.new("Folder")
carsFolder.Name = "Cars"
carsFolder.Parent = world

Builder.applyMaterialColors()
local hub, hubSpawn = Builder.buildHub(world)

local tracks = {}
local origins = Builder.layout()
local session = {}
local hubReady = true

---------------------------------------------------------------------------
-- outils
---------------------------------------------------------------------------
local function now() return workspace:GetServerTimeNow() end

local function push(player, kind, data)
	if player and player.Parent then Push:FireClient(player, kind, data) end
end

local function sendProfile(player)
	local prof = Data.profiles[player]
	if prof then
		player:SetAttribute("Level", Data.level(prof))
		push(player, "profile", prof)
	end
end

local function notify(player, text)
	push(player, "notify", {text = text})
end

local function isVip(player)
	if Config.VIP_GAMEPASS_ID == 0 then return false end
	local ok, res = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.VIP_GAMEPASS_ID) end)
	return ok and res
end

local function ownsComete(player)
	if Config.COMETE_GAMEPASS_ID == 0 then return false end
	local ok, res = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.COMETE_GAMEPASS_ID) end)
	return ok and res
end

local function setGroup(model, group)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.CollisionGroup = group end
	end
end

local function hubPosition()
	return hubSpawn.CFrame + Vector3.new(math.random(-6, 6), 4, math.random(-6, 6))
end

local function getSession(player)
	if not session[player] then session[player] = {} end
	return session[player]
end

---------------------------------------------------------------------------
-- voitures
---------------------------------------------------------------------------
local function unseat(humanoid)
	if not humanoid then return end
	humanoid.Sit = false
	if humanoid.SeatPart then
		local w = humanoid.SeatPart:FindFirstChild("SeatWeld")
		if w then w:Destroy() end
	end
end

local function charParts(char, massless)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Massless = massless
			d.CollisionGroup = massless and "Riders" or "Default"
		end
	end
end

local function removeCar(player)
	local ses = getSession(player)
	-- passager éventuel : retour au parc
	if ses.passenger and ses.passenger.Parent then
		local p = ses.passenger
		local ps = getSession(p)
		ps.riding = nil
		if p.Character then
			unseat(p.Character:FindFirstChildOfClass("Humanoid"))
			charParts(p.Character, false)
			p.Character:PivotTo(hubPosition())
		end
		push(p, "passengerEnd", {})
	end
	ses.passenger = nil
	if player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		unseat(hum)
		charParts(player.Character, false)
	end
	if ses.copilot then ses.copilot:Destroy(); ses.copilot = nil end
	if ses.car then ses.car:Destroy(); ses.car = nil end
	ses.run = nil
	player:SetAttribute("StageName", nil)
end

local function toHub(player)
	removeCar(player)
	local ses = getSession(player)
	if ses.riding then
		local d = ses.riding
		ses.riding = nil
		if d.Parent then getSession(d).passenger = nil end
	end
	if player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		unseat(hum)
		charParts(player.Character, false)
		task.wait()
		player.Character:PivotTo(hubPosition())
	end
end

-- copilote IA : l'avatar d'un ami (ou un avatar par défaut)
local function makeCopilot(player, seat)
	local ses = getSession(player)
	local rig
	local name = "Copilote"
	if ses.friendId then
		local ok, r = pcall(function() return Players:CreateHumanoidModelFromUserId(ses.friendId) end)
		if ok and r then rig = r; name = ses.friendName or name end
	end
	if not rig then
		local ok, r = pcall(function()
			return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		end)
		if ok then rig = r end
	end
	if not rig then return end
	rig.Name = name
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Massless = true
			d.CanCollide = false
			d.CollisionGroup = "Riders"
		end
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
	rig:PivotTo(seat.CFrame + Vector3.new(0, 2, 0))
	rig.Parent = seat.Parent
	if hum then seat:Sit(hum) end
	ses.copilot = rig
	ses.copilotName = name
end

local function spawnCar(player, stageId, carId)
	local T = tracks[stageId]
	local origin = origins[stageId]
	local car = Config.CAR_BY_ID[carId]
	local prof = Data.profiles[player]
	removeCar(player)
	local paintIdx = prof.paints[carId]
	local rgb = paintIdx and Config.PAINTS[paintIdx] and Config.PAINTS[paintIdx].rgb or nil
	local model = Cars.build(car, rgb)
	model.Name = player.Name .. "_" .. car.id
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Stage", stageId)
	local s = T.S[Track.indexAtD(T, Config.SPAWN_D)]
	local pos = origin + Vector3.new(s.x * M, (s.y + 1.2) * M, s.z * M)
	local fwd = Vector3.new(math.sin(s.h), 0, math.cos(s.h))
	model:PivotTo(CFrame.lookAt(pos, pos + fwd))
	setGroup(model, "Cars")
	model.Parent = carsFolder
	local ses = getSession(player)
	ses.car = model

	local char = player.Character
	if not char or not char.Parent then
		player:LoadCharacter()
		char = player.Character or player.CharacterAdded:Wait()
	end
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then
		unseat(hum)
		charParts(char, true)
		char:PivotTo(model.DriverSeat.CFrame + Vector3.new(0, 3, 0))
		model.DriverSeat:Sit(hum)
	end
	pcall(function() model.PrimaryPart:SetNetworkOwner(player) end)
	makeCopilot(player, model.PassengerSeat)
	return model
end

---------------------------------------------------------------------------
-- course
---------------------------------------------------------------------------
local function beginRun(player, stageId, carId, startAt, challenge)
	local prof = Data.profiles[player]
	if not prof then return false, "Profil non chargé" end
	local T = tracks[stageId]
	if not T then return false, "Étape en construction, patiente quelques secondes" end
	local car = Config.CAR_BY_ID[carId]
	if not car or not prof.owned[carId] then return false, "Voiture non possédée" end
	local model = spawnCar(player, stageId, carId)
	local ses = getSession(player)
	ses.run = {stageId = stageId, carId = carId, startAt = startAt, cps = {}, challenge = challenge}
	player:SetAttribute("StageName", Config.STAGE_BY_ID[stageId].name)
	prof.car = carId
	push(player, "raceStart", {stageId = stageId, carId = carId, startAt = startAt, carName = model.Name,
		challenge = challenge and {opponent = challenge.names[player]} or nil, copilot = ses.copilotName})
	return true
end

local function medalFor(T, total)
	local best = nil
	for _, m in ipairs(Config.MEDALS) do
		if total <= T.medals[m] then best = m end
	end
	return best
end

local function medalRank(m)
	for i, x in ipairs(Config.MEDALS) do if x == m then return i end end
	return 0
end

local challenges = {}
local nextChallenge = 1

local function finishChallenge(ch)
	if ch.done then return end
	ch.done = true
	local a, b = ch.players[1], ch.players[2]
	local ta, tb = ch.results[a], ch.results[b]
	local winner
	if ta and tb then winner = (ta <= tb) and a or b elseif ta then winner = a elseif tb then winner = b end
	for _, p in ipairs(ch.players) do
		push(p, "challengeResult", {
			you = ch.results[p], opponent = ch.results[(p == a) and b or a],
			opponentName = ch.names[p], win = (winner == p), stage = ch.stageId,
		})
	end
	challenges[ch.id] = nil
end

local function onFinish(player, info)
	local ses = getSession(player)
	local run = ses.run
	local prof = Data.profiles[player]
	if not run or not prof or run.finished then return nil end
	local T = tracks[run.stageId]
	local stage = Config.STAGE_BY_ID[run.stageId]
	local car = Config.CAR_BY_ID[run.carId]
	-- contrôles : tous les points de passage, temps cohérent avec l'horloge serveur
	if #run.cps < #T.cps then return {error = "Points de passage manquants"} end
	local raw = tonumber(info.raw) or 0
	local pen = math.max(0, tonumber(info.pen) or 0)
	local elapsed = now() - run.startAt
	-- le chrono démarre à l'arche (quelques secondes après le feu vert) : il ne peut pas être
	-- beaucoup plus court que le temps écoulé côté serveur
	if raw < elapsed - 15 or raw < T.par * 0.7 then
		raw = math.max(elapsed - 3, T.par * 0.7)
	end
	run.finished = true
	local total = math.floor((raw + pen) * 1000 + 0.5) / 1000

	local vip = isVip(player)
	local mult = vip and 2 or 1
	local rewards = {}
	local expSum, crSum = 0, 0
	local function give(labelText, r)
		rewards[#rewards + 1] = {label = labelText, exp = r.exp * mult, cr = r.cr * mult}
		expSum = expSum + r.exp * mult
		crSum = crSum + r.cr * mult
	end
	give("Fin d'étape", Config.REWARDS.finish)
	local medal = medalFor(T, total)
	if medal then
		give("Médaille " .. Config.MEDAL_NAMES[medal], Config.REWARDS.medal[medal])
		prof.medalTiers[run.stageId] = prof.medalTiers[run.stageId] or {}
		if not prof.medalTiers[run.stageId][medal] then
			prof.medalTiers[run.stageId][medal] = true
			give("Première médaille " .. Config.MEDAL_NAMES[medal], Config.REWARDS.firstMedal)
		end
		if medalRank(medal) > medalRank(prof.medals[run.stageId]) then prof.medals[run.stageId] = medal end
	end
	local today = Data.today()
	if prof.lastDay ~= today then
		prof.lastDay = today
		give("Première course du jour", Config.REWARDS.firstOfDay)
	end
	-- pièces
	prof.coins[run.stageId] = prof.coins[run.stageId] or {}
	local newCoins = 0
	local got = 0
	if type(info.coins) == "table" then
		for _, k in ipairs(info.coins) do
			k = tonumber(k)
			if k and T.coins[k] then
				got = got + 1
				if not prof.coins[run.stageId][tostring(k)] then
					prof.coins[run.stageId][tostring(k)] = true
					newCoins = newCoins + 1
				end
			end
		end
	end
	if newCoins > 0 then
		give(newCoins .. " nouvelle(s) pièce(s)", {exp = 0, cr = Config.REWARDS.coin.cr * newCoins})
	end
	-- jetons d'événement
	local tokens = 0
	if stage.event then
		tokens = medal and Config.EVENT.tokens[medal] or 1
		prof.tokens = prof.tokens + tokens
		if prof.tokens >= 10 then prof.ownedGloves.sable = true end
	end

	prof.exp = prof.exp + expSum
	prof.cr = prof.cr + crSum
	local oldM = Data.masteryLevel(prof.mastery[run.carId] or 0)
	prof.mastery[run.carId] = (prof.mastery[run.carId] or 0) + expSum
	local newM = Data.masteryLevel(prof.mastery[run.carId])
	if newM >= 10 then prof.ownedGloves["or"] = true end
	prof.runs = prof.runs + 1
	prof.km = prof.km + T.stageLength / 1000

	-- record
	local prev = prof.best[run.stageId]
	local newBest = (prev == nil) or total < prev.t
	local bestSplits = prev and prev.splits or nil
	if newBest then
		prof.best[run.stageId] = {t = total, car = run.carId, splits = run.cps}
		Data.submitTime(player, run.stageId, total)
	end

	-- contrats
	Data.contractProgress(prof, "finish3", 1)
	if medal and medalRank(medal) >= 3 then Data.contractProgress(prof, "gold1", 1) end
	Data.contractProgress(prof, "coins15", got)
	if pen == 0 then Data.contractProgress(prof, "clean2", 1) end
	if Config.SNOW_STAGES[run.stageId] then Data.contractProgress(prof, "snow1", 1) end
	Data.contractProgress(prof, "km5", math.floor(T.stageLength / 100) / 10)
	if car.front == 1 then Data.contractProgress(prof, "fwd1", 1) end
	local hp = 0
	for _, c in ipairs(T.corners) do if c.hairpin then hp = hp + 1 end end
	Data.contractProgress(prof, "hairpin10", hp)

	if run.challenge then
		run.challenge.results[player] = total
		local all = true
		for _, p in ipairs(run.challenge.players) do
			if not run.challenge.results[p] and p.Parent then all = false end
		end
		if all then finishChallenge(run.challenge) end
	end

	sendProfile(player)
	return {
		total = total, raw = raw, pen = pen, medal = medal, rewards = rewards, exp = expSum, cr = crSum,
		newBest = newBest, prev = prev and prev.t or nil, splits = run.cps, bestSplits = bestSplits,
		tokens = tokens, mastery = newM, masteryUp = newM > oldM, vip = vip, medals = T.medals,
	}
end

---------------------------------------------------------------------------
-- requêtes des clients
---------------------------------------------------------------------------
local leaderboards = {}
local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then return nameCache[userId] end
	local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	nameCache[userId] = ok and n or ("#" .. userId)
	return nameCache[userId]
end

local function refreshBoards()
	for _, st in ipairs(Config.STAGES) do
		local list = Data.topTimes(st.id, 10)
		for _, e in ipairs(list) do e.name = nameOf(e.userId) end
		leaderboards[st.id] = list
	end
end

local H = {}

function H.getProfile(player)
	local prof = Data.profiles[player]
	while not prof and player.Parent do
		task.wait(0.2)
		prof = Data.profiles[player]
	end
	return {profile = prof, vip = isVip(player), comete = Config.COMETE_GAMEPASS_ID ~= 0, cometeId = Config.COMETE_GAMEPASS_ID, vipId = Config.VIP_GAMEPASS_ID}
end

function H.leaderboard(player, stageId)
	return leaderboards[stageId] or {}
end

function H.startStage(player, stageId, carId)
	local ses = getSession(player)
	if ses.riding then return {ok = false, msg = "Tu es passager"} end
	local ok, msg = beginRun(player, stageId, carId, now() + 4.5, nil)
	return {ok = ok, msg = msg}
end

function H.checkpoint(player, k, t)
	local run = getSession(player).run
	if not run then return false end
	k = tonumber(k)
	if k == #run.cps + 1 then run.cps[k] = tonumber(t) or 0 end
	return true
end

function H.finish(player, info)
	if type(info) ~= "table" then return nil end
	return onFinish(player, info)
end

function H.abandon(player)
	local ses = getSession(player)
	if ses.run and ses.run.challenge and not ses.run.finished then
		local ch = ses.run.challenge
		ses.run.finished = true
		local all = true
		for _, p in ipairs(ch.players) do
			if p ~= player and not ch.results[p] and p.Parent and getSession(p).run then all = false end
		end
		if all then finishChallenge(ch) end
	end
	toHub(player)
	return true
end

function H.freeRoam(player)
	toHub(player)
	return true
end

function H.buyCar(player, carId)
	local prof = Data.profiles[player]
	local car = Config.CAR_BY_ID[carId]
	if not car or prof.owned[carId] then return {ok = false} end
	if car.gamepass and Config[car.gamepass] ~= 0 then
		return {ok = false, msg = "Disponible avec le pass de jeu", gamepass = Config[car.gamepass]}
	end
	if prof.cr < car.price then return {ok = false, msg = "Crédits insuffisants"} end
	prof.cr = prof.cr - car.price
	prof.owned[carId] = true
	prof.car = carId
	sendProfile(player)
	return {ok = true}
end

function H.selectCar(player, carId)
	local prof = Data.profiles[player]
	if prof.owned[carId] then prof.car = carId; sendProfile(player); return true end
	return false
end

function H.setPaint(player, carId, idx)
	local prof = Data.profiles[player]
	idx = tonumber(idx)
	if not idx or not Config.PAINTS[idx] or not prof.ownedPaints[tostring(idx)] then return false end
	prof.paints[carId] = idx
	sendProfile(player)
	return true
end

function H.setGloves(player, id)
	local prof = Data.profiles[player]
	if prof.ownedGloves[id] then prof.gloves = id; sendProfile(player); return true end
	return false
end

function H.buyGloves(player, id)
	local prof = Data.profiles[player]
	for _, g in ipairs(Config.GLOVES) do
		if g.id == id and g.price and not prof.ownedGloves[id] and prof.cr >= g.price then
			prof.cr = prof.cr - g.price
			prof.ownedGloves[id] = true
			prof.gloves = id
			sendProfile(player)
			return {ok = true}
		end
	end
	return {ok = false, msg = "Achat impossible"}
end

function H.openCrate(player, kind)
	local prof = Data.profiles[player]
	local crate = Config.CRATES[kind]
	if not crate then return {ok = false} end
	if prof.cr < crate.price then return {ok = false, msg = "Crédits insuffisants"} end
	prof.cr = prof.cr - crate.price
	local result
	if kind == "paint" then
		local pool = {}
		for i = 2, #Config.PAINTS do if not prof.ownedPaints[tostring(i)] then pool[#pool + 1] = i end end
		if #pool == 0 then
			prof.cr = prof.cr + math.floor(crate.price / 2)
			result = {ok = true, text = "Toutes les peintures sont à toi : 50 % remboursés"}
		else
			local i = pool[math.random(1, #pool)]
			prof.ownedPaints[tostring(i)] = true
			result = {ok = true, text = "Nouvelle peinture : " .. Config.PAINTS[i].name, paint = i}
		end
	elseif kind == "perf" then
		-- caisse de performance : une voiture au hasard (les classes basses sortent plus souvent)
		local pool, total = {}, 0
		for _, c in ipairs(Config.CARS) do
			if not prof.owned[c.id] and not c.gamepass then
				local w = ({D = 10, C = 7, B = 5, A = 3, S = 1})[c.cls] or 1
				pool[#pool + 1] = {c, w}
				total = total + w
			end
		end
		if #pool == 0 then
			prof.cr = prof.cr + math.floor(crate.price / 2)
			result = {ok = true, text = "Garage complet : 50 % remboursés"}
		else
			local r = math.random() * total
			local pick = pool[1][1]
			for _, e in ipairs(pool) do
				r = r - e[2]
				if r <= 0 then pick = e[1]; break end
			end
			prof.owned[pick.id] = true
			result = {ok = true, text = "Nouvelle voiture : " .. pick.name .. " (" .. pick.cls .. ")", car = pick.id}
		end
	elseif kind == "glove" then
		local pool = {}
		for _, g in ipairs(Config.GLOVES) do
			if g.price and not prof.ownedGloves[g.id] then pool[#pool + 1] = g end
		end
		if #pool == 0 then
			prof.cr = prof.cr + math.floor(crate.price / 2)
			result = {ok = true, text = "Tous les gants sont à toi : 50 % remboursés"}
		else
			local g = pool[math.random(1, #pool)]
			prof.ownedGloves[g.id] = true
			result = {ok = true, text = "Nouveaux gants : " .. g.name}
		end
	end
	sendProfile(player)
	return result
end

function H.claimContract(player, id)
	local prof = Data.profiles[player]
	Data.refreshContracts(prof)
	for _, c in ipairs(prof.contracts.list) do
		if c.id == id and c.done and not c.claimed then
			for _, d in ipairs(Config.CONTRACTS) do
				if d.id == id then prof.cr = prof.cr + d.cr end
			end
			c.claimed = true
			sendProfile(player)
			return true
		end
	end
	return false
end

function H.setSettings(player, s)
	local prof = Data.profiles[player]
	if type(s) ~= "table" then return false end
	for k, v in pairs(s) do
		if prof.settings[k] ~= nil and type(v) == type(prof.settings[k]) then prof.settings[k] = v end
	end
	return true
end

-- défis tête-à-tête
function H.challenge(player, targetId, stageId)
	local target = Players:GetPlayerByUserId(tonumber(targetId) or 0)
	if not target or target == player or not tracks[stageId] then return {ok = false, msg = "Défi impossible"} end
	local id = nextChallenge
	nextChallenge = nextChallenge + 1
	challenges[id] = {id = id, from = player, to = target, stageId = stageId, created = os.clock(), results = {},
		players = {player, target}, names = {[player] = target.DisplayName, [target] = player.DisplayName}}
	push(target, "invite", {id = id, from = player.DisplayName, stage = Config.STAGE_BY_ID[stageId].name})
	return {ok = true}
end

function H.challengeReply(player, id, accept)
	local ch = challenges[tonumber(id) or 0]
	if not ch or ch.to ~= player then return false end
	if not accept or not ch.from.Parent then
		challenges[ch.id] = nil
		notify(ch.from, player.DisplayName .. " a refusé le défi")
		return true
	end
	local startAt = now() + 7
	for _, p in ipairs(ch.players) do
		local prof = Data.profiles[p]
		task.spawn(function()
			local ok, msg = beginRun(p, ch.stageId, prof.car, startAt, ch)
			if not ok then notify(p, msg) end
		end)
	end
	return true
end

-- conduite partagée : monter à côté d'un chauffeur
function H.drivers(player)
	local out = {}
	for p, ses in pairs(session) do
		if p ~= player and p.Parent and ses.car and ses.run and not ses.passenger then
			local prof = Data.profiles[p]
			if prof and prof.settings.passengers then
				out[#out + 1] = {userId = p.UserId, name = p.DisplayName, stage = Config.STAGE_BY_ID[ses.run.stageId].name, car = Config.CAR_BY_ID[ses.run.carId].name}
			end
		end
	end
	return out
end

function H.joinPassenger(player, driverId)
	local driver = Players:GetPlayerByUserId(tonumber(driverId) or 0)
	if not driver then return {ok = false, msg = "Chauffeur introuvable"} end
	local ds = getSession(driver)
	if not ds.car or ds.passenger then return {ok = false, msg = "Place occupée"} end
	removeCar(player)
	if ds.copilot then ds.copilot:Destroy(); ds.copilot = nil end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return {ok = false} end
	charParts(char, true)
	char:PivotTo(ds.car.PassengerSeat.CFrame + Vector3.new(0, 3, 0))
	ds.car.PassengerSeat:Sit(hum)
	ds.passenger = player
	getSession(player).riding = driver
	push(player, "passengerStart", {driver = driver.DisplayName, stageId = ds.run.stageId, carName = ds.car.Name, carId = ds.run.carId, startAt = ds.run.startAt})
	push(driver, "notify", {text = player.DisplayName .. " est ton copilote !"})
	push(driver, "copilotName", {name = player.DisplayName})
	return {ok = true}
end

function H.leavePassenger(player)
	toHub(player)
	return true
end

function H.callout(player, text)
	local driver = getSession(player).riding
	if driver and type(text) == "string" and #text < 40 then
		push(driver, "callout", {from = player.DisplayName, text = text})
	end
	return true
end

function H.buildStatus(player)
	local out = {}
	for _, st in ipairs(Config.STAGES) do out[st.id] = tracks[st.id] ~= nil end
	return out
end

Request.OnServerInvoke = function(player, action, ...)
	local f = H[action]
	if not f then return nil end
	local ok, res = pcall(f, player, ...)
	if not ok then
		warn("[Rallye] " .. tostring(action) .. " : " .. tostring(res))
		return nil
	end
	return res
end

---------------------------------------------------------------------------
-- joueurs
---------------------------------------------------------------------------
local function onPlayer(player)
	Data.load(player)
	local ses = getSession(player)
	task.spawn(function()
		local ok, pages = pcall(function() return Players:GetFriendsAsync(player.UserId) end)
		if ok and pages then
			local page = pages:GetCurrentPage()
			if page[1] then
				ses.friendId = page[1].Id
				ses.friendName = page[1].DisplayName or page[1].Username
			end
		end
	end)
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			task.wait(3)
			if player.Parent then
				removeCar(player)
				player:LoadCharacter()
			end
		end)
	end)
	player:LoadCharacter()
	sendProfile(player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end

Players.PlayerRemoving:Connect(function(player)
	removeCar(player)
	local ses = session[player]
	if ses and ses.riding and ses.riding.Parent then getSession(ses.riding).passenger = nil end
	for _, ch in pairs(challenges) do
		for _, p in ipairs(ch.players) do
			if p == player then finishChallenge(ch) break end
		end
	end
	session[player] = nil
	Data.release(player)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then return end
	local prof = Data.profiles[player]
	if not prof then return end
	if passId == Config.COMETE_GAMEPASS_ID then prof.owned.comete = true end
	sendProfile(player)
	notify(player, "Merci pour ton achat !")
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do Data.save(p) end
	task.wait(2)
end)

-- sauvegarde régulière, contrats du jour, pass Comète
task.spawn(function()
	while true do
		task.wait(120)
		for _, p in ipairs(Players:GetPlayers()) do
			local prof = Data.profiles[p]
			if prof then
				if not prof.owned.comete and ownsComete(p) then prof.owned.comete = true; sendProfile(p) end
				Data.save(p)
			end
		end
	end
end)

-- défis expirés
task.spawn(function()
	while true do
		task.wait(10)
		for id, ch in pairs(challenges) do
			if os.clock() - ch.created > 900 then finishChallenge(ch) end
		end
	end
end)

---------------------------------------------------------------------------
-- construction des étapes (en arrière-plan, l'une après l'autre)
---------------------------------------------------------------------------
task.spawn(function()
	for i, st in ipairs(Config.STAGES) do
		Shared:SetAttribute("Building", st.name)
		local ok, err = pcall(function()
			local T = Builder.buildStage(st, origins[st.id], stagesFolder, function(p)
				Shared:SetAttribute("BuildProgress", (i - 1 + p) / #Config.STAGES)
			end)
			tracks[st.id] = T
		end)
		if not ok then warn("[Rallye] construction " .. st.id .. " : " .. tostring(err)) end
		Push:FireAllClients("stageReady", {id = st.id})
	end
	Shared:SetAttribute("Building", nil)
	Shared:SetAttribute("BuildProgress", 1)
	refreshBoards()
	while true do
		task.wait(90)
		refreshBoards()
	end
end)

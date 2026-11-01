-- Piste Poussière : script client principal (relie menus, course, replay et messages du serveur)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")

local Shared = RS:WaitForChild("Rallye")
local Config = require(Shared.Config)
local ClientMods = Shared:WaitForChild("Client")
local Ui = require(ClientMods.Ui)
local Hud = require(ClientMods.Hud)
local Menus = require(ClientMods.Menus)
local Drive = require(ClientMods.Drive)
local Replay = require(ClientMods.Replay)

local player = Players.LocalPlayer
local Remotes = Shared:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("Request")
local Push = Remotes:WaitForChild("Push")

workspace.Gravity = Config.G * Config.M

local function req(...)
	local ok, res = pcall(Request.InvokeServer, Request, ...)
	if not ok then warn("[Rallye] " .. tostring(res)) return nil end
	return res
end

local App = {
	profile = nil, vip = false, vipId = 0, cometeId = 0,
	leaderboards = {}, stageReady = {}, lastStage = nil, req = req,
}

function App.startStage(stageId)
	App.lastStage = stageId
	Menus.close()
	local res = req("startStage", stageId, App.profile.car)
	if not res or not res.ok then
		Menus.toast((res and res.msg) or "Départ impossible", Ui.C.red)
		Menus.showTop(true)
	end
end

function App.retry()
	if App.lastStage then App.startStage(App.lastStage) end
end

function App.toHub()
	Drive.stop()
	req("abandon")
	Menus.showTop(true)
end

function App.freeRoam()
	Drive.stop()
	req("freeRoam")
	Menus.showTop(true)
end

function App.replay(data, resultsArg)
	Drive.stop()
	if not data then
		Menus.open("results", resultsArg)
		return
	end
	local paintIdx = App.profile.paints[data.car.id]
	local rgb = paintIdx and Config.PAINTS[paintIdx] and Config.PAINTS[paintIdx].rgb or nil
	Replay.play(data, rgb, function()
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		Menus.open("results", resultsArg)
	end)
end

-- démarrage
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
local pg = player:WaitForChild("PlayerGui")
Hud.create(pg)
local init = req("getProfile") or {}
App.profile = init.profile
App.vip = init.vip
App.vipId = init.vipId or 0
App.cometeId = init.cometeId or 0
local status = req("buildStatus") or {}
for id, ok in pairs(status) do App.stageReady[id] = ok end
Menus.init(App)
Menus.open("main")

-- messages du serveur
Push.OnClientEvent:Connect(function(kind, data)
	if kind == "profile" then
		App.profile = data
		Menus.refreshTop()
	elseif kind == "raceStart" then
		Menus.close()
		Menus.showTop(false)
		App.lastStage = data.stageId
		task.spawn(function()
			Drive.start({
				stageId = data.stageId, carId = data.carId, carName = data.carName, startAt = data.startAt, mode = "driver",
				profile = App.profile, copilot = data.copilot, challenge = data.challenge,
				onFinish = function(result, replay)
					Menus.open("results", {result = result, replay = replay})
				end,
			})
			if data.challenge then
				Hud.tip("Défi contre " .. data.challenge.opponent .. " : que le meilleur gagne !", 4)
			end
		end)
	elseif kind == "passengerStart" then
		Menus.close()
		Menus.showTop(false)
		task.spawn(function()
			Drive.start({stageId = data.stageId, carId = data.carId, carName = data.carName, startAt = data.startAt, mode = "passenger",
				profile = App.profile, copilot = player.DisplayName .. " (toi)"})
			Hud.tip("Tu es le copilote de " .. data.driver .. " !", 4)
		end)
	elseif kind == "passengerEnd" then
		Drive.stop()
		Menus.showTop(true)
		Menus.toast("Fin de la course de ton chauffeur")
	elseif kind == "callout" then
		Drive.onCallout(data.from, data.text)
	elseif kind == "copilotName" then
		Drive.setCopilot(data.name)
	elseif kind == "invite" then
		Menus.invite(data)
	elseif kind == "challengeResult" then
		Menus.challengeResult(data)
	elseif kind == "notify" then
		Menus.toast(data.text)
	elseif kind == "stageReady" then
		App.stageReady[data.id] = true
	end
end)

-- panneaux du parc (ProximityPrompt)
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player then return end
	local action = prompt:GetAttribute("Action")
	if not action or Drive.active() then return end
	if action == "garage" then Menus.open("garage")
	elseif action == "shop" or action == "crate" then Menus.open("shop")
	elseif action == "contracts" then Menus.open("contracts")
	elseif action == "menu" then Menus.open("main")
	elseif string.sub(action, 1, 6) == "stage:" then
		local id = string.sub(action, 7)
		if App.stageReady[id] then App.startStage(id) else Menus.toast("Étape en construction, patiente un peu…") end
	elseif string.sub(action, 1, 7) == "garage:" then Menus.open("garage", string.sub(action, 8))
	end
end)

-- rafraîchissements
task.spawn(function()
	local n = 0
	while true do
		task.wait(2)
		n = n + 1
		Menus.refreshTop()
		if Drive.active() and n % 2 == 0 then Hud.updatePlayers() end
		if n % 30 == 1 then
			for _, st in ipairs(Config.STAGES) do
				if App.stageReady[st.id] then
					local lb = req("leaderboard", st.id)
					if lb then App.leaderboards[st.id] = lb end
				end
			end
		end
	end
end)

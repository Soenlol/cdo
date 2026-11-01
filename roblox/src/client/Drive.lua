-- Session de course côté client : pilotage (suspension par rayons + modèle de pneus),
-- caméra, chrono, points de passage, pénalités, copilote, dégâts, fantôme et enregistrement du replay.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Rallye")
local Config = require(Shared.Config)
local Track = require(Shared.Track)
local Physics = require(Shared.Physics)
local Cars = require(Shared.Cars)
local Hud = require(script.Parent.Hud)
local Ui = require(script.Parent.Ui)

local Drive = {}
local player = Players.LocalPlayer
local M = Config.M
local HALF = Config.HALF
local camera = workspace.CurrentCamera

local trackCache = {}
function Drive.track(stageId)
	if not trackCache[stageId] then trackCache[stageId] = Track.generate(Config.STAGE_BY_ID[stageId]) end
	return trackCache[stageId]
end

function Drive.origin(stageId)
	local f = workspace:WaitForChild("Rallye"):WaitForChild("Stages"):WaitForChild(stageId, 60)
	if not f then return nil end
	while not f:GetAttribute("Ready") do task.wait(0.2) end
	return Vector3.new(f:GetAttribute("OriginX"), f:GetAttribute("OriginY"), f:GetAttribute("OriginZ")), f
end

local ghosts = {} -- meilleur passage de la session par étape+voiture

local input = {gas = 0, brake = 0, left = 0, right = 0, stickX = nil, hb = false, shift = 0}
local S = nil -- session en cours

local function setControls(on)
	local ok, pm = pcall(function() return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")) end)
	if ok and pm then
		local controls = pm:GetControls()
		if on then controls:Enable() else controls:Disable() end
	end
end

local function hum()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

---------------------------------------------------------------------------
-- commandes
---------------------------------------------------------------------------
local SINK = Enum.ContextActionResult.Sink
local PASS = Enum.ContextActionResult.Pass
local K = Enum.KeyCode

local function bindAll()
	local function axis(name, field, keys)
		CAS:BindActionAtPriority(name, function(_, state, obj)
			if obj.KeyCode == K.ButtonR2 or obj.KeyCode == K.ButtonL2 then
				input[field] = math.clamp(obj.Position.Z, 0, 1)
			else
				input[field] = (state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change) and 1 or 0
			end
			return SINK
		end, name ~= "RallyeLeft" and name ~= "RallyeRight", 3000, table.unpack(keys))
	end
	axis("RallyeGas", "gas", {K.W, K.Z, K.Up, K.ButtonR2})
	axis("RallyeBrake", "brake", {K.S, K.Down, K.ButtonL2})
	axis("RallyeLeft", "left", {K.A, K.Q, K.Left})
	axis("RallyeRight", "right", {K.D, K.Right})
	CAS:BindActionAtPriority("RallyeHB", function(_, state)
		input.hb = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
		return SINK
	end, true, 3000, K.Space, K.ButtonX, K.ButtonR1)
	CAS:BindActionAtPriority("RallyeStick", function(_, _, obj)
		local x = obj.Position.X
		input.stickX = math.abs(x) > 0.12 and x or nil
		return SINK
	end, false, 3000, K.Thumbstick1)
	CAS:BindActionAtPriority("RallyeKeys", function(_, state, obj)
		if state ~= Enum.UserInputState.Begin or not S then return PASS end
		local kc = obj.KeyCode
		if kc == K.R or kc == K.ButtonY then Drive.recover(true)
		elseif kc == K.C or kc == K.ButtonR3 then Drive.cycleCamera()
		elseif kc == K.M or kc == K.Semicolon then
			if S.st then
				S.st.manual = not S.st.manual
				Hud.tip(S.st.manual and "Boîte manuelle : E / Maj = monter, F / Ctrl = descendre" or "Boîte automatique", 3)
			end
		elseif kc == K.E or kc == K.LeftShift or kc == K.ButtonB then input.shift = 1
		elseif kc == K.F or kc == K.LeftControl or kc == K.ButtonL1 then input.shift = -1
		elseif kc == K.Return and S.state == "finished" and S.onSkip then S.onSkip()
		elseif kc == K.One then Drive.sendCallout("Serré !")
		elseif kc == K.Two then Drive.sendCallout("À fond !")
		elseif kc == K.Three then Drive.sendCallout("Freine !")
		elseif kc == K.Four then Drive.sendCallout("Bien joué !")
		else return PASS end
		return SINK
	end, false, 3000, K.R, K.C, K.M, K.Semicolon, K.E, K.F, K.LeftShift, K.LeftControl, K.Return, K.ButtonY, K.ButtonR3, K.ButtonB, K.ButtonL1,
		K.One, K.Two, K.Three, K.Four)
	CAS:BindActionAtPriority("RallyeRestart", function(_, state)
		if not S then return PASS end
		if state == Enum.UserInputState.Begin then
			S.restartHold = os.clock()
		elseif state == Enum.UserInputState.End then
			S.restartHold = nil
		end
		return SINK
	end, false, 3000, K.Backspace, K.ButtonSelect)
	pcall(function()
		CAS:SetTitle("RallyeGas", "Gaz")
		CAS:SetTitle("RallyeBrake", "Frein")
		CAS:SetTitle("RallyeHB", "FàM")
		CAS:SetPosition("RallyeGas", UDim2.new(1, -95, 1, -170))
		CAS:SetPosition("RallyeBrake", UDim2.new(1, -175, 1, -110))
		CAS:SetPosition("RallyeHB", UDim2.new(1, -95, 1, -250))
	end)
	-- direction tactile : deux grandes zones à gauche de l'écran
	if UIS.TouchEnabled then
		local pg = player:WaitForChild("PlayerGui")
		local tg = Ui.make("ScreenGui", {Name = "RallyeTouch", ResetOnSpawn = false, Parent = pg})
		for _, side in ipairs({{"left", 0, "◀"}, {"right", 1, "▶"}}) do
			local b = Ui.make("TextButton", {Size = UDim2.fromOffset(90, 90), Position = UDim2.new(0, 20 + side[2] * 100, 1, -120), Text = side[3],
				BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.7, TextSize = 36, Parent = tg})
			Ui.corner(b, 45)
			b.InputBegan:Connect(function() input[side[1]] = 1 end)
			b.InputEnded:Connect(function() input[side[1]] = 0 end)
		end
		S.touchGui = tg
	end
end

local function unbindAll()
	for _, n in ipairs({"RallyeGas", "RallyeBrake", "RallyeLeft", "RallyeRight", "RallyeHB", "RallyeStick", "RallyeKeys", "RallyeRestart"}) do
		CAS:UnbindAction(n)
	end
	for k in pairs(input) do input[k] = 0 end
	input.hb = false
	input.stickX = nil
end

---------------------------------------------------------------------------
-- caméra
---------------------------------------------------------------------------
local CAM_NAMES = {"Poursuite", "Capot", "Cockpit"}
function Drive.cycleCamera()
	if not S then return end
	S.camMode = S.camMode % 3 + 1
	Hud.tip("Caméra : " .. CAM_NAMES[S.camMode], 1.5)
end

local function setCharVisible(visible)
	local c = player.Character
	if not c then return end
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = visible and 0 or 1 end
	end
end

local function updateCamera(dt)
	local ch = S.model and S.model.PrimaryPart
	if not ch then return end
	camera.CameraType = Enum.CameraType.Scriptable
	local cf = ch.CFrame
	local speed = ch.AssemblyLinearVelocity.Magnitude / M
	camera.FieldOfView = 68 + math.clamp(speed / 50, 0, 1) * 12
	if S.camMode == 1 then
		local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		if flatLook.Magnitude < 0.1 then flatLook = Vector3.new(0, 0, -1) end
		flatLook = flatLook.Unit
		local blended = S.camLook and S.camLook:Lerp(flatLook, math.clamp(dt * 4, 0, 1)) or flatLook
		S.camLook = blended.Magnitude > 0.05 and blended.Unit or flatLook
		local target = cf.Position - S.camLook * 7.5 * M + Vector3.new(0, 2.6 * M, 0)
		S.camPos = S.camPos and S.camPos:Lerp(target, math.clamp(dt * 8, 0, 1)) or target
		camera.CFrame = CFrame.lookAt(S.camPos, cf.Position + S.camLook * 3 * M + Vector3.new(0, 0.8 * M, 0))
		setCharVisible(true)
	elseif S.camMode == 2 then
		camera.CFrame = cf * CFrame.new(0, 0.9 * M, -1.0 * M) * CFrame.Angles(math.rad(-3), 0, 0)
		setCharVisible(true)
	else
		local eye = ch:FindFirstChild("Eye")
		local base = eye and eye.WorldCFrame or cf * CFrame.new(0, 1 * M, 0)
		-- regarder autour à la souris (clic droit maintenu)
		if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			local d = UIS:GetMouseDelta()
			S.lookYaw = math.clamp((S.lookYaw or 0) - d.X * 0.004, -2.2, 2.2)
			S.lookPitch = math.clamp((S.lookPitch or 0) - d.Y * 0.004, -0.6, 0.5)
			UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		else
			S.lookYaw = (S.lookYaw or 0) * (1 - math.clamp(dt * 5, 0, 1))
			S.lookPitch = (S.lookPitch or 0) * (1 - math.clamp(dt * 5, 0, 1))
			UIS.MouseBehavior = Enum.MouseBehavior.Default
		end
		camera.CFrame = base * CFrame.Angles(0, S.lookYaw, 0) * CFrame.Angles(S.lookPitch - math.rad(4), 0, 0)
		setCharVisible(false)
	end
	if S.gloveParts then
		for _, g in ipairs(S.gloveParts) do g.LocalTransparencyModifier = (S.camMode == 3) and 0 or 1 end
	end
	if S.dashGui then S.dashGui.Enabled = S.camMode == 3 end
end

---------------------------------------------------------------------------
-- tableau de bord du cockpit et gants
---------------------------------------------------------------------------
local function buildCockpit(model, gloveId)
	local dash = model:FindFirstChild("Dash")
	if dash then
		local sg = Ui.make("SurfaceGui", {Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 60,
			LightInfluence = 0, Parent = dash})
		local bg = Ui.make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 14, 16), Parent = sg})
		local function cell(x, w, big)
			return Ui.make("TextLabel", {Position = UDim2.fromScale(x, 0.05), Size = UDim2.fromScale(w, 0.9), TextScaled = true, Font = big and Enum.Font.GothamBlack or Enum.Font.GothamBold,
				TextColor3 = big and Color3.fromRGB(255, 205, 60) or Color3.fromRGB(150, 230, 160), Parent = bg})
		end
		S.dash = {
			speed = cell(0.02, 0.16, true), gear = cell(0.19, 0.12, true), time = cell(0.32, 0.2),
			temps = cell(0.53, 0.26), hdg = cell(0.8, 0.18),
		}
		S.dashGui = sg
	end
	local wheel = model:FindFirstChild("SteeringWheel")
	if wheel then
		local g = Config.GLOVES[1]
		for _, gl in ipairs(Config.GLOVES) do if gl.id == gloveId then g = gl end end
		S.gloveParts = {}
		for _, sx in ipairs({-1, 1}) do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.13, 0.13, 0.2) * M
			p.Color = Ui.rgb(g.rgb)
			p.Material = Enum.Material.Fabric
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CFrame = wheel.CFrame * CFrame.new(sx * 0.17 * M, 0.05 * M, -0.05 * M)
			local w = Instance.new("WeldConstraint")
			w.Part0 = wheel
			w.Part1 = p
			w.Parent = p
			p.Parent = model
			table.insert(S.gloveParts, p)
		end
	end
end

---------------------------------------------------------------------------
-- démarrage d'une session
---------------------------------------------------------------------------
local Remotes = Shared:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("Request")

local function req(...)
	local ok, res = pcall(Request.InvokeServer, Request, ...)
	if ok then return res end
	return nil
end

local function applyLighting(stage)
	local sky = stage.sky
	Lighting.ClockTime = sky.clock
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		atm.Color = Ui.rgb(sky.fog)
		atm.Decay = Ui.rgb(sky.fog)
	end
	Lighting.OutdoorAmbient = Ui.rgb(sky.ambient)
end

local function makeCoins(T, origin, collected)
	local folder = Instance.new("Folder")
	folder.Name = "Coins"
	folder.Parent = workspace
	local list = {}
	for k, c in ipairs(T.coins) do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.25, 1.3, 1.3) * M
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 200, 40)
		p.Transparency = collected[tostring(k)] and 0.6 or 0
		local pos = origin + Vector3.new(c.x, c.y, c.z) * M
		p.CFrame = CFrame.new(pos)
		p.Parent = folder
		list[k] = {part = p, pos = pos, got = false}
	end
	return folder, list
end

-- opts : stageId, carId, carName, startAt, mode ("driver" | "passenger"), profile, challenge, copilot, onFinish(result, replay)
function Drive.start(opts)
	if S then Drive.stop() end
	local stage = Config.STAGE_BY_ID[opts.stageId]
	local car = Config.CAR_BY_ID[opts.carId]
	local T = Drive.track(opts.stageId)
	local origin = Drive.origin(opts.stageId)
	local carsFolder = workspace:WaitForChild("Rallye"):WaitForChild("Cars")
	local model = carsFolder:WaitForChild(opts.carName, 15)
	if not model or not origin then
		Hud.tip("Impossible de charger la voiture", 3)
		return
	end
	local prof = opts.profile or {}
	local settings = prof.settings or {}

	S = {
		opts = opts, stage = stage, car = car, T = T, origin = origin, model = model, mode = opts.mode or "driver",
		state = "countdown", startAt = opts.startAt, raw = 0, pen = 0, cpIdx = 0, cpTimes = {}, idx = 1, d = 0,
		camMode = settings.camera or 1, sens = settings.sens or 1, hints = settings.hints ~= false,
		damage = 0, mud = 0, crashes = 0, cutCorner = nil, cutT = 0, cuts = 0, airT = 0, flipT = 0,
		lastNote = nil, frames = {}, recT = 0, lastSpeed = 0, hairpins = 0,
		bestSplits = prof.best and prof.best[opts.stageId] and prof.best[opts.stageId].splits or nil,
		wheels = {}, compress = {},
	}
	S.p = Physics.prepare(car, Config.BASE_MU, Config.LONG_MU)
	S.p.L = Cars.shapeOf(car).wb
	S.p.a = S.p.L * car.rear
	S.p.b = S.p.L - S.p.a
	S.p.Iz = S.p.m * S.p.a * S.p.b * 1.05
	S.st = Physics.newState()
	S.st.manual = settings.manual == true

	applyLighting(stage)
	Hud.show(true)
	Hud.buildMap(T)
	Hud.setCP("PP 0/" .. #T.cps)
	Hud.setCall(nil)
	Hud.setCracks(0, false)
	Hud.setMud(0, false)
	Hud.setCopilot(opts.copilot and ("Copilote : " .. opts.copilot) or "")
	if S.mode == "passenger" then
		Hud.setHelp("Tu es copilote ! 1 = Serré · 2 = À fond · 3 = Freine · 4 = Bien joué — annonce les virages à ton chauffeur")
	else
		Hud.setHelp("Z/W gaz · S frein/arrière · Q/A D direction · Espace frein à main · R dernier PP · Retour arrière (maintenir) recommencer · C caméra · M boîte manuelle")
	end
	Hud.updatePlayers()

	-- roues et suspension
	for _, w in ipairs(Cars.wheelMounts(model)) do
		local wp = model:FindFirstChild("Wheel" .. w.name)
		local joint = wp and wp:FindFirstChild("Joint" .. w.name)
		table.insert(S.wheels, {name = w.name, pos = w.pos, front = w.front, part = wp, joint = joint, base = joint and joint.C0, x = 0, spin = 0, grounded = false})
	end
	S.rad = model:GetAttribute("WheelRadius") or 1
	local freq = car.freq or 1.4
	S.k = (2 * math.pi * freq) ^ 2
	S.c = 2 * 0.55 * math.sqrt(S.k)
	S.sag = workspace.Gravity / S.k
	S.travel = car.travel * M
	S.restLen = 2 * S.rad + S.sag
	S.rayLen = S.restLen + 0.35 * M + S.travel * 0.5

	S.ray = RaycastParams.new()
	S.ray.FilterType = Enum.RaycastFilterType.Exclude
	S.ray.IgnoreWater = true
	S.ray.FilterDescendantsInstances = {carsFolder, workspace:FindFirstChild("Coins") or carsFolder}
	S.charFilterT = 0

	if S.mode == "driver" then
		buildCockpit(model, prof.gloves)
		local coinFolder, coins = makeCoins(T, origin, (prof.coins and prof.coins[opts.stageId]) or {})
		S.coinFolder, S.coins = coinFolder, coins
		setControls(false)
		local h = hum()
		if h then
			h:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
		bindAll()
		-- fantôme du meilleur passage de la session
		local gk = opts.stageId .. "/" .. opts.carId
		if settings.ghost ~= false and ghosts[gk] then
			local g = Cars.build(car, nil, {anchored = true, ghost = true})
			g.Name = "Fantome"
			g.Parent = workspace
			S.ghost = {model = g, frames = ghosts[gk].frames}
		end
	else
		S.camMode = 1
		bindAll()
	end

	-- feux de départ (locaux)
	local _, folder = Drive.origin(opts.stageId)
	S.gantry = folder and folder:FindFirstChild("StartGantry")

	S.conn = RunService.Heartbeat:Connect(function(dt) Drive.step(math.min(dt, 1 / 20)) end)
	S.camConn = RunService:BindToRenderStep("RallyeCam", Enum.RenderPriority.Camera.Value + 1, function(dt) if S then updateCamera(dt) end end)
end

function Drive.stop()
	if not S then return end
	if S.conn then S.conn:Disconnect() end
	pcall(function() RunService:UnbindFromRenderStep("RallyeCam") end)
	unbindAll()
	if S.coinFolder then S.coinFolder:Destroy() end
	if S.ghost then S.ghost.model:Destroy() end
	if S.touchGui then S.touchGui:Destroy() end
	if S.gloveParts then for _, g in ipairs(S.gloveParts) do g:Destroy() end end
	if S.dashGui then S.dashGui:Destroy() end
	S = nil
	Hud.show(false)
	setControls(true)
	setCharVisible(true)
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	local h = hum()
	if h then h:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local c = player.Character
	if c then camera.CameraSubject = c:FindFirstChildOfClass("Humanoid") end
end

function Drive.active() return S ~= nil end
function Drive.session() return S end

function Drive.sendCallout(text)
	if S and S.mode == "passenger" then
		task.spawn(req, "callout", text)
		Hud.callout("Tu annonces : " .. text)
	end
end

function Drive.onCallout(from, text)
	if S then Hud.callout(from .. " : " .. text) end
end

function Drive.setCopilot(name)
	Hud.setCopilot("Copilote : " .. name)
end

---------------------------------------------------------------------------
-- récupération (R) : dernier point de passage
---------------------------------------------------------------------------
function Drive.recover(manual)
	if not S or S.mode ~= "driver" or S.state == "finished" then return end
	if S.state == "countdown" then return end
	local T = S.T
	local idx = (S.cpIdx > 0) and T.cps[S.cpIdx] or Track.indexAtD(T, Config.SPAWN_D)
	local s = T.S[idx]
	local pos = S.origin + Vector3.new(s.x * M, (s.y + 1.4) * M, s.z * M)
	local fwd = Vector3.new(math.sin(s.h), 0, math.cos(s.h))
	S.model:PivotTo(CFrame.lookAt(pos, pos + fwd))
	local ch = S.model.PrimaryPart
	ch.AssemblyLinearVelocity = Vector3.zero
	ch.AssemblyAngularVelocity = Vector3.zero
	S.st.vF, S.st.vL, S.st.r = 0, 0, 0
	S.idx = idx
	if S.state == "running" then
		S.pen = S.pen + Config.RECOVER_PENALTY
		Hud.penalty(string.format("Récupération +%d s", Config.RECOVER_PENALTY))
	end
	S.flipT = 0
end

---------------------------------------------------------------------------
-- boucle physique
---------------------------------------------------------------------------
local function surfaceOf(material)
	return Config.SURFACES[material.Name] or Config.DEFAULT_SURFACE
end

local function driverInputs()
	local steer = input.left - input.right
	if input.stickX then steer = -input.stickX end
	local inp = {throttle = input.gas, brake = input.brake, steer = steer, hb = input.hb, shift = input.shift, sens = S.sens}
	input.shift = 0
	if S.state ~= "running" then
		inp.throttle, inp.brake, inp.hb = 0, 1, true
		if S.state == "countdown" then inp.steer = 0 end
	end
	return inp
end

function Drive.step(dt)
	if not S then return end
	local model = S.model
	local ch = model and model.PrimaryPart
	if not ch or not model.Parent then
		Drive.stop()
		return
	end
	local T = S.T
	local now = workspace:GetServerTimeNow()

	-- compte à rebours et feux
	if S.state == "countdown" then
		local left = S.startAt - now
		local n = math.ceil(left)
		if n ~= S.lastCount then
			S.lastCount = n
			if n >= 1 and n <= 3 then Hud.big(tostring(n), Ui.C.text) end
			if S.gantry then
				for k = 1, 3 do
					local l = S.gantry:FindFirstChild("Light" .. k)
					if l then l.Color = (k <= 4 - n and n <= 3) and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(60, 0, 0) end
				end
			end
		end
		if left <= 0 then
			S.state = "running"
			S.goTime = now
			Hud.big("ALLEZ !", Ui.C.green, 1)
			if S.gantry then
				for k = 1, 3 do
					local l = S.gantry:FindFirstChild("Light" .. k)
					if l then l.Color = Color3.fromRGB(40, 255, 80) end
				end
			end
		end
	end

	local cf = ch.CFrame
	local up = cf.UpVector
	local mass = ch.AssemblyMass

	-- position sur le tracé
	local px = (cf.Position.X - S.origin.X) / M
	local pz = (cf.Position.Z - S.origin.Z) / M
	local idx, lat, smp = Track.nearest(T, px, pz, S.idx)
	S.idx, S.lat = idx, lat
	S.d = smp.d

	if S.mode == "driver" then
		-- filtre des rayons : voitures et personnages
		S.charFilterT = S.charFilterT - dt
		if S.charFilterT <= 0 then
			S.charFilterT = 1
			local list = {workspace.Rallye.Cars}
			if S.coinFolder then table.insert(list, S.coinFolder) end
			if S.ghost then table.insert(list, S.ghost.model) end
			for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list, p.Character) end end
			S.ray.FilterDescendantsInstances = list
		end

		-- suspension par rayons
		local grounded = 0
		local nSum = Vector3.zero
		local gF, gR, nF, nR, drag, mudHit = 0, 0, 0, 0, 0, false
		local surfName = nil
		for _, w in ipairs(S.wheels) do
			local origin = cf:PointToWorldSpace(w.pos)
			local res = workspace:Raycast(origin, -up * S.rayLen, S.ray)
			local x = 0
			if res and res.Distance < S.restLen + S.travel * 0.5 then
				x = S.restLen - res.Distance
				local xdot = (x - w.x) / dt
				local f = (S.k * x + S.c * xdot) * mass / 4
				if x > S.sag + S.travel then f = f + (x - S.sag - S.travel) * S.k * 6 * mass / 4 end
				f = math.max(0, f)
				ch:ApplyImpulseAtPosition(up * f * dt, origin)
				w.grounded = true
				grounded = grounded + 1
				nSum = nSum + res.Normal
				local sf = surfaceOf(res.Material)
				if w.front then gF = gF + sf.grip; nF = nF + 1 else gR = gR + sf.grip; nR = nR + 1 end
				local dg = sf.drag
				if sf.sand and S.car.sand then dg = dg * 0.4 end
				drag = drag + dg
				if sf.mud then mudHit = true end
				w.surf = sf
				surfName = surfName or sf.name
				w.dist = res.Distance
			else
				w.grounded = false
				w.dist = S.restLen + S.travel * 0.4
			end
			w.x = x
		end

		local inp = driverInputs()
		local st = S.st
		local p = S.p
		if grounded >= 2 then
			if S.airT > 0.45 and S.car.nervous then
				st.r = st.r + (math.random() - 0.5) * 1.4
				Hud.tip("La voiture est nerveuse sur les crêtes !", 1.5)
			end
			S.airT = 0
			local n = (nSum / grounded).Unit
			local fwd = cf.LookVector - n * cf.LookVector:Dot(n)
			if fwd.Magnitude < 0.05 then fwd = cf.LookVector end
			fwd = fwd.Unit
			local left = n:Cross(fwd)
			local v = ch.AssemblyLinearVelocity
			local w = ch.AssemblyAngularVelocity
			st.vF = v:Dot(fwd) / M
			st.vL = v:Dot(left) / M
			st.r = w:Dot(n)
			local vN = v:Dot(n)
			if smp.feat == "gue" then drag = drag + 2.5 * grounded; mudHit = true end
			local surf = {
				gF = nF > 0 and gF / nF or (nR > 0 and gR / nR or 0.7),
				gR = nR > 0 and gR / nR or (nF > 0 and gF / nF or 0.7),
				drag = drag / grounded,
			}
			local sub = 4
			for _ = 1, sub do Physics.step(p, st, inp, surf, dt / sub) end
			if S.state == "countdown" then st.vF, st.vL, st.r = 0, 0, 0 end
			ch.AssemblyLinearVelocity = fwd * st.vF * M + left * st.vL * M + n * vN
			local wPerp = w - n * w:Dot(n)
			ch.AssemblyAngularVelocity = wPerp * 0.96 + n * st.r
			S.surfName = surfName
			S.mudHit = mudHit
		else
			S.airT = S.airT + dt
			Physics.air(p, st, inp, dt)
			-- se redresse doucement en l'air
			local wv = ch.AssemblyAngularVelocity
			local fix = up:Cross(Vector3.yAxis) * 2.2 * dt
			ch.AssemblyAngularVelocity = wv * 0.995 + fix
			local v = ch.AssemblyLinearVelocity
			st.vF = v:Dot(cf.LookVector) / M
		end

		-- roues : suspension, braquage, rotation
		for _, w in ipairs(S.wheels) do
			if w.joint and w.base then
				local yoff = (2 * S.rad) - (w.dist or S.restLen)
				w.spin = (w.spin + st.vF * M / S.rad * dt) % (math.pi * 2)
				local steerA = w.front and st.steer or 0
				w.joint.C0 = CFrame.new(w.base.Position + Vector3.new(0, yoff, 0)) * CFrame.Angles(0, steerA, 0) * CFrame.Angles(-w.spin, 0, 0)
			end
		end

		-- poussière et projections
		local spd = math.abs(st.vF)
		for _, nm in ipairs({"DustRL", "DustRR"}) do
			local at = ch:FindFirstChild(nm)
			if at then
				local pe = at:FindFirstChild("Dust")
				local chunks = at:FindFirstChild("Chunks")
				local wsurf = nil
				for _, w in ipairs(S.wheels) do if ("Dust" .. w.name) == nm then wsurf = w.grounded and w.surf end end
				if pe then
					if wsurf and wsurf.dust and spd > 3 then
						pe.Color = ColorSequence.new(Color3.fromRGB(wsurf.dust[1], wsurf.dust[2], wsurf.dust[3]))
						pe.Rate = math.clamp(spd * 1.5 + math.abs(st.slipR) * 60, 0, 90)
					else
						pe.Rate = 0
					end
				end
				if chunks then
					if wsurf and (wsurf.mud or S.mudHit) and spd > 4 then
						chunks.Color = ColorSequence.new(Color3.fromRGB(80, 56, 34))
						chunks.Rate = math.clamp(spd * 2, 0, 60)
					else
						chunks.Rate = 0
					end
				end
			end
		end
		if S.mudHit and spd > 5 then S.mud = math.min(1, S.mud + dt * 0.25) else S.mud = math.max(0, S.mud - dt * 0.03) end

		-- chocs
		local speedNow = ch.AssemblyLinearVelocity.Magnitude / M
		local drop = S.lastSpeed - speedNow
		if drop > 6 and S.state == "running" then
			S.crashes = S.crashes + 1
			S.damage = math.min(1, S.damage + drop / 35)
			Hud.flash()
			local wsg = model:FindFirstChild("Windshield")
			if wsg then wsg.Transparency = math.min(0.6, wsg.Transparency + 0.1) ; wsg.Color = wsg.Color:Lerp(Color3.fromRGB(240, 240, 240), 0.3) end
		end
		S.lastSpeed = speedNow

		-- retourné ou trop loin : récupération automatique
		if up.Y < 0.25 then S.flipT = S.flipT + dt else S.flipT = 0 end
		if S.flipT > 2.5 or math.abs(lat) > 45 or cf.Position.Y < S.origin.Y + (smp.y - 25) * M then
			Hud.tip("Récupération automatique", 2)
			Drive.recover(false)
		end

		-- pièces
		if S.coins then
			for k, c in ipairs(S.coins) do
				if not c.got and (c.pos - cf.Position).Magnitude < 3 * M then
					c.got = true
					c.part.Transparency = 1
				end
				if not c.got then c.part.CFrame = CFrame.new(c.pos) * CFrame.Angles(0, os.clock() * 3 + k, 0) end
			end
		end

		-- redémarrage (maintenir Retour arrière)
		if S.restartHold and os.clock() - S.restartHold > 1 then
			S.restartHold = nil
			Hud.big("Redémarrage…", Ui.C.text, 1)
			task.spawn(function() req("startStage", S.opts.stageId, S.opts.carId) end)
		end
	end

	-- chrono, points de passage, arrivée
	if S.state == "running" then
		if not S.crossed and S.d >= T.startD then
			S.crossed = true
			S.t0 = now
		end
		if S.crossed then S.raw = now - S.t0 end
		if S.mode == "driver" then
			-- points de passage
			local nextCp = T.cps[S.cpIdx + 1]
			if nextCp and S.idx >= nextCp and S.crossed then
				S.cpIdx = S.cpIdx + 1
				local t = S.raw + S.pen
				S.cpTimes[S.cpIdx] = t
				task.spawn(req, "checkpoint", S.cpIdx, t)
				local best = S.bestSplits and S.bestSplits[S.cpIdx]
				if best then
					local dlt = t - best
					Hud.setCP(Ui.fmtDelta(dlt) .. "  PP " .. S.cpIdx .. "/" .. #T.cps, dlt < 0 and Ui.C.green or Ui.C.red)
				else
					Hud.setCP("PP " .. S.cpIdx .. "/" .. #T.cps)
				end
			end
			-- coupe de virage : loin à l'intérieur d'un virage serré
			local c = smp.corner and T.corners[smp.corner]
			if c and (c.grade <= 3 or c.hairpin) and math.abs(lat) > HALF + 2.5 and (lat > 0) == (c.dir == 1) then
				S.cutT = S.cutT + dt
				if S.cutT > 0.3 and S.cutCorner ~= c.id then
					S.cutCorner = c.id
					local p = (math.abs(lat) > HALF + 7) and 2.5 or 1.5
					S.pen = S.pen + p
					S.cuts = S.cuts + 1
					Hud.penalty(string.format("Coupe de virage : +%.1f s", p):gsub("%.", ","))
				end
			else
				S.cutT = 0
			end
			-- arrivée
			if S.d >= T.finishD and S.cpIdx >= #T.cps then
				Drive.finish()
			end
		end
	end

	-- copilote
	local spdNow = (ch.AssemblyLinearVelocity.Magnitude) / M
	local ahead = math.max(70, spdNow * 3.4)
	local note = Track.noteAt(T, S.d, ahead)
	if note then Hud.setCall(note, math.max(0, note.d - S.d)) else Hud.setCall({kind = "flat", text = "À fond", dir = 0, label = ""}) end
	if note and note ~= S.lastNote then
		S.lastNote = note
		if note.hairpin then S.hairpins = S.hairpins + 1 end
		if S.hints and note.tip then Hud.tip(note.tip, 4) end
	end

	-- affichage
	Hud.setTimer(S.raw + S.pen)
	Hud.setProgress((S.d - T.startD) / T.stageLength)
	local st = S.st
	local boost, boostTxt = nil, nil
	if S.car.turbo then boost = S.car.turbo.lag2 and (st.boost * 0.55 + st.boost2 * 0.45) or st.boost; boostTxt = "Turbo" end
	if S.car.hybrid then boost = st.battery; boostTxt = st.hybridOn and "Hybride : BOOST +134 ch" or "Batterie hybride" end
	local km = math.max(0, S.d - T.startD) / 1000
	if S.mode == "driver" then
		Hud.setDash(math.abs(st.vF) * 3.6, Physics.gearLabel(st), st.rpm, S.surfName or "", km, S.car.name, boost, boostTxt)
	else
		Hud.setDash(spdNow * 3.6, "-", 0, "", km, S.car.name)
	end
	local h = math.atan2(cf.LookVector.X, cf.LookVector.Z)
	Hud.updateMap(px, pz, h)
	local inside = S.camMode >= 2
	Hud.setCracks(S.damage, inside)
	Hud.setMud(S.mud, S.camMode == 3)
	if S.dash then
		S.dash.speed.Text = tostring(math.floor(math.abs(st.vF) * 3.6))
		S.dash.gear.Text = Physics.gearLabel(st)
		S.dash.time.Text = Ui.fmt(S.raw + S.pen)
		S.dash.temps.Text = string.format("H%d E%d B%d  %d%%", st.temps.oil, st.temps.water, st.temps.box, math.floor(st.fuel * 100))
		S.dash.hdg.Text = string.format("HDG %03d", math.floor(math.deg(h) % 360))
	end

	-- fantôme
	if S.ghost and S.crossed and S.state == "running" then
		local fr = S.ghost.frames
		local t = S.raw
		local i = S.ghostI or 1
		while fr[i + 1] and fr[i + 1].t <= t do i = i + 1 end
		S.ghostI = i
		local a = fr[i]
		local b = fr[i + 1] or a
		if a then
			local u = (b.t > a.t) and math.clamp((t - a.t) / (b.t - a.t), 0, 1) or 0
			S.ghost.model:PivotTo(a.cf:Lerp(b.cf, u))
		end
	end

	-- enregistrement du replay (20 images/s)
	S.recT = S.recT + dt
	if S.recT >= 0.05 and S.state ~= "finished" then
		S.recT = 0
		table.insert(S.frames, {t = S.crossed and S.raw or -(S.startAt - now), cf = cf, v = spdNow})
	end
end

---------------------------------------------------------------------------
-- arrivée
---------------------------------------------------------------------------
function Drive.finish()
	if S.state == "finished" then return end
	S.state = "finished"
	local total = S.raw + S.pen
	Hud.big("ARRIVÉE", Ui.C.acc)
	local coins = {}
	if S.coins then
		for k, c in ipairs(S.coins) do if c.got then coins[#coins + 1] = k end end
	end
	local session = S
	local frames = S.frames
	task.spawn(function()
		local result = req("finish", {raw = session.raw, pen = session.pen, coins = coins, crashes = session.crashes, cuts = session.cuts})
		-- fantôme : meilleur passage de la session
		local gk = session.opts.stageId .. "/" .. session.opts.carId
		if not ghosts[gk] or total < ghosts[gk].t then ghosts[gk] = {t = total, frames = frames} end
		task.wait(1.2)
		if session.opts.onFinish then session.opts.onFinish(result, {frames = frames, car = session.car, stageId = session.opts.stageId, T = session.T, origin = session.origin}) end
	end)
end

return Drive

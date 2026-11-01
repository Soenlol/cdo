-- Interface de course : chrono, points de passage, copilote, compteur, mini-carte, dégâts

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Ui = require(script.Parent.Ui)
local make, C = Ui.make, Ui.C

local Hud = {}
local gui, el = nil, {}

local function txt(props)
	local l = make("TextLabel", props)
	l.TextStrokeTransparency = 0.6
	return l
end

function Hud.create(playerGui)
	if gui then gui:Destroy() end
	gui = make("ScreenGui", {Name = "RallyeHud", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5, Enabled = false, Parent = playerGui})
	el = {}

	-- surcouches : boue, fissures, flash rouge
	el.mud = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui})
	el.cracks = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui})
	el.flash = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.red, BackgroundTransparency = 1, Parent = gui})

	-- chrono (haut centre)
	local top = make("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(300, 92), BackgroundTransparency = 1, Parent = gui})
	el.cp = txt({Size = UDim2.new(1, 0, 0, 20), Text = "", Font = Enum.Font.GothamBold, TextSize = 18, Parent = top})
	el.timer = txt({Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 44), Text = "0:00.0", Font = Enum.Font.GothamBlack, TextSize = 42, Parent = top})
	local _, fill = Ui.bar(top, {Position = UDim2.fromOffset(40, 66), Size = UDim2.new(1, -80, 0, 6)}, 0, C.acc)
	el.progress = fill

	-- annonce du copilote
	el.call = make("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(330, 70),
		BackgroundColor3 = Color3.fromRGB(12, 16, 22), BackgroundTransparency = 0.2, Parent = gui})
	Ui.corner(el.call, 14)
	el.callStroke = Ui.stroke(el.call, C.red, 0)
	el.callStroke = el.call:FindFirstChildOfClass("UIStroke")
	el.arrow = txt({Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(64, 70), Text = "↑", Font = Enum.Font.GothamBlack, TextSize = 46, Parent = el.call})
	el.callText = txt({Position = UDim2.fromOffset(76, 8), Size = UDim2.new(1, -86, 0, 30), Text = "", Font = Enum.Font.GothamBlack, TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = el.call})
	el.callSub = txt({Position = UDim2.fromOffset(76, 40), Size = UDim2.new(1, -86, 0, 22), Text = "", Font = Enum.Font.GothamBold, TextSize = 16,
		TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = el.call})
	el.callTag = txt({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(110, 22), Text = "", Font = Enum.Font.GothamBlack,
		TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, Parent = el.call})

	-- message central / pénalités / appels du copilote humain
	el.big = txt({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(600, 110), Text = "",
		Font = Enum.Font.GothamBlack, TextSize = 90, Parent = gui})
	el.pen = txt({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 186), Size = UDim2.fromOffset(500, 30), Text = "",
		Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = C.red, Parent = gui})
	el.callout = txt({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 220), Size = UDim2.fromOffset(500, 30), Text = "",
		Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = Color3.fromRGB(110, 220, 255), Parent = gui})

	-- conseils (bas gauche) + mini-carte
	el.tip = make("TextLabel", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -200), Size = UDim2.fromOffset(330, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(12, 16, 22), BackgroundTransparency = 0.2, Text = "", TextWrapped = true, Font = Enum.Font.GothamBold, TextSize = 16,
		TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Parent = gui})
	Ui.corner(el.tip, 10)
	Ui.pad(el.tip, 10)
	el.map = make("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.fromOffset(176, 176),
		BackgroundColor3 = Color3.fromRGB(12, 16, 22), BackgroundTransparency = 0.25, ClipsDescendants = true, Parent = gui})
	Ui.corner(el.map, 88)
	el.mapInner = make("Frame", {Size = UDim2.fromOffset(176, 176), BackgroundTransparency = 1, Parent = el.map})
	el.mapDot = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.acc, ZIndex = 3, Parent = el.map})
	Ui.corner(el.mapDot, 5)
	el.hdg = txt({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(100, 18), Text = "HDG 000", Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 4, Parent = el.map})

	-- compteur (bas droite)
	local dash = make("Frame", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(250, 170),
		BackgroundColor3 = Color3.fromRGB(12, 16, 22), BackgroundTransparency = 0.2, Parent = gui})
	Ui.corner(dash, 14)
	el.speed = txt({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -70, 0, 60), Text = "0", Font = Enum.Font.GothamBlack, TextSize = 56, TextXAlignment = Enum.TextXAlignment.Right, Parent = dash})
	txt({Position = UDim2.new(1, -60, 0, 36), Size = UDim2.fromOffset(50, 20), Text = "km/h", TextColor3 = C.dim, TextSize = 14, Parent = dash})
	el.gear = txt({Position = UDim2.new(1, -60, 0, 4), Size = UDim2.fromOffset(50, 34), Text = "N", Font = Enum.Font.GothamBlack, TextSize = 30, TextColor3 = C.acc, Parent = dash})
	local _, rpm = Ui.bar(dash, {Position = UDim2.fromOffset(12, 70), Size = UDim2.new(1, -24, 0, 8)}, 0, C.green)
	el.rpm = rpm
	local boostBack, boost = Ui.bar(dash, {Position = UDim2.fromOffset(12, 84), Size = UDim2.new(1, -24, 0, 5)}, 0, C.blue)
	el.boost, el.boostBack = boost, boostBack
	el.boostLabel = txt({Position = UDim2.fromOffset(12, 90), Size = UDim2.new(1, -24, 0, 16), Text = "", TextSize = 12, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = dash})
	el.surface = txt({Position = UDim2.fromOffset(12, 106), Size = UDim2.new(1, -24, 0, 18), Text = "", Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = dash})
	el.km = txt({Position = UDim2.fromOffset(12, 126), Size = UDim2.new(1, -24, 0, 18), Text = "KM 0.0", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = dash})
	el.carName = txt({Position = UDim2.fromOffset(12, 146), Size = UDim2.new(1, -24, 0, 18), Text = "", TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = dash})

	-- joueurs (haut droite)
	el.players = make("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 60), Size = UDim2.fromOffset(220, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(12, 16, 22), BackgroundTransparency = 0.3, Parent = gui})
	Ui.corner(el.players, 10)
	Ui.pad(el.players, 8)
	Ui.list(el.players, 2)

	-- aide commandes + copilote
	el.help = txt({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(760, 40), TextWrapped = true,
		Text = "", TextSize = 14, TextColor3 = C.dim, Parent = gui})
	el.copilot = txt({Position = UDim2.fromOffset(14, 60), Size = UDim2.fromOffset(300, 20), Text = "", TextSize = 15, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = gui})
	return gui
end

function Hud.gui() return gui end

function Hud.show(on)
	if gui then gui.Enabled = on end
end

function Hud.setTimer(t, raw)
	el.timer.Text = Ui.fmt(t)
end

function Hud.setCP(text, color)
	el.cp.Text = text or ""
	el.cp.TextColor3 = color or C.text
end

function Hud.setProgress(f)
	el.progress.Size = UDim2.fromScale(math.clamp(f, 0, 1), 1)
end

local ARROWS = {[1] = "←", [-1] = "→", [0] = "↑"}
function Hud.setCall(note, dist)
	if not note then
		el.call.Visible = false
		return
	end
	el.call.Visible = true
	local arrow = ARROWS[note.dir or 0] or "!"
	if note.hairpin then arrow = note.dir == 1 and "↶" or "↷" end
	if note.kind == "hazard" then arrow = "⚠" end
	el.arrow.Text = arrow
	el.callText.Text = note.text
	local sub = ""
	if note.puis then sub = "puis " .. note.puis end
	if dist and dist > 5 then sub = (sub ~= "" and (sub .. " · ") or "") .. math.floor(dist / 10 + 0.5) * 10 .. " m" end
	el.callSub.Text = sub
	el.callTag.Text = note.label or ""
	local red = note.tight or note.danger
	el.arrow.TextColor3 = red and C.red or C.text
	el.callTag.TextColor3 = (note.label == "LÉGER") and C.green or C.red
	el.callStroke.Thickness = red and 3 or 0
end

local tipToken = 0
function Hud.tip(text, dur)
	tipToken = tipToken + 1
	local my = tipToken
	el.tip.Text = text
	el.tip.Visible = true
	task.delay(dur or 4, function()
		if tipToken == my then el.tip.Visible = false end
	end)
end

local bigToken = 0
function Hud.big(text, color, dur)
	bigToken = bigToken + 1
	local my = bigToken
	el.big.Text = text
	el.big.TextColor3 = color or C.text
	if dur then
		task.delay(dur, function() if bigToken == my then el.big.Text = "" end end)
	end
end

local penToken = 0
function Hud.penalty(text)
	penToken = penToken + 1
	local my = penToken
	el.pen.Text = text
	task.delay(2.5, function() if penToken == my then el.pen.Text = "" end end)
end

local coToken = 0
function Hud.callout(text)
	coToken = coToken + 1
	local my = coToken
	el.callout.Text = text
	task.delay(2.5, function() if coToken == my then el.callout.Text = "" end end)
end

function Hud.setDash(kmh, gear, rpm, surface, km, carName, boost, boostText)
	el.speed.Text = tostring(math.floor(kmh + 0.5))
	el.gear.Text = gear
	el.rpm.Size = UDim2.fromScale(math.clamp(rpm, 0, 1), 1)
	el.rpm.BackgroundColor3 = rpm > 0.95 and C.red or C.green
	el.surface.Text = surface or ""
	el.km.Text = string.format("KM %.2f", km)
	el.carName.Text = carName or ""
	el.boostBack.Visible = boost ~= nil
	el.boostLabel.Text = boostText or ""
	if boost then el.boost.Size = UDim2.fromScale(math.clamp(boost, 0, 1), 1) end
end

function Hud.setHelp(text) el.help.Text = text or "" end
function Hud.setCopilot(text) el.copilot.Text = text or "" end

function Hud.flash()
	el.flash.BackgroundTransparency = 0.45
	TweenService:Create(el.flash, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
end

-- fissures du pare-brise (lignes tournées)
function Hud.setCracks(level, visible)
	el.cracks.Visible = visible
	local want = math.floor(level * 14)
	local have = #el.cracks:GetChildren()
	local rnd = Random.new(have + 7)
	while have < want do
		have = have + 1
		local cx, cy = rnd:NextNumber(0.2, 0.8), rnd:NextNumber(0.1, 0.5)
		for k = 1, 5 do
			make("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(cx, cy), Size = UDim2.fromOffset(rnd:NextInteger(40, 160), 2),
				Rotation = k * 72 + rnd:NextNumber(-20, 20), BackgroundColor3 = Color3.fromRGB(235, 245, 255), BackgroundTransparency = 0.25, Parent = el.cracks})
		end
	end
	if want == 0 then
		for _, ch in ipairs(el.cracks:GetChildren()) do ch:Destroy() end
	end
end

-- boue sur le pare-brise
function Hud.setMud(level, visible)
	el.mud.Visible = visible
	local want = math.floor(level * 26)
	local list = el.mud:GetChildren()
	local rnd = Random.new(#list + 3)
	while #list < want do
		local s = rnd:NextInteger(30, 110)
		local f = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(rnd:NextNumber(0.05, 0.95), rnd:NextNumber(0.05, 0.6)), Size = UDim2.fromOffset(s, s * 0.7),
			BackgroundColor3 = Color3.fromRGB(70, 50, 30), BackgroundTransparency = 0.25, Parent = el.mud})
		Ui.corner(f, s)
		list = el.mud:GetChildren()
	end
	while #list > want do
		list[#list]:Destroy()
		list = el.mud:GetChildren()
	end
end

-- mini-carte : tracé centré sur la voiture, tourné selon le cap
local mapPts = nil
function Hud.buildMap(T)
	Ui.clear(el.mapInner)
	mapPts = {}
	local S = T.S
	for i = 1, #S, 6 do
		local f = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = Color3.fromRGB(230, 230, 230), Parent = el.mapInner})
		mapPts[#mapPts + 1] = {f = f, x = S[i].x, z = S[i].z}
	end
	local fi = S[T.finishIdx]
	local fin = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = C.green, ZIndex = 2, Parent = el.mapInner})
	mapPts[#mapPts + 1] = {f = fin, x = fi.x, z = fi.z}
end

function Hud.updateMap(x, z, heading)
	if not mapPts then return end
	local scale = 0.35
	local c, s = math.cos(heading), math.sin(heading)
	for _, p in ipairs(mapPts) do
		local dx, dz = p.x - x, p.z - z
		-- rotation : l'avant de la voiture vers le haut de la carte
		local rx = dx * c - dz * s
		local ry = dx * s + dz * c
		local px, py = 88 - rx * scale, 88 - ry * scale
		local vis = px > -10 and px < 186 and py > -10 and py < 186
		p.f.Visible = vis
		if vis then p.f.Position = UDim2.fromOffset(px, py) end
	end
	local deg = (math.deg(heading) % 360)
	el.hdg.Text = string.format("HDG %03d", math.floor(deg))
end

function Hud.updatePlayers()
	if not el.players then return end
	Ui.clear(el.players)
	make("TextLabel", {Size = UDim2.new(1, 0, 0, 18), Text = "JOUEURS", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = C.acc,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = el.players})
	for _, p in ipairs(Players:GetPlayers()) do
		local stage = p:GetAttribute("StageName")
		local lvl = p:GetAttribute("Level") or 1
		make("TextLabel", {Size = UDim2.new(1, 0, 0, 18), Text = string.format("%s  · Niv %d · %s", p.DisplayName, lvl, stage or "Parc"),
			TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = el.players})
	end
end

return Hud

-- Menus : accueil, étapes, garage, boutique, contrats, défis, conduite partagée, paramètres, résultats

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Rallye")
local Config = require(Shared.Config)
local Track = require(Shared.Track)
local Ui = require(script.Parent.Ui)
local make, C = Ui.make, Ui.C

local Menus = {}
local App -- fourni par le script principal
local gui, top, win, winTitle, body, toastBox, inviteBox
local player = Players.LocalPlayer
local trackInfo = {}

local function info(stageId)
	if not trackInfo[stageId] then
		local T = Track.generate(Config.STAGE_BY_ID[stageId])
		local ymin, ymax = math.huge, -math.huge
		local surfs, seen = {}, {}
		for _, s in ipairs(T.S) do
			ymin = math.min(ymin, s.y); ymax = math.max(ymax, s.y)
			local n = (Config.SURFACES[s.surf] or Config.DEFAULT_SURFACE).name
			if not seen[n] then seen[n] = true; surfs[#surfs + 1] = n end
		end
		for _, f in ipairs(T.features) do
			local h = Track.HAZARDS[f.kind]
			if h and not seen[h.text] and (f.kind == "gue" or f.kind == "pont" or f.kind == "pontCouvert" or f.kind == "saut" or f.kind == "tunnel") then
				seen[h.text] = true
				surfs[#surfs + 1] = h.text
			end
		end
		trackInfo[stageId] = {T = T, km = T.stageLength / 1000, climb = ymax - ymin, surfaces = table.concat(surfs, ", ")}
	end
	return trackInfo[stageId]
end

---------------------------------------------------------------------------
-- structure
---------------------------------------------------------------------------
function Menus.init(app)
	App = app
	local pg = player:WaitForChild("PlayerGui")
	gui = make("ScreenGui", {Name = "RallyeMenus", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg})

	-- barre du haut (parc)
	top = make("Frame", {Position = UDim2.fromOffset(12, 50), Size = UDim2.fromOffset(520, 44), BackgroundTransparency = 1, Parent = gui})
	Ui.list(top, 8, true)
	Ui.button("☰  MENU", {Size = UDim2.fromOffset(120, 40)}, function() Menus.open("main") end).Parent = top
	Menus.topInfo = make("TextLabel", {Size = UDim2.fromOffset(380, 40), BackgroundColor3 = C.panel, BackgroundTransparency = 0.15, Text = "",
		Font = Enum.Font.GothamBold, TextSize = 16, Parent = top})
	Ui.corner(Menus.topInfo, 10)

	-- fenêtre
	win = Ui.panel({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0.94, 0, 0.84, 0), Visible = false, Parent = gui})
	make("UISizeConstraint", {MaxSize = Vector2.new(960, 640), Parent = win})
	winTitle = make("TextLabel", {Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -140, 0, 40), Text = "", Font = Enum.Font.GothamBlack, TextSize = 28,
		TextColor3 = C.acc, TextXAlignment = Enum.TextXAlignment.Left, Parent = win})
	local close = Ui.button("✕", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(40, 36)}, function() Menus.close() end, "secondary")
	close.Parent = win
	Menus.backBtn = Ui.button("◀ Retour", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 12), Size = UDim2.fromOffset(100, 36)}, function() Menus.open("main") end, "secondary")
	Menus.backBtn.Parent = win
	body = make("ScrollingFrame", {Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -32, 1, -72), BackgroundTransparency = 1, ScrollBarThickness = 6,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win})

	toastBox = make("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(460, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, ZIndex = 30, Parent = gui})
	Ui.list(toastBox, 6, false, Enum.HorizontalAlignment.Center)
	Menus.refreshTop()
end

function Menus.showTop(on) top.Visible = on end

function Menus.refreshTop()
	local p = App.profile
	if not p or not Menus.topInfo then return end
	local lvl = math.floor(p.exp / Config.LEVEL_EXP) + 1
	local building = Shared:GetAttribute("Building")
	local extra = building and ("  ·  construction : " .. math.floor((Shared:GetAttribute("BuildProgress") or 0) * 100) .. " %") or ""
	Menus.topInfo.Text = string.format("  %s CR   ·   Niveau %d   ·   %d EXP%s", Ui.num(p.cr), lvl, p.exp % Config.LEVEL_EXP, extra)
end

function Menus.isOpen() return win.Visible end

function Menus.close()
	win.Visible = false
	if App.onMenuClosed then App.onMenuClosed() end
end

function Menus.toast(text, color)
	local t = make("TextLabel", {Size = UDim2.fromOffset(460, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = color or C.panel2, Text = text,
		TextWrapped = true, Font = Enum.Font.GothamBold, TextSize = 17, ZIndex = 30, Parent = toastBox})
	Ui.corner(t, 10)
	Ui.pad(t, 10)
	task.delay(3.5, function() t:Destroy() end)
end

local SCREENS = {}
function Menus.open(name, arg)
	if not SCREENS[name] then return end
	win.Visible = true
	Ui.clear(body)
	body.CanvasPosition = Vector2.zero
	Menus.backBtn.Visible = name ~= "main" and name ~= "results"
	if not body:FindFirstChildOfClass("UIListLayout") then Ui.list(body, 10) end
	SCREENS[name](arg)
end

local function section(text)
	return make("TextLabel", {Size = UDim2.new(1, 0, 0, 26), Text = text, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = body})
end

local function row(height, parent)
	local f = make("Frame", {Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.panel2, Parent = parent or body})
	Ui.corner(f, 12)
	return f
end

---------------------------------------------------------------------------
-- accueil
---------------------------------------------------------------------------
SCREENS.main = function()
	winTitle.Text = "PISTE POUSSIÈRE"
	local p = App.profile
	local lvl = math.floor(p.exp / Config.LEVEL_EXP) + 1
	local head = row(70)
	Ui.label(string.format("%s   ·   Niveau %d   ·   %s CR", player.DisplayName, lvl, Ui.num(p.cr)), {Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 26),
		Font = Enum.Font.GothamBold, TextSize = 20, Parent = head})
	Ui.bar(head, {Position = UDim2.fromOffset(16, 42), Size = UDim2.new(1, -32, 0, 10)}, (p.exp % Config.LEVEL_EXP) / Config.LEVEL_EXP)

	-- événement
	local ev = row(56)
	ev.BackgroundColor3 = Color3.fromRGB(120, 70, 20)
	Ui.label(string.format("ÉVÉNEMENT EN COURS : %s — jetons de raid %d / 10 → gants « Sable du raid »", Config.EVENT.name, p.tokens or 0),
		{Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -150, 1, 0), Font = Enum.Font.GothamBold, TextSize = 16, Parent = ev})
	Ui.button("Y aller", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(120, 38)}, function()
		App.startStage(Config.EVENT.stage)
	end).Parent = ev

	local grid = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body})
	make("UIGridLayout", {CellSize = UDim2.new(0.5, -6, 0, 64), CellPadding = UDim2.fromOffset(12, 12), Parent = grid})
	local items = {
		{"CONDUIRE", function() Menus.open("stages") end},
		{"CONDUITE PARTAGÉE", function() Menus.open("drivers") end},
		{"DÉPLACEMENT LIBRE", function() Menus.close(); App.freeRoam() end},
		{"MON GARAGE", function() Menus.open("garage") end},
		{"BOUTIQUE", function() Menus.open("shop") end},
		{"CONTRATS", function() Menus.open("contracts") end},
		{"DÉFIER UN JOUEUR", function() Menus.open("challenge") end},
		{"PARAMÈTRES", function() Menus.open("settings") end},
	}
	for i, it in ipairs(items) do
		local b = Ui.button(it[1], {TextSize = 20}, it[2], i == 1 and "primary" or "secondary")
		b.Parent = grid
	end
	local building = Shared:GetAttribute("Building")
	if building then
		section("Construction des étapes en cours : " .. building .. " (" .. math.floor((Shared:GetAttribute("BuildProgress") or 0) * 100) .. " %)")
	end
end

---------------------------------------------------------------------------
-- étapes
---------------------------------------------------------------------------
SCREENS.stages = function()
	winTitle.Text = "ÉTAPES"
	local p = App.profile
	local car = Config.CAR_BY_ID[p.car]
	local carRow = row(50)
	Ui.label("Voiture : " .. car.name .. "  (" .. car.cls .. " " .. car.score .. ")", {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -200, 1, 0),
		Font = Enum.Font.GothamBold, TextSize = 18, Parent = carRow})
	Ui.button("Changer", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(120, 36)}, function() Menus.open("garage") end, "secondary").Parent = carRow

	for _, st in ipairs(Config.STAGES) do
		local inf = info(st.id)
		local T = inf.T
		local r = row(150)
		if st.event then Ui.stroke(r, Color3.fromRGB(250, 150, 30), 2) end
		Ui.label((st.event and "ÉVÉNEMENT — " or "") .. st.name .. "  ·  " .. st.country, {Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -220, 0, 26),
			Font = Enum.Font.GothamBlack, TextSize = 20, Parent = r})
		local got = 0
		local cs = p.coins[st.id]
		if cs then for _ in pairs(cs) do got = got + 1 end end
		local medal = p.medals[st.id]
		local best = p.best[st.id]
		Ui.label(string.format("%.1f km · dénivelé %d m · %d virages · pièces %d/%d\n%s", inf.km, math.floor(inf.climb + 0.5), #T.corners, got, #T.coins, inf.surfaces),
			{Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -220, 0, 40), TextSize = 14, TextColor3 = C.dim, Parent = r})
		local md = T.medals
		Ui.label(string.format("Bronze %s · Argent %s · Or %s · Platine %s", Ui.fmt(md.bronze), Ui.fmt(md.argent), Ui.fmt(md["or"]), Ui.fmt(md.platine)),
			{Position = UDim2.fromOffset(16, 80), Size = UDim2.new(1, -220, 0, 20), TextSize = 14, Parent = r})
		local lb = App.leaderboards[st.id]
		local glob = (lb and lb[1]) and (Ui.fmt(lb[1].t) .. " (" .. lb[1].name .. ")") or "--"
		Ui.label(string.format("Record perso : %s%s   ·   Meilleur temps mondial : %s", best and Ui.fmt(best.t) or "--",
			medal and ("  · " .. Config.MEDAL_NAMES[medal]) or "", glob), {Position = UDim2.fromOffset(16, 104), Size = UDim2.new(1, -220, 0, 36), TextSize = 14,
			TextColor3 = medal and Ui.rgb(Config.MEDAL_COLORS[medal]) or C.text, Parent = r})
		local ready = App.stageReady[st.id]
		local go = Ui.button(ready and "PARTIR" or "Construction…", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 14), Size = UDim2.fromOffset(180, 50), TextSize = 20},
			function() if App.stageReady[st.id] then App.startStage(st.id) end end, ready and "primary" or "secondary")
		go.Parent = r
		Ui.button("Classement", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 76), Size = UDim2.fromOffset(180, 40)}, function()
			Menus.open("leaderboard", st.id)
		end, "secondary").Parent = r
	end
end

SCREENS.leaderboard = function(stageId)
	local st = Config.STAGE_BY_ID[stageId]
	winTitle.Text = "CLASSEMENT — " .. string.upper(st.name)
	local list = App.req("leaderboard", stageId) or {}
	if #list == 0 then section("Aucun temps enregistré pour l'instant (ou classement indisponible en test dans Studio).") end
	for i, e in ipairs(list) do
		local r = row(40)
		Ui.label(string.format("%d.  %s", i, e.name or "?"), {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.7, 0, 1, 0), Font = Enum.Font.GothamBold, TextSize = 17, Parent = r})
		Ui.label(Ui.fmt(e.t), {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0.3, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamBlack, TextSize = 17, Parent = r})
	end
	Ui.button("◀ Étapes", {Size = UDim2.fromOffset(160, 40)}, function() Menus.open("stages") end, "secondary").Parent = body
end

---------------------------------------------------------------------------
-- garage
---------------------------------------------------------------------------
local function statBar(parent, y, name, v)
	Ui.label(name, {Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(120, 18), TextSize = 14, TextColor3 = C.dim, Parent = parent})
	Ui.bar(parent, {Position = UDim2.fromOffset(124, y + 5), Size = UDim2.new(1, -160, 0, 8)}, v / 10)
	Ui.label(tostring(v), {Position = UDim2.new(1, -30, 0, y), Size = UDim2.fromOffset(30, 18), TextSize = 14, Parent = parent})
end

SCREENS.garage = function(selId)
	winTitle.Text = "MON GARAGE"
	local p = App.profile
	selId = selId or p.car
	local car = Config.CAR_BY_ID[selId] or Config.CARS[1]
	local owned = p.owned[car.id]

	-- liste des voitures
	local list = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body})
	make("UIGridLayout", {CellSize = UDim2.new(0.25, -8, 0, 54), CellPadding = UDim2.fromOffset(8, 8), Parent = list})
	for _, c in ipairs(Config.CARS) do
		local own = p.owned[c.id]
		local t = c.name .. "  " .. c.cls .. "\n" .. (own and (c.id == p.car and "★ Choisie" or "Possédée") or (c.gamepass and App.cometeId ~= 0 and "Pass de jeu" or (Ui.num(c.price) .. " CR")))
		local b = Ui.button(t, {TextSize = 14}, function() Menus.open("garage", c.id) end, c.id == car.id and "primary" or "secondary")
		b.TextWrapped = true
		b.Parent = list
	end

	-- détail
	local d = row(250)
	local stats = Config.carStats(car)
	local drive = car.front == 1 and "Traction" or (car.front == 0 and "Propulsion" or string.format("4x4 %d/%d", math.floor(car.front * 100 + 0.5), math.floor((1 - car.front) * 100 + 0.5)))
	Ui.label(string.format("%s   %s %d", car.name, car.cls, car.score), {Position = UDim2.fromOffset(16, 10), Size = UDim2.new(0.5, -20, 0, 30), Font = Enum.Font.GothamBlack, TextSize = 24, Parent = d})
	Ui.label(car.desc, {Position = UDim2.fromOffset(16, 44), Size = UDim2.new(0.5, -20, 0, 60), TextSize = 14, TextColor3 = C.dim, Parent = d})
	Ui.label(string.format("%d km/h · %d ch · %d Nm · %d kg · %s%s", car.vmax, car.ch + (car.hybrid and car.hybrid.ch or 0), car.nm, car.kg, drive,
		car.turbo and " · turbo" or (car.hybrid and " · hybride" or (car.electric and " · électrique" or ""))),
		{Position = UDim2.fromOffset(16, 108), Size = UDim2.new(0.5, -20, 0, 36), TextSize = 14, Parent = d})
	local mexp = p.mastery[car.id] or 0
	local mlvl = 1
	for i, need in ipairs(Config.MASTERY_EXP) do if mexp >= need then mlvl = i end end
	local nextNeed = Config.MASTERY_EXP[mlvl + 1]
	Ui.label(string.format("Maîtrise M%d%s", mlvl, nextNeed and string.format("  (%d / %d EXP)", mexp, nextNeed) or "  (max)"),
		{Position = UDim2.fromOffset(16, 150), Size = UDim2.new(0.5, -20, 0, 20), Font = Enum.Font.GothamBold, TextSize = 15, Parent = d})
	Ui.bar(d, {Position = UDim2.fromOffset(16, 174), Size = UDim2.new(0.5, -36, 0, 8)}, nextNeed and (mexp - Config.MASTERY_EXP[mlvl]) / (nextNeed - Config.MASTERY_EXP[mlvl]) or 1, C.blue)

	local sp = make("Frame", {Position = UDim2.new(0.5, 10, 0, 16), Size = UDim2.new(0.5, -26, 0, 110), BackgroundTransparency = 1, Parent = d})
	statBar(sp, 0, "Vitesse max", stats.vitesse)
	statBar(sp, 26, "Accélération", stats.acceleration)
	statBar(sp, 52, "Adhérence", stats.adherence)
	statBar(sp, 78, "Maniabilité", stats.maniabilite)

	local act
	if owned then
		act = Ui.button(p.car == car.id and "Voiture choisie" or "CHOISIR", {}, function()
			App.req("selectCar", car.id)
			Menus.open("garage", car.id)
		end, p.car == car.id and "secondary" or nil)
	elseif car.gamepass and App.cometeId ~= 0 then
		act = Ui.button("Acheter le pass", {}, function() MarketplaceService:PromptGamePassPurchase(player, App.cometeId) end)
	else
		act = Ui.button("ACHETER  " .. Ui.num(car.price) .. " CR", {}, function()
			local r = App.req("buyCar", car.id)
			if r and r.ok then Menus.toast(car.name .. " ajoutée au garage !", C.green) else Menus.toast(r and r.msg or "Achat impossible", C.red) end
			Menus.open("garage", car.id)
		end)
	end
	act.AnchorPoint = Vector2.new(1, 1)
	act.Position = UDim2.new(1, -16, 1, -16)
	act.Size = UDim2.fromOffset(240, 50)
	act.Parent = d
	if owned then
		Ui.button("Rouler avec", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -266, 1, -16), Size = UDim2.fromOffset(150, 50)}, function()
			App.req("selectCar", car.id)
			Menus.open("stages")
		end, "secondary").Parent = d
	end

	-- peintures
	if owned then
		section("PEINTURE")
		local pal = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body})
		make("UIGridLayout", {CellSize = UDim2.fromOffset(110, 46), CellPadding = UDim2.fromOffset(8, 8), Parent = pal})
		for i, paint in ipairs(Config.PAINTS) do
			local own = p.ownedPaints[tostring(i)]
			local col = paint.rgb and Ui.rgb(paint.rgb) or Ui.rgb(car.color)
			local b = Ui.button(own and paint.name or "🔒", {TextSize = 12}, function()
				if own then
					App.req("setPaint", car.id, i)
					Menus.toast("Peinture appliquée à la prochaine course")
					Menus.open("garage", car.id)
				else
					Menus.toast("Débloque des peintures avec la caisse de peinture (Boutique)")
				end
			end)
			b.BackgroundColor3 = col
			b.TextColor3 = (col.R + col.G + col.B > 1.6) and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
			if (p.paints[car.id] or 1) == i then Ui.stroke(b, C.acc, 3) end
			if not own then b.BackgroundTransparency = 0.6 end
			b.Parent = pal
		end
	end

	-- gants du chauffeur
	section("GANTS DU CHAUFFEUR")
	local gl = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body})
	make("UIGridLayout", {CellSize = UDim2.fromOffset(170, 46), CellPadding = UDim2.fromOffset(8, 8), Parent = gl})
	for _, g in ipairs(Config.GLOVES) do
		local own = p.ownedGloves[g.id]
		local txt = g.name
		if not own then
			if g.price then txt = txt .. " · " .. g.price .. " CR" elseif g.event then txt = txt .. " · événement" elseif g.mastery then txt = txt .. " · M10" end
		end
		local b = Ui.button(txt, {TextSize = 13}, function()
			if own then
				App.req("setGloves", g.id)
			elseif g.price then
				local r = App.req("buyGloves", g.id)
				if not (r and r.ok) then Menus.toast(r and r.msg or "Impossible", C.red) end
			else
				Menus.toast("Ces gants se gagnent : " .. (g.event and "10 jetons de raid" or "maîtrise M10 sur une voiture"))
			end
			Menus.open("garage", car.id)
		end, p.gloves == g.id and "primary" or "secondary")
		b.TextWrapped = true
		local sw = make("Frame", {Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(10, 34), BackgroundColor3 = Ui.rgb(g.rgb), Parent = b})
		Ui.corner(sw, 4)
		b.Parent = gl
	end
end

---------------------------------------------------------------------------
-- boutique
---------------------------------------------------------------------------
SCREENS.shop = function()
	winTitle.Text = "BOUTIQUE"
	local p = App.profile
	section("CAISSES  (tu as " .. Ui.num(p.cr) .. " CR)")
	local descs = {
		paint = "Une peinture au hasard parmi celles qui te manquent.",
		perf = "Une voiture au hasard : les classes D et C sortent plus souvent que les S.",
		glove = "Une paire de gants au hasard.",
	}
	for _, k in ipairs({"perf", "paint", "glove"}) do
		local cr = Config.CRATES[k]
		local r = row(70)
		Ui.label(cr.name, {Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -240, 0, 26), Font = Enum.Font.GothamBlack, TextSize = 19, Parent = r})
		Ui.label(descs[k], {Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -240, 0, 24), TextSize = 14, TextColor3 = C.dim, Parent = r})
		Ui.button("Ouvrir · " .. Ui.num(cr.price) .. " CR", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(200, 44)}, function()
			local res = App.req("openCrate", k)
			if res and res.ok then Menus.toast(res.text, C.green) else Menus.toast(res and res.msg or "Impossible", C.red) end
			Menus.open("shop")
		end).Parent = r
	end
	section("PASSES")
	local r = row(70)
	Ui.label("Pass VIP : EXP et crédits doublés", {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -240, 1, 0), Font = Enum.Font.GothamBold, TextSize = 17, Parent = r})
	if App.vipId ~= 0 then
		Ui.button(App.vip and "Actif ✓" or "Acheter", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(200, 44)}, function()
			if not App.vip then MarketplaceService:PromptGamePassPurchase(player, App.vipId) end
		end, App.vip and "secondary" or nil).Parent = r
	else
		Ui.label("Bientôt disponible", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(200, 44), TextColor3 = C.dim, Parent = r})
	end
	if App.cometeId ~= 0 then
		local r2 = row(70)
		Ui.label("Pass Comète Bi : la supercar biturbo classe S", {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -240, 1, 0), Font = Enum.Font.GothamBold, TextSize = 17, Parent = r2})
		Ui.button(p.owned.comete and "Possédée ✓" or "Acheter", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(200, 44)}, function()
			if not p.owned.comete then MarketplaceService:PromptGamePassPurchase(player, App.cometeId) end
		end, p.owned.comete and "secondary" or nil).Parent = r2
	end
	section("CRÉDITS : gagne-les en course, avec les médailles, les pièces et les contrats.")
end

---------------------------------------------------------------------------
-- contrats
---------------------------------------------------------------------------
SCREENS.contracts = function()
	winTitle.Text = "CONTRATS DU JOUR"
	local p = App.profile
	local list = p.contracts and p.contracts.list or {}
	for _, c in ipairs(list) do
		local def
		for _, d in ipairs(Config.CONTRACTS) do if d.id == c.id then def = d end end
		if def then
			local r = row(76)
			Ui.label(def.text, {Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -240, 0, 26), Font = Enum.Font.GothamBold, TextSize = 18, Parent = r})
			Ui.bar(r, {Position = UDim2.fromOffset(16, 44), Size = UDim2.new(1, -260, 0, 10)}, c.progress / def.goal, C.green)
			Ui.label(string.format("%s / %s", tostring(c.progress), tostring(def.goal)), {Position = UDim2.new(1, -236, 0, 38), Size = UDim2.fromOffset(60, 20), TextSize = 14, Parent = r})
			local b = Ui.button(c.claimed and "Récupéré ✓" or ("+" .. def.cr .. " CR"), {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 44)}, function()
				if c.done and not c.claimed then
					App.req("claimContract", c.id)
					Menus.toast("+" .. def.cr .. " CR", C.green)
					task.wait(0.3)
					Menus.open("contracts")
				end
			end, (c.done and not c.claimed) and "primary" or "secondary")
			b.Parent = r
		end
	end
	section("Nouveaux contrats chaque jour (minuit UTC).")
end

---------------------------------------------------------------------------
-- défis et conduite partagée
---------------------------------------------------------------------------
SCREENS.challenge = function(target)
	winTitle.Text = "DÉFIER UN JOUEUR"
	if not target then
		section("Choisis un adversaire :")
		local n = 0
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= player then
				n = n + 1
				local r = row(50)
				Ui.label(pl.DisplayName .. "  · Niveau " .. (pl:GetAttribute("Level") or 1), {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -200, 1, 0), Font = Enum.Font.GothamBold, TextSize = 17, Parent = r})
				Ui.button("Choisir", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 38)}, function()
					Menus.open("challenge", pl)
				end).Parent = r
			end
		end
		if n == 0 then section("Personne d'autre sur le serveur pour l'instant.") end
		return
	end
	section("Défi contre " .. target.DisplayName .. " — choisis l'étape :")
	for _, st in ipairs(Config.STAGES) do
		local r = row(50)
		Ui.label(st.name .. " · " .. st.country, {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -200, 1, 0), Font = Enum.Font.GothamBold, TextSize = 17, Parent = r})
		Ui.button("Envoyer", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 38)}, function()
			local res = App.req("challenge", target.UserId, st.id)
			Menus.toast((res and res.ok) and ("Défi envoyé à " .. target.DisplayName) or ((res and res.msg) or "Défi impossible"))
			Menus.close()
		end).Parent = r
	end
end

function Menus.invite(data)
	if inviteBox then inviteBox:Destroy() end
	inviteBox = Ui.panel({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(460, 120), ZIndex = 40, Parent = gui})
	Ui.stroke(inviteBox, C.acc, 2)
	Ui.label("DÉFI DE COURSE", {Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 24), Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = C.acc, Parent = inviteBox})
	Ui.label(data.from .. " te défie sur « " .. data.stage .. " »", {Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -32, 0, 24), TextSize = 16, Parent = inviteBox})
	local box = inviteBox
	Ui.button("Accepter", {Position = UDim2.fromOffset(16, 66), Size = UDim2.fromOffset(200, 42)}, function()
		box:Destroy()
		App.req("challengeReply", data.id, true)
	end).Parent = box
	Ui.button("Refuser", {Position = UDim2.fromOffset(244, 66), Size = UDim2.fromOffset(200, 42)}, function()
		box:Destroy()
		App.req("challengeReply", data.id, false)
	end, "secondary").Parent = box
	task.delay(30, function() if box.Parent then box:Destroy() end end)
end

SCREENS.drivers = function()
	winTitle.Text = "CONDUITE PARTAGÉE"
	section("Monte à côté d'un chauffeur et annonce-lui les virages (touches 1 à 4).")
	local list = App.req("drivers") or {}
	if #list == 0 then section("Aucun chauffeur en course pour l'instant. Réessaie dans un moment !") end
	for _, d in ipairs(list) do
		local r = row(56)
		Ui.label(string.format("%s  ·  %s  ·  %s", d.name, d.stage, d.car), {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -200, 1, 0), Font = Enum.Font.GothamBold, TextSize = 17, Parent = r})
		Ui.button("Monter", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 40)}, function()
			local res = App.req("joinPassenger", d.userId)
			if res and res.ok then Menus.close() else Menus.toast(res and res.msg or "Impossible", C.red) end
		end).Parent = r
	end
	Ui.button("Actualiser", {Size = UDim2.fromOffset(160, 40)}, function() Menus.open("drivers") end, "secondary").Parent = body
end

---------------------------------------------------------------------------
-- paramètres
---------------------------------------------------------------------------
SCREENS.settings = function()
	winTitle.Text = "PARAMÈTRES"
	local s = App.profile.settings
	local function choice(title, key, options)
		local r = row(60)
		Ui.label(title, {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.4, 0, 1, 0), Font = Enum.Font.GothamBold, TextSize = 17, Parent = r})
		local box = make("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0.58, 0, 0, 40), BackgroundTransparency = 1, Parent = r})
		Ui.list(box, 6, true, Enum.HorizontalAlignment.Right)
		for _, o in ipairs(options) do
			local b = Ui.button(o[1], {Size = UDim2.fromOffset(130, 40), TextSize = 14}, function()
				s[key] = o[2]
				App.req("setSettings", {[key] = o[2]})
				Menus.open("settings")
			end, s[key] == o[2] and "primary" or "secondary")
			b.Parent = box
		end
	end
	choice("Caméra par défaut", "camera", {{"Poursuite", 1}, {"Capot", 2}, {"Cockpit", 3}})
	choice("Boîte de vitesses", "manual", {{"Automatique", false}, {"Manuelle (M)", true}})
	choice("Sensibilité direction", "sens", {{"Douce", 0.75}, {"Normale", 1}, {"Vive", 1.25}})
	choice("Conseils du copilote", "hints", {{"Oui", true}, {"Non", false}})
	choice("Fantôme", "ghost", {{"Oui", true}, {"Non", false}})
	choice("Accepter des passagers", "passengers", {{"Oui", true}, {"Non", false}})
	section("Commandes : Z/W gaz · S frein puis marche arrière · Q/A et D direction · Espace frein à main · R dernier point de passage · Retour arrière (maintenir) recommencer · C caméra · M boîte manuelle (E/Maj monter, F/Ctrl descendre) · clic droit maintenu : regarder autour (cockpit)")
	section("Manette : gâchettes gaz/frein · stick gauche direction · X frein à main · Y récupération · B/L1 rapports")
end

---------------------------------------------------------------------------
-- résultats
---------------------------------------------------------------------------
SCREENS.results = function(arg)
	local res, replay = arg.result, arg.replay
	winTitle.Text = "ARRIVÉE !"
	if not res or res.error then
		section(res and res.error or "Résultat indisponible")
	else
		local head = row(110)
		Ui.label(Ui.fmt(res.total), {Position = UDim2.fromOffset(16, 6), Size = UDim2.new(0.5, 0, 0, 56), Font = Enum.Font.GothamBlack, TextSize = 52, Parent = head})
		Ui.label(string.format("Temps brut %s + pénalités %.1f s", Ui.fmt(res.raw), res.pen), {Position = UDim2.fromOffset(16, 66), Size = UDim2.new(0.5, 0, 0, 20), TextSize = 15, TextColor3 = C.dim, Parent = head})
		local mtxt = res.medal and ("Médaille " .. Config.MEDAL_NAMES[res.medal]) or "Pas de médaille"
		Ui.label(mtxt, {Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0.5, -16, 0, 34), Font = Enum.Font.GothamBlack, TextSize = 28,
			TextColor3 = res.medal and Ui.rgb(Config.MEDAL_COLORS[res.medal]) or C.dim, TextXAlignment = Enum.TextXAlignment.Right, Parent = head})
		local rec = res.newBest and "Nouveau record personnel !" or ("Record : " .. Ui.fmt(res.prev))
		Ui.label(rec, {Position = UDim2.new(0.5, 0, 0, 50), Size = UDim2.new(0.5, -16, 0, 22), Font = Enum.Font.GothamBold, TextSize = 16,
			TextColor3 = res.newBest and C.green or C.text, TextXAlignment = Enum.TextXAlignment.Right, Parent = head})
		if res.medals then
			Ui.label(string.format("Bronze %s · Argent %s · Or %s · Platine %s", Ui.fmt(res.medals.bronze), Ui.fmt(res.medals.argent), Ui.fmt(res.medals["or"]), Ui.fmt(res.medals.platine)),
				{Position = UDim2.new(0.5, 0, 0, 76), Size = UDim2.new(0.5, -16, 0, 20), TextSize = 13, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right, Parent = head})
		end

		-- récompenses
		section("RÉCOMPENSES" .. (res.vip and "  (VIP ×2)" or ""))
		for _, r in ipairs(res.rewards or {}) do
			local rr = row(32)
			Ui.label(r.label, {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.6, 0, 1, 0), TextSize = 15, Parent = rr})
			Ui.label(string.format("+%d EXP   +%d CR", r.exp, r.cr), {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0.4, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = C.acc, Parent = rr})
		end
		local tot = row(36)
		Ui.label(string.format("TOTAL  +%d EXP   +%d CR%s%s", res.exp or 0, res.cr or 0, (res.tokens and res.tokens > 0) and ("   +" .. res.tokens .. " jeton(s) de raid") or "",
			res.masteryUp and ("   ·   Maîtrise M" .. res.mastery .. " !") or ""), {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0),
			Font = Enum.Font.GothamBlack, TextSize = 16, Parent = tot})

		-- gain / perte par section
		if res.bestSplits and res.splits then
			section("GAIN / PERTE PAR SECTION (comparé à ton ancien record)")
			local chart = row(120)
			local n = #res.splits
			local prevA, prevB = 0, 0
			for k = 1, n do
				local a, b = res.splits[k], res.bestSplits[k]
				if a and b then
					local d = (a - prevA) - (b - prevB)
					prevA, prevB = a, b
					local h = math.clamp(math.abs(d) * 30, 2, 50)
					make("Frame", {AnchorPoint = Vector2.new(0, d < 0 and 1 or 0), Position = UDim2.new((k - 1) / n, 4, 0.5, 0), Size = UDim2.new(1 / n, -8, 0, h),
						BackgroundColor3 = d < 0 and C.green or C.red, Parent = chart})
				end
			end
			make("Frame", {Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.dim, Parent = chart})
		end
	end

	local btns = make("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = body})
	Ui.list(btns, 10, true)
	Ui.button("Réessayer", {Size = UDim2.fromOffset(170, 48)}, function() Menus.close(); App.retry() end).Parent = btns
	Ui.button("Regarder le replay", {Size = UDim2.fromOffset(210, 48)}, function() Menus.close(); App.replay(replay, arg) end, "secondary").Parent = btns
	Ui.button("Menu principal", {Size = UDim2.fromOffset(170, 48)}, function() App.toHub(); Menus.open("main") end, "secondary").Parent = btns
	Ui.button("Mon garage", {Size = UDim2.fromOffset(150, 48)}, function() App.toHub(); Menus.open("garage") end, "secondary").Parent = btns
end

function Menus.challengeResult(d)
	local txt
	if d.you and d.opponent then
		txt = string.format("%s ! %s contre %s pour %s", d.win and "Victoire" or "Défaite", Ui.fmt(d.you), Ui.fmt(d.opponent), d.opponentName)
	elseif d.you then
		txt = "Victoire : " .. d.opponentName .. " n'a pas terminé"
	else
		txt = "Défi terminé"
	end
	Menus.toast(txt, d.win and C.green or C.red)
end

return Menus

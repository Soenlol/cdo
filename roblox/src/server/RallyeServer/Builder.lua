-- Construction des étapes et du parc d'assistance (serveur)
-- Terrain lisse Roblox pour la route et le sol (la surface est lue par la physique), pièces pour le décor.

local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Rallye")
local Config = require(Shared.Config)
local Track = require(Shared.Track)
local Cars = require(Shared.Cars)

local Builder = {}
local M = Config.M
local HALF = Config.HALF
local terrain = workspace.Terrain
local Mat = Enum.Material

local function c3(r, g, b) return Color3.fromRGB(r, g, b) end

local function newPart(parent, size, cf, color, material, collide, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Mat.SmoothPlastic
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end
Builder.newPart = newPart

local function label(p, face, text, bg, fg, size)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 20
	sg.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = bg or c3(255, 255, 255)
	t.BackgroundTransparency = bg and 0 or 1
	t.TextColor3 = fg or c3(20, 20, 20)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = text
	t.Parent = sg
	return sg
end
Builder.label = label

function Builder.applyMaterialColors()
	for name, rgb in pairs(Config.MATERIAL_COLORS) do
		pcall(function() terrain:SetMaterialColor(Mat[name], c3(rgb[1], rgb[2], rgb[3])) end)
	end
	pcall(function() terrain.Decoration = true end)
	terrain.WaterColor = c3(60, 120, 150)
	terrain.WaterTransparency = 0.4
	terrain.WaterWaveSize = 0.08
end

-- position monde d'un échantillon
local function W(origin, s, lat, up)
	lat = lat or 0
	up = up or 0
	return origin + Vector3.new((s.x + s.nx * lat) * M, (s.y + up) * M, (s.z + s.nz * lat) * M)
end
Builder.W = W

local function segFrame(origin, a, b, lat, up, pitched)
	local p1 = W(origin, a, lat, up)
	local p2 = W(origin, b, lat, up)
	local dir = p2 - p1
	if not pitched then dir = Vector3.new(dir.X, 0, dir.Z) end
	if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, 1) end
	local mid = (p1 + p2) / 2
	return CFrame.lookAt(mid, mid + dir), (p2 - p1).Magnitude
end

local function featureAt(T, d, kind)
	for _, f in ipairs(T.features) do
		if f.kind == kind and d >= f.d0 - 0.01 and d <= f.d1 + 0.01 then return f end
	end
	return nil
end

-- colonne de terrain : demi-largeur hw (m), sommet top (m, relatif à la route), base absolue
local function column(origin, a, b, hw, top, baseY, material, extraLen)
	local cf, len = segFrame(origin, a, b, 0, 0, false)
	local topY = (math.min(a.y, b.y) + top) * M + origin.Y
	local bottom = baseY * M + origin.Y
	local h = topY - bottom
	if h < 1 then return end
	local c = CFrame.new(cf.Position.X, (topY + bottom) / 2, cf.Position.Z) * (cf - cf.Position)
	terrain:FillBlock(c, Vector3.new(hw * 2 * M, h, len + (extraLen or 1) * M), material)
end

---------------------------------------------------------------------------
-- Décor
---------------------------------------------------------------------------
local DECO = {}

local trunkC = c3(92, 62, 36)
DECO.pins = function(f, pos, r)
	local h = r(4, 7)
	newPart(f, Vector3.new(0.6, 2.2, 0.6) * M, CFrame.new(pos + Vector3.new(0, 1.1 * M, 0)), trunkC, Mat.Wood, true)
	for k = 0, 2 do
		local w = (2.8 - k * 0.8) * M
		newPart(f, Vector3.new(w, h / 3 * M, w), CFrame.new(pos + Vector3.new(0, (2.2 + (k + 0.5) * h / 3) * M, 0)) * CFrame.Angles(0, r(0, 3), 0),
			c3(36 + k * 6, 82 + k * 8, 44), Mat.SmoothPlastic, false)
	end
end
DECO.sapins = DECO.pins
DECO.sapinsNeige = function(f, pos, r)
	local h = r(4, 7)
	newPart(f, Vector3.new(0.6, 2.2, 0.6) * M, CFrame.new(pos + Vector3.new(0, 1.1 * M, 0)), trunkC, Mat.Wood, true)
	for k = 0, 2 do
		local w = (2.8 - k * 0.8) * M
		local y = (2.2 + (k + 0.5) * h / 3) * M
		local rot = CFrame.Angles(0, r(0, 3), 0)
		newPart(f, Vector3.new(w, h / 3 * M, w), CFrame.new(pos + Vector3.new(0, y, 0)) * rot, c3(40, 80, 58), Mat.SmoothPlastic, false)
		newPart(f, Vector3.new(w * 0.9, 0.25 * M, w * 0.9), CFrame.new(pos + Vector3.new(0, y + h / 6 * M, 0)) * rot, c3(250, 252, 255), Mat.Snow, false)
	end
end
DECO.erables = function(f, pos, r)
	newPart(f, Vector3.new(0.7, 3, 0.7) * M, CFrame.new(pos + Vector3.new(0, 1.5 * M, 0)), trunkC, Mat.Wood, true)
	local cols = {c3(214, 70, 40), c3(236, 130, 40), c3(190, 40, 40), c3(240, 180, 60)}
	local c = cols[math.floor(r(1, 4.99))]
	newPart(f, Vector3.new(4, 2.5, 4) * M, CFrame.new(pos + Vector3.new(0, 4.2 * M, 0)) * CFrame.Angles(0, r(0, 3), 0), c, Mat.SmoothPlastic, false)
	newPart(f, Vector3.new(2.8, 1.6, 2.8) * M, CFrame.new(pos + Vector3.new(0.4 * M, 6 * M, 0)) * CFrame.Angles(0, r(0, 3), 0), c, Mat.SmoothPlastic, false)
end
DECO.oliviers = function(f, pos, r)
	newPart(f, Vector3.new(0.6, 1.8, 0.6) * M, CFrame.new(pos + Vector3.new(0, 0.9 * M, 0)), c3(110, 90, 70), Mat.Wood, true)
	newPart(f, Vector3.new(3.2, 1.4, 3.2) * M, CFrame.new(pos + Vector3.new(0, 2.4 * M, 0)) * CFrame.Angles(0, r(0, 3), 0), c3(120, 140, 90), Mat.SmoothPlastic, false)
	if r() < 0.3 then
		newPart(f, Vector3.new(0.3, 0.3, 0.3) * M, CFrame.new(pos + Vector3.new(1.2 * M, 2.2 * M, 0)), c3(245, 220, 60), Mat.SmoothPlastic, false)
	end
end
DECO.plage = function(f, pos, r)
	if r() < 0.5 then
		-- palmier
		for k = 0, 4 do
			newPart(f, Vector3.new(0.45, 1.2, 0.45) * M, CFrame.new(pos + Vector3.new(k * 0.15 * M, (0.6 + k * 1.15) * M, 0)), c3(130, 100, 70), Mat.Wood, k == 0)
		end
		for a = 0, 4 do
			newPart(f, Vector3.new(0.5, 0.15, 2.6) * M, CFrame.new(pos + Vector3.new(0.75 * M, 6 * M, 0)) * CFrame.Angles(math.rad(-20), a * 1.25, 0) * CFrame.new(0, 0, -1.2 * M),
				c3(60, 150, 70), Mat.SmoothPlastic, false)
		end
	else
		-- parasol
		newPart(f, Vector3.new(0.15, 2.5, 0.15) * M, CFrame.new(pos + Vector3.new(0, 1.25 * M, 0)), c3(240, 240, 240), Mat.SmoothPlastic, true)
		newPart(f, Vector3.new(2.6, 0.25, 2.6) * M, CFrame.new(pos + Vector3.new(0, 2.5 * M, 0)) * CFrame.Angles(0, r(0, 3), 0),
			r() < 0.5 and c3(230, 60, 60) or c3(40, 120, 220), Mat.SmoothPlastic, false)
	end
end
DECO.desert = function(f, pos, r)
	local k = r()
	if k < 0.4 then
		-- acacia au sommet plat
		newPart(f, Vector3.new(0.5, 3, 0.5) * M, CFrame.new(pos + Vector3.new(0, 1.5 * M, 0)), c3(100, 80, 60), Mat.Wood, true)
		newPart(f, Vector3.new(5, 0.8, 4) * M, CFrame.new(pos + Vector3.new(0, 3.3 * M, 0)) * CFrame.Angles(0, r(0, 3), 0), c3(110, 130, 60), Mat.SmoothPlastic, false)
	elseif k < 0.75 then
		local s = r(1, 3)
		newPart(f, Vector3.new(s * 1.3, s, s) * M, CFrame.new(pos + Vector3.new(0, s * 0.4 * M, 0)) * CFrame.Angles(r(0, 1), r(0, 3), r(0, 1)), c3(170, 120, 80), Mat.Slate, true)
	else
		newPart(f, Vector3.new(1.2, 0.8, 1.2) * M, CFrame.new(pos + Vector3.new(0, 0.4 * M, 0)), c3(150, 140, 80), Mat.Grass, false)
	end
end
DECO.canyon = function(f, pos, r)
	local s = r(1.5, 4.5)
	newPart(f, Vector3.new(s * 1.2, s * r(0.8, 2), s) * M, CFrame.new(pos + Vector3.new(0, s * 0.5 * M, 0)) * CFrame.Angles(r(0, 0.5), r(0, 3), r(0, 0.5)),
		r() < 0.5 and c3(170, 80, 45) or c3(140, 70, 50), Mat.Slate, true)
end
DECO.village = function(f, pos, r, yaw)
	local w, d, h = r(5, 8), r(5, 8), r(4, 7)
	local wall = ({c3(240, 236, 226), c3(236, 214, 170), c3(220, 180, 150), c3(200, 220, 230)})[math.floor(r(1, 4.99))]
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	newPart(f, Vector3.new(w, h, d) * M, base * CFrame.new(0, h / 2 * M, 0), wall, Mat.SmoothPlastic, true)
	newPart(f, Vector3.new(w + 0.6, 0.8, d + 0.6) * M, base * CFrame.new(0, (h + 0.4) * M, 0), c3(170, 70, 50), Mat.SmoothPlastic, false)
	newPart(f, Vector3.new(1.2, 2, 0.1) * M, base * CFrame.new(0, 1 * M, -d / 2 * M - 0.05 * M), c3(90, 60, 40), Mat.Wood, false)
end
DECO.ferme = function(f, pos, r, yaw)
	if r() < 0.25 then
		local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
		newPart(f, Vector3.new(9, 5, 7) * M, base * CFrame.new(0, 2.5 * M, 0), c3(170, 40, 35), Mat.WoodPlanks, true)
		newPart(f, Vector3.new(9.6, 1, 7.6) * M, base * CFrame.new(0, 5.5 * M, 0), c3(70, 70, 75), Mat.SmoothPlastic, false)
	else
		DECO.pins(f, pos, r)
	end
end
DECO.lac = DECO.sapins
DECO.phare = DECO.oliviers

---------------------------------------------------------------------------
-- Construction d'une étape
---------------------------------------------------------------------------
function Builder.buildStage(stage, origin, parent, progress)
	local T = Track.generate(stage)
	local S = T.S
	local folder = Instance.new("Folder")
	folder.Name = stage.id
	folder.Parent = parent
	local deco = Instance.new("Folder")
	deco.Name = "Decor"
	deco.Parent = folder

	local offMat = Mat[stage.offroad] or Mat.Grass
	local x0, x1, z0, z1, y0 = Track.bounds(T)
	local baseY = y0 - 2
	local yield = 0
	local function tick()
		yield = yield + 1
		if yield % 25 == 0 then task.wait() end
	end

	-- sol de base
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local bw, bd = (x1 - x0 + 500), (z1 - z0 + 500)
	local tiles = 4
	for ix = 0, tiles - 1 do
		for iz = 0, tiles - 1 do
			local px = cx - bw / 2 + (ix + 0.5) * bw / tiles
			local pz = cz - bd / 2 + (iz + 0.5) * bd / tiles
			terrain:FillBlock(CFrame.new(origin + Vector3.new(px * M, (baseY - 3) * M, pz * M)),
				Vector3.new(bw / tiles * M, 6 * M, bd / tiles * M), offMat)
			task.wait()
		end
	end
	if progress then progress(0.1) end

	local n = #S
	-- 1) talus et collines
	for i = 1, n - 2, 2 do
		local a, b = S[i], S[i + 2]
		local bridge = featureAt(T, a.d, "pont") or featureAt(T, a.d, "pontCouvert")
		local lake = featureAt(T, a.d, "lac")
		local beach = featureAt(T, a.d, "plage")
		local mat = offMat
		if beach then mat = Mat.Sand end
		if lake then mat = Mat.Glacier end
		if not bridge then
			column(origin, a, b, HALF + 3, -0.3, baseY - 3, mat)
			column(origin, a, b, HALF + 14, -1.0, baseY - 3, mat)
			if i % 4 == 1 then
				column(origin, a, b, HALF + 32, -3.5, baseY - 3, mat, 5)
				local high = a.y - baseY
				if high > 12 then column(origin, a, b, HALF + 70, -9, baseY - 3, offMat, 5) end
				if high > 28 then column(origin, a, b, HALF + 130, -22, baseY - 3, offMat, 9) end
			end
			if lake and i % 4 == 1 then
				column(origin, a, b, HALF + 110, -0.05, baseY - 3, Mat.Glacier, 6)
			end
		end
		tick()
	end
	if progress then progress(0.4) end

	-- 2) masses rocheuses (tunnels, falaises)
	for i = 1, n - 2, 2 do
		local a, b = S[i], S[i + 2]
		if featureAt(T, a.d, "tunnel") then
			column(origin, a, b, HALF + 16, 22, baseY - 3, Mat.Rock, 2)
		end
		if stage.deco == "canyon" and i % 4 == 1 and not featureAt(T, a.d, "gue") then
			for _, side in ipairs({-1, 1}) do
				local cf = segFrame(origin, a, b, side * (HALF + 26), 0, false)
				local top = (a.y + 14 + ((i * 7) % 11)) * M + origin.Y
				local bottom = (baseY - 3) * M + origin.Y
				terrain:FillBlock(CFrame.new(cf.Position.X, (top + bottom) / 2, cf.Position.Z) * (cf - cf.Position),
					Vector3.new(16 * M, top - bottom, 9 * M), (i % 8 == 1) and Mat.Sandstone or Mat.Rock)
			end
		end
		tick()
	end

	-- 3) dégagement au-dessus de la route
	for i = 1, n - 1 do
		local a, b = S[i], S[i + 1]
		local tunnel = featureAt(T, a.d, "tunnel")
		local cf, len = segFrame(origin, a, b, 0, 0, true)
		local h = tunnel and 6.5 or 16
		local lift = (h / 2 - 0.4) * M
		terrain:FillBlock(cf * CFrame.new(0, lift, 0), Vector3.new((HALF + 2.5) * 2 * M, h * M, len + 0.6 * M), Mat.Air)
		tick()
	end
	if progress then progress(0.55) end

	-- 4) rivières sous les ponts
	for _, f in ipairs(T.features) do
		if f.kind == "pont" or f.kind == "pontCouvert" then
			local i0, i1 = Track.indexAtD(T, f.d0), Track.indexAtD(T, f.d1)
			local mid = S[math.floor((i0 + i1) / 2)]
			local yRoad = mid.y
			local p = origin + Vector3.new(mid.x * M, 0, mid.z * M)
			local dir = Vector3.new(math.sin(mid.h), 0, math.cos(mid.h))
			local cf = CFrame.lookAt(p, p + dir)
			local span = (f.d1 - f.d0 - 4) * M
			terrain:FillBlock(cf * CFrame.new(0, (yRoad - 2.5) * M + origin.Y - p.Y, 0), Vector3.new(90 * M, 9 * M, span), Mat.Air)
			terrain:FillBlock(cf * CFrame.new(0, (yRoad - 6.5) * M + origin.Y - p.Y, 0), Vector3.new(90 * M, 2 * M, span), Mat.Mud)
			terrain:FillBlock(cf * CFrame.new(0, (yRoad - 5) * M + origin.Y - p.Y, 0), Vector3.new(90 * M, 1.6 * M, span), Mat.Water)
		end
	end

	-- 5) la route
	for i = 1, n - 1 do
		local a, b = S[i], S[i + 1]
		local bridge = featureAt(T, a.d, "pont") or featureAt(T, a.d, "pontCouvert")
		local cf, len = segFrame(origin, a, b, 0, 0, true)
		if not bridge then
			local mat = Mat[a.surf] or Mat.Ground
			terrain:FillBlock(cf * CFrame.new(0, -1.2 * M, 0), Vector3.new(HALF * 2 * M, 2.4 * M, len + 0.6 * M), mat)
		end
		tick()
	end
	if progress then progress(0.7) end

	-- 6) eau : gués, lacs, mer
	for i = 1, n - 1, 2 do
		local a = S[i]
		local b = S[math.min(n, i + 2)]
		if featureAt(T, a.d, "gue") then
			local cf, len = segFrame(origin, a, b, 0, 0, false)
			local y = (math.min(a.y, b.y)) * M + origin.Y
			terrain:FillBlock(CFrame.new(cf.Position.X, y + 0.05 * M, cf.Position.Z) * (cf - cf.Position), Vector3.new((HALF + 14) * 2 * M, 0.5 * M, len + 1 * M), Mat.Water)
		end
		if featureAt(T, a.d, "plage") and i % 4 == 1 then
			local cf = segFrame(origin, a, b, -(HALF + 70), 0, false)
			local y = a.y * M + origin.Y
			terrain:FillBlock(CFrame.new(cf.Position.X, y - 2.5 * M, cf.Position.Z) * (cf - cf.Position), Vector3.new(110 * M, 3 * M, 12 * M), Mat.Water)
		end
		if a.deco == "lac" and stage.offroad ~= "Snow" and i % 4 == 1 then
			local cf = segFrame(origin, a, b, HALF + 60, 0, false)
			local y = a.y * M + origin.Y
			terrain:FillBlock(CFrame.new(cf.Position.X, y - 3 * M, cf.Position.Z) * (cf - cf.Position), Vector3.new(90 * M, 3.5 * M, 12 * M), Mat.Water)
		end
		tick()
	end

	-- 7) congères (murs souples de neige) et arche de grès
	for i = 1, n - 1, 2 do
		local a = S[i]
		local b = S[math.min(n, i + 2)]
		if featureAt(T, a.d, "congeres") then
			for _, side in ipairs({-1, 1}) do
				local cf, len = segFrame(origin, a, b, side * (HALF + 1.2), 0, true)
				terrain:FillBlock(cf * CFrame.new(0, 0.3 * M, 0), Vector3.new(2.2 * M, 2.2 * M, len + 1 * M), Mat.Snow)
			end
		end
		tick()
	end
	for _, f in ipairs(T.features) do
		if f.kind == "arche" then
			local s = S[Track.indexAtD(T, (f.d0 + f.d1) / 2)]
			local p = W(origin, s)
			local cf = CFrame.lookAt(p, p + Vector3.new(math.sin(s.h), 0, math.cos(s.h)))
			terrain:FillBlock(cf * CFrame.new(0, 10 * M, 0), Vector3.new((HALF * 2 + 12) * M, 4 * M, 10 * M), Mat.Sandstone)
			for _, side in ipairs({-1, 1}) do
				terrain:FillBlock(cf * CFrame.new(side * (HALF + 4) * M, 3 * M, 0), Vector3.new(5 * M, 18 * M, 10 * M), Mat.Sandstone)
			end
		end
	end
	if progress then progress(0.8) end

	-- 8) ponts (planches, rondins, toit)
	for i = 1, n - 1 do
		local a, b = S[i], S[i + 1]
		local f = featureAt(T, a.d, "pont") or featureAt(T, a.d, "pontCouvert")
		if f then
			local cf, len = segFrame(origin, a, b, 0, 0, true)
			local deck = newPart(deco, Vector3.new((HALF * 2 + 0.6) * M, 0.6 * M, len + 0.4 * M), cf * CFrame.new(0, -0.3 * M, 0), c3(130, 92, 58), Mat.WoodPlanks, true)
			deck.CanQuery = true
			for _, side in ipairs({-1, 1}) do
				local log = newPart(deco, Vector3.new(len + 0.4 * M, 0.7 * M, 0.7 * M), cf * CFrame.new(side * (HALF + 0.3) * M, 0.35 * M, 0) * CFrame.Angles(0, math.pi / 2, 0),
					c3(110, 76, 46), Mat.Wood, true, Enum.PartType.Cylinder)
				log.CanQuery = false
				if i % 3 == 0 then
					newPart(deco, Vector3.new(0.6, 6, 0.6) * M, cf * CFrame.new(side * (HALF + 0.3) * M, -3 * M, 0), c3(90, 62, 36), Mat.Wood, false)
				end
				if f.kind == "pontCouvert" then
					newPart(deco, Vector3.new(0.4 * M, 4.5 * M, len + 0.4 * M), cf * CFrame.new(side * (HALF + 0.5) * M, 2.6 * M, 0), c3(150, 40, 35), Mat.WoodPlanks, true)
				end
			end
			if f.kind == "pontCouvert" then
				newPart(deco, Vector3.new((HALF * 2 + 2) * M, 0.5 * M, len + 0.4 * M), cf * CFrame.new(0, 5 * M, 0), c3(80, 60, 50), Mat.WoodPlanks, false)
			end
		end
	end

	-- 9) lumières de tunnel
	for i = 1, n - 1, 6 do
		local a = S[i]
		if featureAt(T, a.d, "tunnel") then
			local p = newPart(deco, Vector3.new(1.5, 0.2, 0.6) * M, CFrame.new(W(origin, a, 0, 6.1)), c3(255, 230, 170), Mat.Neon, false)
			local l = Instance.new("PointLight")
			l.Range = 40
			l.Brightness = 1.5
			l.Color = c3(255, 220, 160)
			l.Parent = p
		end
	end

	-- 10) décor (arbres, rochers, maisons) : rien sur la route
	local grid = {}
	local CELL = 20
	for i, s in ipairs(S) do
		local k = math.floor(s.x / CELL) .. "," .. math.floor(s.z / CELL)
		grid[k] = grid[k] or {}
		table.insert(grid[k], i)
	end
	local function clearOfRoad(x, z, margin)
		local gx, gz = math.floor(x / CELL), math.floor(z / CELL)
		for ax = -1, 1 do
			for az = -1, 1 do
				local list = grid[(gx + ax) .. "," .. (gz + az)]
				if list then
					for _, i in ipairs(list) do
						local s = S[i]
						local dx, dz = s.x - x, s.z - z
						if dx * dx + dz * dz < margin * margin then return false end
					end
				end
			end
		end
		return true
	end
	local r = Track.rng(stage.seed * 7 + 3)
	for i = 4, n - 4, 3 do
		local s = S[i]
		local kind = s.deco
		local village = featureAt(T, s.d, "village")
		local lake = featureAt(T, s.d, "lac")
		local fn = DECO[kind]
		if village then fn = DECO.village end
		local density = (kind == "desert" or kind == "canyon") and 0.22 or (lake and 0.04 or 0.5)
		if kind == "plage" then density = 0.18 end
		if village then density = 0.45 end
		for _, side in ipairs({-1, 1}) do
			if fn and r() < density then
				local off = village and r(HALF + 7, HALF + 11) or r(HALF + 4.5, HALF + 26)
				if kind == "plage" and side == -1 then off = r(HALF + 4, HALF + 8) end
				local x, z = s.x + s.nx * off * side, s.z + s.nz * off * side
				if clearOfRoad(x, z, HALF + 3.5) then
					local pos = origin + Vector3.new(x * M, (s.y - 0.4) * M, z * M)
					fn(deco, pos, r, s.h + (side == 1 and math.pi / 2 or -math.pi / 2))
				end
			end
		end
		if i % 30 == 0 then task.wait() end
	end
	if progress then progress(0.9) end

	-- 11) piquets, chevrons et panneaux
	local red, white, yellow, black = c3(210, 35, 40), c3(245, 245, 245), c3(255, 205, 30), c3(20, 20, 20)
	for i = 6, n - 6, 8 do
		local s = S[i]
		for _, side in ipairs({-1, 1}) do
			if not featureAt(T, s.d, "pont") and not featureAt(T, s.d, "pontCouvert") and not featureAt(T, s.d, "tunnel") then
				local p = W(origin, s, side * (HALF + 0.9), 0)
				local a1 = newPart(deco, Vector3.new(0.22, 0.55, 0.22) * M, CFrame.new(p + Vector3.new(0, 0.28 * M, 0)), red, Mat.SmoothPlastic, true)
				newPart(deco, Vector3.new(0.22, 0.55, 0.22) * M, CFrame.new(p + Vector3.new(0, 0.83 * M, 0)), white, Mat.SmoothPlastic, true)
				a1.CanQuery = false
			end
		end
	end
	for _, c in ipairs(T.corners) do
		if c.grade <= 3 or c.hairpin then
			local side = -c.dir -- extérieur du virage
			for i = c.i0 + 1, c.i1, 3 do
				local s = S[i]
				local p = W(origin, s, side * (HALF + 2.0), 0)
				local cf = CFrame.lookAt(p, p - Vector3.new(math.sin(s.h), 0, math.cos(s.h)))
				local board = newPart(deco, Vector3.new(1.6 * M, 0.9 * M, 0.08 * M), cf * CFrame.new(0, 1.0 * M, 0), yellow, Mat.SmoothPlastic, true)
				label(board, Enum.NormalId.Front, c.dir == 1 and "<<<" or ">>>", yellow, black)
				newPart(deco, Vector3.new(0.12, 0.6, 0.12) * M, cf * CFrame.new(0, 0.3 * M, 0), black, Mat.SmoothPlastic, false)
			end
		end
	end
	for _, nt in ipairs(T.notes) do
		if nt.danger or nt.hairpin then
			local i = Track.indexAtD(T, math.max(2, nt.d - 55))
			local s = S[i]
			local p = W(origin, s, -(HALF + 2.2), 0)
			local cf = CFrame.lookAt(p, p - Vector3.new(math.sin(s.h), 0, math.cos(s.h)))
			newPart(deco, Vector3.new(0.12, 1.6, 0.12) * M, cf * CFrame.new(0, 0.8 * M, 0), c3(150, 150, 150), Mat.Metal, true)
			-- triangle jaune (deux biseaux dos à dos)
			local sz = 1.3 * M
			for _, sgn in ipairs({-1, 1}) do
				local w = Instance.new("WedgePart")
				w.Anchored = true
				w.CanCollide = false
				w.Size = Vector3.new(0.08 * M, sz, sz / 2)
				w.Color = yellow
				w.CFrame = cf * CFrame.new(0, 2.2 * M, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, sgn * sz / 4) * CFrame.Angles(0, sgn == 1 and math.pi or 0, 0)
				w.Parent = deco
			end
			local mark = newPart(deco, Vector3.new(0.15, 0.6, 0.12) * M, cf * CFrame.new(0, 2.1 * M, -0.06 * M), black, Mat.SmoothPlastic, false)
			mark.Transparency = 0
		end
	end

	-- 12) arches de départ et d'arrivée
	local function gantry(d, text, isStart)
		local s = S[Track.indexAtD(T, d)]
		local p = W(origin, s)
		local cf = CFrame.lookAt(p, p + Vector3.new(math.sin(s.h), 0, math.cos(s.h)))
		local g = Instance.new("Model")
		g.Name = isStart and "StartGantry" or "FinishGantry"
		g.Parent = folder
		local col = isStart and c3(30, 30, 34) or c3(255, 205, 30)
		for _, side in ipairs({-1, 1}) do
			newPart(g, Vector3.new(0.8, 6.5, 0.8) * M, cf * CFrame.new(side * (HALF + 1.2) * M, 3.25 * M, 0), col, Mat.Metal, true)
		end
		local beam = newPart(g, Vector3.new((HALF * 2 + 3.2) * M, 1.4 * M, 0.6 * M), cf * CFrame.new(0, 6.6 * M, 0), col, Mat.Metal, false)
		label(beam, Enum.NormalId.Front, text, col, isStart and c3(255, 205, 30) or c3(20, 20, 20))
		label(beam, Enum.NormalId.Back, text, col, isStart and c3(255, 205, 30) or c3(20, 20, 20))
		if isStart then
			for k = 1, 3 do
				local l = newPart(g, Vector3.new(0.7, 0.7, 0.3) * M, cf * CFrame.new((k - 2) * 1.2 * M, 5.3 * M, 0.35 * M), c3(60, 0, 0), Mat.Neon, false)
				l.Name = "Light" .. k
			end
		else
			-- damier
			for k = 0, 9 do
				newPart(g, Vector3.new((HALF * 2 + 3) / 10 * M, 0.5 * M, 0.62 * M), cf * CFrame.new(((k + 0.5) / 10 - 0.5) * (HALF * 2 + 3) * M, 5.65 * M, 0),
					(k % 2 == 0) and c3(20, 20, 20) or c3(245, 245, 245), Mat.SmoothPlastic, false)
			end
		end
		-- tentes et barrières
		for _, side in ipairs({-1, 1}) do
			local tp = cf * CFrame.new(side * (HALF + 8) * M, 0, -3 * M)
			newPart(g, Vector3.new(5, 0.3, 5) * M, tp * CFrame.new(0, 3 * M, 0), isStart and c3(220, 40, 40) or c3(40, 90, 200), Mat.Fabric, false)
			for _, cx in ipairs({-2.3, 2.3}) do
				for _, cz in ipairs({-2.3, 2.3}) do
					newPart(g, Vector3.new(0.15, 3, 0.15) * M, tp * CFrame.new(cx * M, 1.5 * M, cz * M), c3(200, 200, 200), Mat.Metal, false)
				end
			end
		end
	end
	gantry(T.startD, "DÉPART", true)
	gantry(T.finishD, "ARRIVÉE", false)

	-- phare au bout de la corniche
	for i = n, 1, -1 do
		if S[i].deco == "phare" then
			local s = S[i]
			local p = W(origin, s, HALF + 14, -0.5)
			for k = 0, 7 do
				newPart(deco, Vector3.new(4 - k * 0.25, 2, 4 - k * 0.25) * M, CFrame.new(p + Vector3.new(0, (1 + k * 2) * M, 0)),
					(k % 2 == 0) and c3(245, 245, 245) or c3(200, 40, 40), Mat.SmoothPlastic, true, Enum.PartType.Cylinder)
			end
			local lamp = newPart(deco, Vector3.new(2, 2, 2) * M, CFrame.new(p + Vector3.new(0, 17 * M, 0)), c3(255, 240, 180), Mat.Neon, false)
			local l = Instance.new("PointLight")
			l.Range = 60
			l.Parent = lamp
			break
		end
	end

	folder:SetAttribute("OriginX", origin.X)
	folder:SetAttribute("OriginY", origin.Y)
	folder:SetAttribute("OriginZ", origin.Z)
	folder:SetAttribute("Ready", true)
	if progress then progress(1) end
	return T, folder
end

-- emplacement des étapes : grille autour du parc (évite les coordonnées trop lointaines)
function Builder.layout()
	local origins = {}
	local slots = {
		Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
		Vector3.new(1, 0, 1), Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1),
	}
	local SPACING = 2700 -- m
	for i, st in ipairs(Config.STAGES) do
		local T = Track.generate(st)
		local x0, x1, z0, z1, y0 = Track.bounds(T)
		local slot = slots[i]
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		-- centre de la boîte du tracé placé sur la case ; altitude au-dessus du parc
		origins[st.id] = Vector3.new((slot.X * SPACING - cx) * M, (20 - y0) * M, (slot.Z * SPACING - cz) * M)
	end
	return origins
end

---------------------------------------------------------------------------
-- Parc d'assistance (zone libre à pied)
---------------------------------------------------------------------------
function Builder.buildHub(parent)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = parent
	terrain:FillBlock(CFrame.new(0, -6 * M, 0), Vector3.new(400 * M, 12 * M, 400 * M), Mat.Grass)
	terrain:FillBlock(CFrame.new(0, -0.6 * M, -20 * M), Vector3.new(90 * M, 1.2 * M, 120 * M), Mat.Asphalt)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(4, 0.4, 4) * M
	spawn.CFrame = CFrame.new(0, 0.2 * M, 30 * M)
	spawn.Color = c3(255, 205, 30)
	spawn.Material = Mat.SmoothPlastic
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local prompts = {}
	local function sign(name, text, pos, color, action, sub)
		local post = newPart(hub, Vector3.new(0.4, 4, 0.4) * M, CFrame.new(pos + Vector3.new(0, 2 * M, 0)), c3(80, 80, 85), Mat.Metal, true)
		local board = newPart(hub, Vector3.new(7, 2.4, 0.3) * M, CFrame.new(pos + Vector3.new(0, 4.6 * M, 0)), color, Mat.SmoothPlastic, true)
		board.Name = name
		label(board, Enum.NormalId.Front, text, color, c3(255, 255, 255))
		label(board, Enum.NormalId.Back, text, color, c3(255, 255, 255))
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = sub or text
		pp.ObjectText = text
		pp.MaxActivationDistance = 14
		pp.RequiresLineOfSight = false
		pp:SetAttribute("Action", action)
		pp.Parent = post
		prompts[#prompts + 1] = pp
		return post
	end
	-- tentes
	local function tent(pos, color, w, d)
		newPart(hub, Vector3.new(w, 0.4, d) * M, CFrame.new(pos + Vector3.new(0, 4 * M, 0)), color, Mat.Fabric, false)
		for _, cx in ipairs({-1, 1}) do
			for _, cz in ipairs({-1, 1}) do
				newPart(hub, Vector3.new(0.2, 4, 0.2) * M, CFrame.new(pos + Vector3.new(cx * (w / 2 - 0.2) * M, 2 * M, cz * (d / 2 - 0.2) * M)), c3(220, 220, 220), Mat.Metal, true)
			end
		end
	end
	tent(Vector3.new(-30, 0, 0) * M, c3(200, 40, 45), 14, 10)
	tent(Vector3.new(30, 0, 0) * M, c3(40, 90, 200), 14, 10)
	tent(Vector3.new(-30, 0, -35) * M, c3(250, 190, 30), 12, 10)
	sign("Garage", "MON GARAGE", Vector3.new(-30, 0, 8) * M, c3(40, 90, 200), "garage", "Ouvrir le garage")
	sign("Shop", "BOUTIQUE", Vector3.new(30, 0, 8) * M, c3(200, 40, 45), "shop", "Ouvrir la boutique")
	sign("Crate", "CAISSE DE PERFORMANCE 2 500 CR", Vector3.new(30, 0, -12) * M, c3(120, 60, 180), "crate", "Ouvrir une caisse")
	sign("Contracts", "CONTRATS", Vector3.new(-30, 0, -26) * M, c3(250, 150, 30), "contracts", "Voir les contrats")
	sign("Menu", "MENU", Vector3.new(0, 0, 18) * M, c3(30, 30, 34), "menu", "Ouvrir le menu")

	-- départs des étapes, à 75 m de l'apparition
	for i, st in ipairs(Config.STAGES) do
		local x = (i - (#Config.STAGES + 1) / 2) * 11
		local pad = newPart(hub, Vector3.new(8, 0.3, 8) * M, CFrame.new(Vector3.new(x, 0.15, -45) * M), st.event and c3(250, 150, 30) or c3(255, 205, 30), Mat.Neon, true)
		pad.Name = "Pad_" .. st.id
		sign("StageSign_" .. st.id, st.name, Vector3.new(x, 0, -50) * M, c3(30, 30, 34), "stage:" .. st.id, "Prendre le départ")
	end
	newPart(hub, Vector3.new(84, 1.2, 1.2) * M, CFrame.new(Vector3.new(0, 7.5, -54) * M), c3(30, 30, 34), Mat.Metal, false)
	local banner = newPart(hub, Vector3.new(40, 3, 0.4) * M, CFrame.new(Vector3.new(0, 9.6, -54) * M), c3(255, 205, 30), Mat.SmoothPlastic, false)
	label(banner, Enum.NormalId.Back, "ÉTAPES — PRENDRE LE DÉPART", c3(255, 205, 30), c3(20, 20, 20))
	label(banner, Enum.NormalId.Front, "PISTE POUSSIÈRE", c3(255, 205, 30), c3(20, 20, 20))

	-- vitrine des voitures
	local show = Instance.new("Folder")
	show.Name = "Showroom"
	show.Parent = hub
	for i, car in ipairs(Config.CARS) do
		local ok, model = pcall(Cars.build, car, nil, {anchored = true})
		if ok then
			local row = (i - 1) % 6
			local col = math.floor((i - 1) / 6)
			local pos = Vector3.new(-40 + row * 16, 0, 55 + col * 18) * M
			model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(200), 0))
			model.Parent = show
			local pl = newPart(show, Vector3.new(14, 0.3, 12) * M, CFrame.new(pos + Vector3.new(0, 0.15 * M, 0)), c3(60, 60, 66), Mat.SmoothPlastic, true)
			label(pl, Enum.NormalId.Top, car.name .. "  " .. car.cls, c3(60, 60, 66), c3(255, 205, 30))
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Voir dans le garage"
			pp.ObjectText = car.name
			pp.MaxActivationDistance = 16
			pp.RequiresLineOfSight = false
			pp:SetAttribute("Action", "garage:" .. car.id)
			pp.Parent = pl
		end
	end

	-- quelques sapins autour
	local r = Track.rng(99)
	for _ = 1, 60 do
		local a = r(0, math.pi * 2)
		local d = r(110, 180)
		DECO.pins(hub, Vector3.new(math.cos(a) * d, 0, math.sin(a) * d) * M, r)
	end
	return hub, spawn
end

return Builder

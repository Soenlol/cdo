-- Génération du tracé d'une étape (pur : aucune API Roblox)
-- Le même code tourne sur le serveur (construction) et sur le client (copilote, chrono, pénalités).

local Config = require(script.Parent.Config)

local Track = {}
local STEP = Config.STEP
local HALF = Config.HALF

-- générateur pseudo-aléatoire déterministe
function Track.rng(seed)
	local s = (seed % 2147483646) + 1
	return function(a, b)
		s = (s * 16807) % 2147483647
		local r = (s - 1) / 2147483646
		if a then return a + (b - a) * r end
		return r
	end
end

local function lerp(a, b, t) return a + (b - a) * t end

local function elevAt(elev, d)
	if d <= elev[1][1] then return elev[1][2] end
	for i = 1, #elev - 1 do
		local a, b = elev[i], elev[i + 1]
		if d <= b[1] then
			local t = (d - a[1]) / (b[1] - a[1])
			t = (1 - math.cos(t * math.pi)) / 2
			return lerp(a[2], b[2], t)
		end
	end
	return elev[#elev][2]
end

local function gradeOf(radius, angle)
	local g
	if radius >= 120 then g = 6 elseif radius >= 80 then g = 5 elseif radius >= 55 then g = 4
	elseif radius >= 38 then g = 3 elseif radius >= 24 then g = 2 else g = 1 end
	if angle < 25 and g < 6 then g = g + 1 end
	return g
end
Track.gradeOf = gradeOf

local HAZARDS = {
	saut = {text = "Crête", tip = "Crête : relâchez, gardez le droit"},
	gue = {text = "Gué", tip = "Gué : levez le pied, la boue glisse"},
	pont = {text = "Pont", tip = "Pont étroit : restez au centre"},
	pontCouvert = {text = "Pont couvert", tip = "Pont étroit : restez au centre"},
	tunnel = {text = "Tunnel", tip = "Tunnel : gardez la ligne"},
	congeres = {text = "Congères", tip = "Congères : appuyez-vous dessus, sans prendre trop large"},
	lac = {text = "Glace !", tip = "Glace : gestes doux, longues glissades"},
	arche = {text = "Arche", tip = nil},
	plage = {text = "Sable", tip = "Sable : gardez de l'élan"},
}
Track.HAZARDS = HAZARDS

function Track.generate(stage)
	local S = {}
	local x, z, h = 0, 0, 0
	local d = 0
	local surf = "Ground"
	local deco = stage.deco
	local corners = {}
	local features = {}

	local function push(curv, feat, cornerId)
		local s = {x = x, y = 0, z = z, h = h, d = d, surf = surf, curv = curv, feat = feat, corner = cornerId, deco = deco}
		S[#S + 1] = s
	end
	push(0, nil, nil)

	local function addFeature(f, d0, d1)
		if not f then return end
		local last = features[#features]
		if last and last.kind == f and math.abs(last.d1 - d0) < 0.01 then
			last.d1 = d1
		else
			features[#features + 1] = {kind = f, d0 = d0, d1 = d1}
		end
	end

	local path = {}
	for _, c in ipairs(stage.path) do path[#path + 1] = c end
	path[#path + 1] = {"S", 70} -- dégagement après l'arrivée

	for _, c in ipairs(path) do
		local k = c[1]
		if k == "surf" then
			surf = c[2]
		elseif k == "deco" then
			deco = c[2]
		elseif k == "S" then
			local n = math.max(1, math.floor(c[2] / STEP + 0.5))
			local d0 = d
			for _ = 1, n do
				x = x + math.sin(h) * STEP
				z = z + math.cos(h) * STEP
				d = d + STEP
				push(0, c.f, nil)
			end
			addFeature(c.f, d0, d)
		else
			local dir, angle, radius, hairpin
			if k == "HL" or k == "HR" then
				dir = (k == "HL") and 1 or -1
				angle, radius, hairpin = 175, 9, true
			else
				dir = (k == "L") and 1 or -1
				angle, radius = c[2], c[3]
			end
			local arc = math.rad(angle) * radius
			local n = math.max(1, math.floor(arc / STEP + 0.5))
			local dh = math.rad(angle) / n * dir
			local stepLen = arc / n
			local id = #corners + 1
			local d0 = d
			local i0 = #S + 1
			for _ = 1, n do
				-- intégration au point milieu pour suivre l'arc
				local hm = h + dh / 2
				x = x + math.sin(hm) * stepLen
				z = z + math.cos(hm) * stepLen
				h = h + dh
				d = d + stepLen
				push(dir / radius, c.f, id)
			end
			corners[id] = {id = id, dir = dir, angle = angle, radius = radius, hairpin = hairpin,
				d0 = d0, d1 = d, i0 = i0, i1 = #S, grade = gradeOf(radius, angle)}
			addFeature(c.f, d0, d)
		end
	end

	-- altitude
	for _, s in ipairs(S) do s.y = elevAt(stage.elev, s.d) end
	for _, f in ipairs(features) do
		if f.kind == "saut" then
			-- crête : montée douce puis rupture nette => la voiture décolle
			local peak = f.d0 + (f.d1 - f.d0) * 0.6
			for _, s in ipairs(S) do
				local u = s.d - peak
				if u > -18 and u <= 0 then
					s.y = s.y + 2.4 * (1 - math.cos((u + 18) / 18 * math.pi)) / 2
				elseif u > 0 and u < 10 then
					s.y = s.y + 2.4 * (1 - u / 10) ^ 2
				end
			end
		elseif f.kind == "pont" or f.kind == "pontCouvert" or f.kind == "lac" then
			local y0, y1
			for _, s in ipairs(S) do
				if s.d >= f.d0 and not y0 then y0 = s.y end
				if s.d <= f.d1 then y1 = s.y end
			end
			for _, s in ipairs(S) do
				if s.d >= f.d0 and s.d <= f.d1 then
					s.y = lerp(y0, y1, (s.d - f.d0) / math.max(1, f.d1 - f.d0))
				end
			end
		end
	end

	-- vecteurs gauche
	for _, s in ipairs(S) do
		s.nx, s.nz = math.cos(s.h), -math.sin(s.h)
	end

	local T = {stage = stage, S = S, corners = corners, features = features}
	T.length = d
	T.finishD = d - 60
	T.startD = Config.START_D
	T.startIdx = math.floor(Config.START_D / STEP) + 1
	T.finishIdx = 1
	for i, s in ipairs(S) do
		if s.d <= T.finishD then T.finishIdx = i end
	end
	T.stageLength = T.finishD - T.startD

	-- points de passage
	local nCP = math.max(4, math.floor(T.stageLength / 125 + 0.5))
	T.cps = {}
	for k = 1, nCP do
		local cd = T.startD + T.stageLength * k / (nCP + 1)
		T.cps[k] = Track.indexAtD(T, cd)
	end

	-- pièces
	local rnd = Track.rng(stage.seed)
	T.coins = {}
	local span = T.finishD - 40 - 60
	for k = 1, stage.coins do
		local cd = 60 + (k - 0.5) * span / stage.coins
		local i = Track.indexAtD(T, cd)
		local s = S[i]
		local off = rnd(-2.6, 2.6)
		T.coins[k] = {i = i, x = s.x + s.nx * off, y = s.y + 1.3, z = s.z + s.nz * off}
	end

	Track.buildNotes(T)
	T.par = Track.parTime(T)
	T.medals = {}
	for _, m in ipairs(Config.MEDALS) do
		T.medals[m] = math.floor(T.par * Config.MEDAL_FACTORS[m] * 2 + 0.5) / 2
	end
	return T
end

function Track.indexAtD(T, d)
	local i = math.floor(d / STEP) + 1
	local S = T.S
	i = math.max(1, math.min(#S, i))
	while i < #S and S[i + 1].d <= d do i = i + 1 end
	while i > 1 and S[i].d > d do i = i - 1 end
	return i
end

-- annonces du copilote
function Track.buildNotes(T)
	local notes = {}
	for _, c in ipairs(T.corners) do
		if c.angle >= 12 then
			local dirTxt = c.dir == 1 and "Gauche" or "Droite"
			local n = {d = c.d0, dEnd = c.d1, kind = "corner", dir = c.dir, grade = c.grade, corner = c.id}
			if c.hairpin then
				n.text = "Épingle " .. string.lower(dirTxt)
				n.label = "DIFFICILE"
				n.tight = true
				n.tip = "Épingle : freinez tôt, puis utilisez le frein à main"
				n.hairpin = true
			else
				n.text = dirTxt .. " " .. c.grade
				if c.angle >= 100 and c.grade <= 3 then n.text = n.text .. " long" end
				if c.grade >= 5 then n.label = "LÉGER"
				elseif c.grade <= 2 then n.label = "DIFFICILE"; n.tight = true
				else n.label = "" end
			end
			notes[#notes + 1] = n
		end
	end
	for _, f in ipairs(T.features) do
		local hz = HAZARDS[f.kind]
		if hz then
			notes[#notes + 1] = {d = f.d0, dEnd = f.d1, kind = "hazard", text = hz.text, label = "DANGER", tip = hz.tip, danger = true, feat = f.kind}
		end
	end
	table.sort(notes, function(a, b) return a.d < b.d end)
	-- enchaînements et lignes droites
	local out = {}
	for i, n in ipairs(notes) do
		local nx = notes[i + 1]
		if nx and n.kind == "corner" and nx.kind == "corner" and nx.d - n.dEnd < 25 then
			n.puis = nx.text
		end
		out[#out + 1] = n
		local nextD = nx and nx.d or T.finishD
		if n.kind == "corner" and nextD - n.dEnd > 110 then
			out[#out + 1] = {d = n.dEnd + 5, dEnd = nextD, kind = "flat", text = "À fond", label = "", dir = 0}
		end
	end
	T.notes = out
end

-- prochaine annonce à partir de la distance d (avec anticipation en mètres)
function Track.noteAt(T, d, ahead)
	for _, n in ipairs(T.notes) do
		if n.dEnd >= d and n.d <= d + ahead then return n end
		if n.d > d + ahead then break end
	end
	return nil
end

-- échantillon le plus proche (recherche locale autour de hint)
function Track.nearest(T, px, pz, hint)
	local S = T.S
	local best, bd = hint or 1, math.huge
	local i0, i1 = 1, #S
	if hint then i0 = math.max(1, hint - 25); i1 = math.min(#S, hint + 45) end
	for i = i0, i1 do
		local s = S[i]
		local dx, dz = px - s.x, pz - s.z
		local dd = dx * dx + dz * dz
		if dd < bd then bd = dd; best = i end
	end
	if hint and bd > 900 then return Track.nearest(T, px, pz, nil) end
	local s = S[best]
	local lat = (px - s.x) * s.nx + (pz - s.z) * s.nz
	return best, lat, s
end

-- temps de référence (passe avant/arrière sur la vitesse limite de chaque échantillon)
function Track.parTime(T)
	local S = T.S
	local mu, g = Config.BASE_MU, Config.G
	local m, P, vmax = 1090, 470 * 735.5 * 0.82, 195 / 3.6
	local cd = P / (vmax ^ 3)
	local n = #S
	local cap = {}
	for i = 1, n do
		local s = S[i]
		local sf = Config.SURFACES[s.surf] or Config.DEFAULT_SURFACE
		local c = vmax
		if s.curv ~= 0 then c = math.min(c, math.sqrt(mu * sf.grip * g * 0.9 / math.abs(s.curv))) end
		if s.feat == "saut" then c = math.min(c, 30) end
		cap[i] = c
	end
	local v = {}
	v[1] = 0
	for i = 2, n do
		local sf = Config.SURFACES[S[i].surf] or Config.DEFAULT_SURFACE
		local pv = v[i - 1]
		local a = math.min(mu * sf.grip * g, P / (m * math.max(pv, 3))) - cd * pv * pv / m - sf.drag
		v[i] = math.min(cap[i], math.sqrt(math.max(0, pv * pv + 2 * math.max(a, 0.2) * STEP)))
	end
	for i = n - 1, 1, -1 do
		local sf = Config.SURFACES[S[i].surf] or Config.DEFAULT_SURFACE
		local a = mu * sf.grip * g * 1.25
		v[i] = math.min(v[i], math.sqrt(v[i + 1] ^ 2 + 2 * a * STEP))
	end
	local t = 0
	for i = 2, n do
		local s = S[i]
		if s.d > T.startD and s.d <= T.finishD then
			local dd = s.d - S[i - 1].d
			t = t + dd / math.max(1, (v[i] + v[i - 1]) / 2)
		end
	end
	return t
end

-- distance minimale entre deux portions éloignées du tracé (contrôle des croisements)
function Track.selfCheck(T)
	local S = T.S
	local minD, at = math.huge, nil
	for i = 1, #S, 2 do
		for j = i + 40, #S, 2 do
			local dx, dz = S[i].x - S[j].x, S[i].z - S[j].z
			local dd = math.sqrt(dx * dx + dz * dz)
			if dd < minD then minD = dd; at = {i, j} end
		end
	end
	return minD, at
end

function Track.bounds(T)
	local x0, x1, z0, z1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, s in ipairs(T.S) do
		x0 = math.min(x0, s.x); x1 = math.max(x1, s.x)
		z0 = math.min(z0, s.z); z1 = math.max(z1, s.z)
		y0 = math.min(y0, s.y); y1 = math.max(y1, s.y)
	end
	return x0, x1, z0, z1, y0, y1
end

return Track

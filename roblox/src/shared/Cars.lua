-- Construction des modèles de voitures en blocs (low-poly)
-- Utilisé par le serveur (voiture de course, vitrine) et par le client (fantôme, replay)

local Config = require(script.Parent.Config)

local Cars = {}
local M = Config.M

-- gabarits : longueur, largeur, hauteur caisse, hauteur cabine, longueur cabine, décalage cabine, rayon roue, garde au sol
local SHAPES = {
	citadine = {len = 3.7, wid = 1.65, body = 0.75, cab = 0.75, cabLen = 1.9, cabOff = -0.15, wheel = 0.33, ride = 0.42, wb = 2.3},
	coupe    = {len = 3.9, wid = 1.6, body = 0.6, cab = 0.55, cabLen = 1.6, cabOff = -0.2, wheel = 0.32, ride = 0.30, wb = 2.25},
	mini     = {len = 3.1, wid = 1.45, body = 0.65, cab = 0.62, cabLen = 1.6, cabOff = -0.1, wheel = 0.28, ride = 0.28, wb = 2.05},
	compacte = {len = 4.0, wid = 1.75, body = 0.7, cab = 0.62, cabLen = 1.9, cabOff = -0.2, wheel = 0.34, ride = 0.34, wb = 2.4},
	cubique  = {len = 4.2, wid = 1.7, body = 0.72, cab = 0.62, cabLen = 1.8, cabOff = -0.15, wheel = 0.33, ride = 0.32, wb = 2.55},
	berline  = {len = 4.5, wid = 1.75, body = 0.72, cab = 0.66, cabLen = 2.4, cabOff = -0.1, wheel = 0.34, ride = 0.34, wb = 2.6},
	buggy    = {len = 4.1, wid = 2.0, body = 0.5, cab = 0.9, cabLen = 1.8, cabOff = 0.1, wheel = 0.45, ride = 0.55, wb = 2.8, open = true},
	groupeb  = {len = 4.0, wid = 1.85, body = 0.68, cab = 0.58, cabLen = 1.7, cabOff = -0.1, wheel = 0.35, ride = 0.30, wb = 2.3, wing = true},
	rally1   = {len = 4.2, wid = 1.88, body = 0.72, cab = 0.62, cabLen = 1.9, cabOff = -0.1, wheel = 0.35, ride = 0.32, wb = 2.6, wing = true},
	suv      = {len = 4.9, wid = 1.98, body = 0.95, cab = 0.72, cabLen = 2.6, cabOff = -0.15, wheel = 0.40, ride = 0.42, wb = 2.95},
	truck    = {len = 5.4, wid = 2.2, body = 0.85, cab = 0.8, cabLen = 1.9, cabOff = 0.2, wheel = 0.55, ride = 0.62, wb = 3.3, open = false, bed = true},
	supercar = {len = 4.3, wid = 1.9, body = 0.55, cab = 0.5, cabLen = 1.7, cabOff = -0.15, wheel = 0.34, ride = 0.24, wb = 2.5, wing = true},
}
Cars.SHAPES = SHAPES

function Cars.shapeOf(car)
	return SHAPES[car.shape] or SHAPES.compacte
end

local function c3(rgb) return Color3.fromRGB(rgb[1], rgb[2], rgb[3]) end

local function part(props)
	local p = Instance.new(props.Class or "Part")
	props.Class = nil
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
	return w
end

-- construit le modèle ; anchored = vitrine / fantôme
function Cars.build(car, paintRGB, opts)
	opts = opts or {}
	local sh = Cars.shapeOf(car)
	local col = c3(paintRGB or car.color)
	local model = Instance.new("Model")
	model.Name = car.name

	local len, wid = sh.len * M, sh.wid * M
	local bodyH, cabH = sh.body * M, sh.cab * M
	local ride = (sh.ride + sh.wheel * 0.2) * M

	-- châssis = la seule pièce physique (collision avec le décor)
	local chassis = part({Name = "Chassis", Size = Vector3.new(wid * 0.92, bodyH * 0.85, len * 0.96),
		Transparency = 1, CanCollide = true, CanQuery = false, Massless = false})
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.05, 0, 100, 1)
	chassis.CFrame = CFrame.new(0, ride + bodyH / 2, 0)
	chassis.Parent = model
	model.PrimaryPart = chassis

	local base = chassis.CFrame
	local function add(name, size, offset, color, material, extra)
		local p = part({Name = name, Size = size, Color = color or col, CFrame = base * offset})
		if material then p.Material = material end
		if extra then for k, v in pairs(extra) do p[k] = v end end
		p.Parent = model
		weld(chassis, p)
		return p
	end

	local dark = Color3.fromRGB(28, 28, 30)
	local glass = Color3.fromRGB(150, 200, 235)
	local white = Color3.fromRGB(245, 245, 245)

	-- caisse
	add("Body", Vector3.new(wid, bodyH, len), CFrame.new(0, 0, 0))
	add("Bumper", Vector3.new(wid * 1.01, bodyH * 0.35, 0.25 * M), CFrame.new(0, -bodyH * 0.3, -len / 2), dark)
	add("BumperR", Vector3.new(wid * 1.01, bodyH * 0.35, 0.25 * M), CFrame.new(0, -bodyH * 0.3, len / 2), dark)
	-- plaque numéro portière
	add("Number", Vector3.new(wid * 1.02, bodyH * 0.55, 0.9 * M), CFrame.new(0, 0, -sh.cabOff * M), white)
	-- phares
	for _, sx in ipairs({-1, 1}) do
		add("Light", Vector3.new(0.35 * M, 0.18 * M, 0.06 * M), CFrame.new(sx * wid * 0.32, bodyH * 0.1, -len / 2 - 0.02 * M),
			Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
		add("Tail", Vector3.new(0.35 * M, 0.14 * M, 0.06 * M), CFrame.new(sx * wid * 0.34, bodyH * 0.15, len / 2 + 0.02 * M),
			Color3.fromRGB(200, 20, 20), Enum.Material.Neon)
	end

	-- cabine (ou arceau pour le buggy)
	local cabY = bodyH / 2 + cabH / 2
	local cabZ = sh.cabOff * M
	if sh.open then
		for _, sx in ipairs({-1, 1}) do
			for _, sz in ipairs({-1, 1}) do
				add("Cage", Vector3.new(0.12 * M, cabH, 0.12 * M), CFrame.new(sx * wid * 0.38, cabY, cabZ + sz * sh.cabLen * M * 0.45), dark)
			end
		end
		add("CageTop", Vector3.new(wid * 0.8, 0.1 * M, sh.cabLen * M), CFrame.new(0, bodyH / 2 + cabH, cabZ), dark)
		add("Windshield", Vector3.new(wid * 0.7, cabH * 0.6, 0.04 * M), CFrame.new(0, cabY, cabZ - sh.cabLen * M * 0.45) * CFrame.Angles(math.rad(-15), 0, 0),
			glass, Enum.Material.Glass, {Transparency = 0.6})
	else
		add("Cabin", Vector3.new(wid * 0.86, cabH, sh.cabLen * M), CFrame.new(0, cabY, cabZ))
		add("Roof", Vector3.new(wid * 0.8, 0.06 * M, sh.cabLen * M * 0.8), CFrame.new(0, bodyH / 2 + cabH + 0.03 * M, cabZ), white)
		add("Windshield", Vector3.new(wid * 0.8, cabH * 0.8, 0.05 * M), CFrame.new(0, cabY, cabZ - sh.cabLen * M / 2 - 0.01 * M),
			glass, Enum.Material.Glass, {Transparency = 0.25})
		add("RearGlass", Vector3.new(wid * 0.78, cabH * 0.7, 0.05 * M), CFrame.new(0, cabY, cabZ + sh.cabLen * M / 2 + 0.01 * M),
			glass, Enum.Material.Glass, {Transparency = 0.3})
		for _, sx in ipairs({-1, 1}) do
			add("SideGlass", Vector3.new(0.05 * M, cabH * 0.7, sh.cabLen * M * 0.8), CFrame.new(sx * (wid * 0.43 + 0.01 * M), cabY, cabZ),
				glass, Enum.Material.Glass, {Transparency = 0.3})
		end
	end
	if sh.wing then
		add("Wing", Vector3.new(wid * 0.95, 0.06 * M, 0.45 * M), CFrame.new(0, bodyH / 2 + cabH * 0.75, len / 2 - 0.3 * M), dark)
		for _, sx in ipairs({-1, 1}) do
			add("WingLeg", Vector3.new(0.06 * M, cabH * 0.6, 0.2 * M), CFrame.new(sx * wid * 0.35, bodyH / 2 + cabH * 0.4, len / 2 - 0.3 * M), dark)
		end
	end
	if sh.bed then
		add("Bed", Vector3.new(wid * 0.9, 0.5 * M, len * 0.32), CFrame.new(0, bodyH / 2 + 0.25 * M, len * 0.3), dark)
		add("Spare", Vector3.new(wid * 0.5, 0.35 * M, 0.9 * M), CFrame.new(0, bodyH / 2 + 0.6 * M, len * 0.32), dark)
	end
	-- prise d'air / rampe de phares pour les voitures de rallye
	if car.cls == "A" or car.cls == "S" then
		add("Scoop", Vector3.new(wid * 0.3, 0.12 * M, 0.6 * M), CFrame.new(0, bodyH / 2 + cabH + 0.08 * M, cabZ), dark)
	end

	-- sièges (le conducteur s'assoit à gauche, le copilote à droite)
	local seatY = -bodyH * 0.4
	local seatZ = cabZ + 0.15 * M
	local function seat(name, sx)
		local s = part({Class = "Seat", Name = name, Size = Vector3.new(0.6 * M, 0.2 * M, 0.6 * M), Transparency = 1,
			CFrame = base * CFrame.new(sx * wid * 0.22, seatY, seatZ)})
		s.CanTouch = false
		s.Parent = model
		weld(chassis, s)
		return s
	end
	seat("DriverSeat", -1)
	seat("PassengerSeat", 1)

	-- tableau de bord / volant (repère pour la vue cockpit)
	local dashZ = cabZ - sh.cabLen * M * 0.38
	add("Dash", Vector3.new(wid * 0.82, 0.25 * M, 0.3 * M), CFrame.new(0, bodyH * 0.45, dashZ), dark)
	add("SteeringWheel", Vector3.new(0.38 * M, 0.38 * M, 0.05 * M), CFrame.new(-wid * 0.22, bodyH * 0.55 + 0.15 * M, dashZ + 0.25 * M) * CFrame.Angles(math.rad(-20), 0, 0), dark)
	local eye = Instance.new("Attachment")
	eye.Name = "Eye"
	eye.Position = Vector3.new(-wid * 0.22, bodyH * 0.55 + 0.6 * M, cabZ + 0.05 * M)
	eye.Parent = chassis

	-- roues (soudées, l'animation est faite côté client)
	local wheelW = 0.26 * M
	local rad = sh.wheel * M
	local zF, zR = -sh.wb * M / 2, sh.wb * M / 2
	local wx = wid / 2 - wheelW * 0.3
	local wy = -(ride + bodyH / 2) + rad
	local names = {{"FL", -1, zF}, {"FR", 1, zF}, {"RL", -1, zR}, {"RR", 1, zR}}
	for _, w in ipairs(names) do
		local wp = part({Class = "Part", Name = "Wheel" .. w[1], Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(wheelW, rad * 2, rad * 2), Color = dark, Material = Enum.Material.SmoothPlastic})
		wp.CFrame = base * CFrame.new(w[2] * wx, wy, w[3])
		wp.Parent = model
		local hub = part({Name = "Hub" .. w[1], Size = Vector3.new(wheelW * 1.05, rad * 0.9, rad * 0.9), Color = Color3.fromRGB(190, 190, 195),
			CFrame = wp.CFrame})
		hub.Shape = Enum.PartType.Cylinder
		hub.Parent = model
		weld(wp, hub)
		local m6 = Instance.new("Weld")
		m6.Name = "Joint" .. w[1]
		m6.Part0 = chassis
		m6.Part1 = wp
		m6.C0 = CFrame.new(w[2] * wx, wy, w[3])
		m6.Parent = wp
		local at = Instance.new("Attachment")
		at.Name = "Mount" .. w[1]
		at.Position = Vector3.new(w[2] * wx, wy + rad, w[3])
		at.Parent = chassis
		-- poussière
		if w[1] == "RL" or w[1] == "RR" then
			local pa = Instance.new("Attachment")
			pa.Name = "Dust" .. w[1]
			pa.Position = Vector3.new(w[2] * wx, wy - rad * 0.6, w[3] + rad)
			pa.Parent = chassis
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "Dust"
			pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
			pe.Rate = 0
			pe.Lifetime = NumberRange.new(0.8, 1.6)
			pe.Speed = NumberRange.new(2, 6)
			pe.SpreadAngle = Vector2.new(25, 25)
			pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 6)})
			pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)})
			pe.Acceleration = Vector3.new(0, 2, 0)
			pe.Drag = 1.5
			pe.EmissionDirection = Enum.NormalId.Back
			pe.Parent = pa
			local mud = Instance.new("ParticleEmitter")
			mud.Name = "Chunks"
			mud.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			mud.Rate = 0
			mud.Lifetime = NumberRange.new(0.4, 0.8)
			mud.Speed = NumberRange.new(6, 14)
			mud.SpreadAngle = Vector2.new(35, 35)
			mud.Size = NumberSequence.new(0.4)
			mud.Acceleration = Vector3.new(0, -30, 0)
			mud.EmissionDirection = Enum.NormalId.Back
			mud.Parent = pa
		end
	end

	model:SetAttribute("CarId", car.id)
	model:SetAttribute("WheelRadius", rad)
	model:SetAttribute("Ride", ride)

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = opts.anchored == true
			if opts.ghost and d.Transparency < 1 then d.Transparency = 0.6 end
			if opts.ghost or opts.anchored then
				d.CanCollide = false
			end
		end
	end
	return model
end

-- positions des roues dans le repère du châssis (pour la suspension par rayons)
function Cars.wheelMounts(model)
	local out = {}
	local ch = model.PrimaryPart
	for _, n in ipairs({"FL", "FR", "RL", "RR"}) do
		local at = ch:FindFirstChild("Mount" .. n)
		out[#out + 1] = {name = n, pos = at.Position, front = (n == "FL" or n == "FR")}
	end
	return out
end

function Cars.paint(model, rgb)
	local col = c3(rgb)
	for _, n in ipairs({"Body", "Cabin"}) do
		local p = model:FindFirstChild(n)
		if p then p.Color = col end
	end
end

return Cars

-- Modèle de conduite (pur : aucune API Roblox, testable hors du jeu)
-- Modèle « bicyclette » à deux essieux avec pneus à saturation, cercle d'adhérence,
-- transfert de charge, frein à main, turbo, hybride et boîte de vitesses.
-- Repère voiture : vF = vitesse avant (m/s), vL = vitesse vers la gauche, r = lacet (rad/s, + = gauche)

local Physics = {}

local G = 9.81
local SHIFT_FRACS = {
	[1] = {1.0},
	[4] = {0.40, 0.70, 0.88, 1.0},
	[5] = {0.36, 0.67, 0.82, 0.92, 1.0},
	[6] = {0.30, 0.52, 0.68, 0.81, 0.92, 1.0},
}
local EFF = 0.82           -- rendement de transmission
local HB_GAIN = 1.8        -- les roues arrière bloquées creusent le gravier
local SHIFT_TIME = 0.18

local function clamp(v, a, b)
	if v < a then return a elseif v > b then return b end
	return v
end
local function sign(v)
	if v > 0 then return 1 elseif v < 0 then return -1 end
	return 0
end
Physics.clamp = clamp

-- prépare les constantes dérivées d'une voiture
function Physics.prepare(car, baseMu, longMu)
	local p = {}
	p.car = car
	p.m = car.kg
	p.L = car.wheelbase or 2.5
	-- a = distance CG -> essieu avant, b = CG -> essieu arrière ; car.rear = part de masse à l'arrière
	p.a = p.L * car.rear
	p.b = p.L - p.a
	p.h = 0.45 + car.travel * 0.4
	p.Iz = p.m * p.a * p.b * 1.05
	p.P = car.ch * 735.5 * EFF
	p.Fmax = car.nm * 40
	p.vmax = car.vmax / 3.6
	p.cd = p.P / (p.vmax * p.vmax * p.vmax)
	p.brake = car.brake or 18
	p.mu = (baseMu or 1.6) * (car.grip or 1)
	p.longMu = longMu or 1.45
	local fr = SHIFT_FRACS[car.gears or 5] or SHIFT_FRACS[5]
	p.tops = {}
	for i, f in ipairs(fr) do p.tops[i] = f * p.vmax end
	p.vrev = p.vmax * 0.43
	p.hybridP = car.hybrid and car.hybrid.ch * 735.5 * EFF or 0
	return p
end

function Physics.newState()
	return {
		vF = 0, vL = 0, r = 0, steer = 0, ax = 0,
		gear = 1, shiftT = 0, rpm = 0.1, reverse = false,
		boost = 0, boost2 = 0, battery = 0.3, hybridOn = false,
		slipR = 0, slipF = 0, spin = 0, manual = false,
		temps = {oil = 40, water = 45, box = 35}, fuel = 1.0,
	}
end

local function tire(alpha)
	-- courbe de pneu : pic vers 12°, retombe à ~85 % en glissade
	return math.sin(1.5 * math.atan(8 * alpha))
end

-- angle de braquage maximal selon la vitesse (clavier)
function Physics.maxSteer(v, sens)
	return (0.58 / (1 + math.abs(v) / 24)) * (sens or 1)
end

-- inp : throttle 0..1, brake 0..1, steer -1..1 (+ = gauche), hb bool, shift (+1/-1/0)
-- surf : gF, gR (adhérence avant / arrière), drag (m/s²), sandF (multiplicateur de drag)
function Physics.step(p, st, inp, surf, dt)
	local car = p.car
	local m = p.m
	local v = math.sqrt(st.vF * st.vF + st.vL * st.vL)

	-- direction progressive
	local target = clamp(inp.steer, -1, 1) * Physics.maxSteer(v, inp.sens)
	local rate = (math.abs(target) > math.abs(st.steer)) and 3.2 or 5.0
	local ds = target - st.steer
	st.steer = st.steer + clamp(ds, -rate * dt, rate * dt)

	-- marche arrière automatique : frein tenu quasi à l'arrêt
	if inp.brake > 0.5 and st.vF < 0.8 and inp.throttle < 0.1 then
		st.reverse = true
	elseif inp.throttle > 0.1 then
		st.reverse = false
	end

	-- boîte de vitesses
	local tops = p.tops
	local ng = #tops
	if st.shiftT > 0 then st.shiftT = st.shiftT - dt end
	local spd = math.abs(st.vF)
	if st.reverse then
		st.gear = -1
	elseif st.manual then
		if st.gear < 1 then st.gear = 1 end
		if inp.shift == 1 and st.gear < ng then st.gear = st.gear + 1; st.shiftT = SHIFT_TIME end
		if inp.shift == -1 and st.gear > 1 then st.gear = st.gear - 1; st.shiftT = SHIFT_TIME * 0.5 end
	else
		if st.gear < 1 then st.gear = 1 end
		local g = st.gear
		if g < ng and spd > tops[g] * 0.985 and inp.throttle > 0.05 then
			st.gear = g + 1; st.shiftT = SHIFT_TIME
		elseif g > 1 then
			local down = tops[g - 1] * ((inp.brake > 0.1 or inp.hb) and 1.17 or 0.8)
			if spd < down then st.gear = g - 1 end
		end
	end
	local gTop = st.gear >= 1 and tops[st.gear] or p.vrev
	local gLow = (st.gear > 1) and tops[st.gear - 1] * 0.55 or 0
	st.rpm = clamp(0.12 + 0.88 * (spd - gLow) / math.max(1, gTop - gLow), 0.12, 1.05)

	-- turbo(s) et hybride
	local thr = inp.throttle
	if car.turbo then
		local want = (thr > 0.3 and st.rpm > 0.35) and 1 or 0
		local k = want > st.boost and dt / car.turbo.lag or dt * 4
		st.boost = st.boost + (want - st.boost) * clamp(k, 0, 1)
		if car.turbo.lag2 then
			local w2 = (want == 1 and st.boost > 0.8 and st.rpm > 0.55) and 1 or 0
			local k2 = w2 > st.boost2 and dt / car.turbo.lag2 or dt * 3
			st.boost2 = st.boost2 + (w2 - st.boost2) * clamp(k2, 0, 1)
		end
	end
	local powerMul = 1
	if car.turbo then
		if car.turbo.lag2 then
			powerMul = 0.38 + 0.32 * st.boost + 0.30 * st.boost2
		else
			powerMul = 0.32 + 0.68 * st.boost
		end
	end
	local P = p.P * powerMul
	st.hybridOn = false
	if car.hybrid and thr > 0.5 and st.battery > 0.02 and spd > 3 then
		P = P + p.hybridP
		st.battery = math.max(0, st.battery - dt * 0.28)
		st.hybridOn = true
	end

	-- force motrice
	local Fdrive = 0
	if st.reverse then
		if inp.brake > 0.1 then
			Fdrive = -inp.brake * math.min(p.Fmax * 0.7, P / math.max(spd, 5)) * (1 - clamp(-st.vF / p.vrev, 0, 1))
		end
	elseif thr > 0 and st.shiftT <= 0 then
		local lim = 1
		if spd >= gTop then lim = 0 end
		if st.manual and st.gear > 1 and spd < gLow then lim = 0.45 end
		Fdrive = thr * math.min(p.Fmax, P / math.max(spd, 3)) * lim
	end
	-- frein moteur au lever de pied
	if thr < 0.05 and not st.reverse and spd > 1 then
		Fdrive = Fdrive - sign(st.vF) * m * (0.7 + 0.6 * st.rpm)
	end

	-- freins de service (pas en marche arrière)
	local Fbrake = 0
	if inp.brake > 0 and not st.reverse and st.vF > 0.3 then
		Fbrake = inp.brake * p.brake * m
		if car.hybrid then st.battery = math.min(1, st.battery + dt * 0.35 * inp.brake * clamp(spd / 20, 0, 1)) end
	end

	-- charges sur les essieux (transfert)
	local Fz = m * G
	local Fzf = clamp(Fz * p.b / p.L - m * st.ax * p.h / p.L, 0.15 * Fz, 0.85 * Fz)
	local Fzr = Fz - Fzf

	local muF = p.mu * surf.gF
	local muR = p.mu * surf.gR

	-- forces longitudinales par essieu (repère roue)
	local front = car.front
	local FxF = Fdrive * front - Fbrake * 0.65 * sign(st.vF)
	local FxR = Fdrive * (1 - front) - Fbrake * 0.35 * sign(st.vF)
	local hbOn = inp.hb and spd > 0.5
	if hbOn then
		FxR = -sign(st.vF) * muR * Fzr * HB_GAIN
	end
	local capF = muF * p.longMu * Fzf
	local capR = muR * p.longMu * Fzr * (hbOn and HB_GAIN or 1)
	-- patinage : si la demande dépasse l'adhérence, la force retombe et consomme le latéral
	local spinR = math.abs(FxR) > capR
	local spinF = math.abs(FxF) > capF
	FxF = clamp(FxF, -capF, capF)
	FxR = clamp(FxR, -capR, capR)
	st.spin = (spinR or spinF) and 1 or 0

	-- vitesses aux roues
	local d = st.steer
	local cd, sd = math.cos(d), math.sin(d)
	local vyF = st.vL + p.a * st.r
	local vyR = st.vL - p.b * st.r
	local wlF = st.vF * cd + vyF * sd
	local wtF = -st.vF * sd + vyF * cd
	local alphaF = math.atan2(wtF, math.max(math.abs(wlF), 1.5))
	local alphaR = math.atan2(vyR, math.max(math.abs(st.vF), 1.5))
	st.slipF, st.slipR = alphaF, alphaR

	-- forces latérales avec cercle d'adhérence
	local function lat(alpha, mu, fz, fx, cap, kill)
		local maxY = mu * fz
		local used = cap > 0 and math.abs(fx) / cap or 0
		local rem = math.sqrt(math.max(0, 1 - used * used))
		return -maxY * tire(alpha) * math.max(rem, kill)
	end
	local FyF = lat(alphaF, muF, Fzf, FxF, capF, 0.25)
	local FyR = lat(alphaR, muR, Fzr, FxR, capR, hbOn and 0.5 or (spinR and 0.35 or 0.3))
	if hbOn then FyR = FyR * 0.95 end

	-- retour au repère voiture
	local FxFc = FxF * cd - FyF * sd
	local FyFc = FxF * sd + FyF * cd

	-- résistances
	local drag = p.cd * st.vF * math.abs(st.vF)
	local roll = m * (surf.drag or 0) * clamp(math.abs(st.vF) / 3, 0, 1) * sign(st.vF)
	-- frottement latéral supplémentaire sur bas-côtés
	local sideRoll = m * (surf.drag or 0) * 0.3 * clamp(math.abs(st.vL) / 3, 0, 1) * sign(st.vL)

	local FxTot = FxFc + FxR - drag - roll
	local FyTot = FyFc + FyR - sideRoll

	local axNew = FxTot / m
	local ay = FyTot / m
	local yawAcc = (p.a * FyFc - p.b * FyR) / p.Iz
	-- stabilité des 4x4 à haute vitesse
	if front > 0 and front < 1 then yawAcc = yawAcc - st.r * clamp(spd / 30, 0, 1) * 0.8 end

	st.vF = st.vF + (axNew + st.vL * st.r) * dt
	st.vL = st.vL + (ay - st.vF * st.r) * dt
	st.r = st.r + yawAcc * dt
	-- arcade : rotation plafonnée (~110°/s mesuré en épingle) et amortie quand l'arrière glisse
	if math.abs(alphaR) > 0.35 then st.r = st.r * (1 - clamp(dt * 2.5, 0, 1)) end
	st.r = clamp(st.r, -1.95, 1.95)

	-- basse vitesse : modèle cinématique pour éviter les oscillations
	local blend = clamp((v - 1.5) / 3, 0, 1)
	if blend < 1 then
		local rKin = st.vF * math.tan(st.steer) / p.L
		st.r = st.r * blend + rKin * (1 - blend)
		st.vL = st.vL * (0.6 + 0.4 * blend)
	end
	-- arrêt net
	if math.abs(st.vF) < 0.25 and thr < 0.05 and inp.brake < 0.05 then
		st.vF = st.vF * 0.85
	end
	st.ax = st.ax + (axNew - st.ax) * clamp(dt * 8, 0, 1)

	-- tableau de bord : températures et carburant
	local t = st.temps
	t.oil = t.oil + ((70 + 40 * st.rpm * thr) - t.oil) * dt * 0.05
	t.water = t.water + ((82 + 12 * st.rpm) - t.water) * dt * 0.08
	t.box = t.box + ((60 + 30 * thr) - t.box) * dt * 0.03
	st.fuel = math.max(0.05, st.fuel - dt * thr * 0.0008)
end

-- avance sans adhérence (en l'air) : la direction et le régime évoluent quand même
function Physics.air(p, st, inp, dt)
	local target = clamp(inp.steer, -1, 1) * Physics.maxSteer(0)
	st.steer = st.steer + clamp(target - st.steer, -4 * dt, 4 * dt)
	if inp.throttle > 0.5 then st.rpm = math.min(1.05, st.rpm + dt * 2) else st.rpm = math.max(0.12, st.rpm - dt) end
end

function Physics.gearLabel(st)
	if st.gear == -1 then return "R" end
	if math.abs(st.vF) < 0.3 then return "N" end
	return tostring(st.gear)
end

return Physics

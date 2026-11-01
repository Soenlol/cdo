-- Piste Poussière : données du jeu (voitures, étapes, surfaces, récompenses)
-- Unités internes : mètres, secondes, kg. 1 m = Config.M studs dans Roblox.

local Config = {}

Config.VERSION = 1
Config.M = 3                 -- studs par mètre
Config.G = 9.81
Config.HALF = 4              -- demi-largeur de la route (m)
Config.STEP = 2              -- pas d'échantillonnage du tracé (m)
Config.START_D = 22          -- distance de l'arche de départ (m)
Config.SPAWN_D = 8           -- position d'apparition (m)
Config.RECOVER_PENALTY = 3   -- R = dernier point de passage (+3 s)

-- IDs Roblox à remplir après publication (0 = désactivé)
Config.VIP_GAMEPASS_ID = 0       -- double EXP et crédits
Config.COMETE_GAMEPASS_ID = 0    -- débloque la Comète Bi

---------------------------------------------------------------------------
-- Surfaces : clé = nom du matériau de terrain Roblox
-- grip : multiplicateur d'adhérence, drag : résistance (m/s²), fx : couleur de poussière
---------------------------------------------------------------------------
Config.BASE_MU = 1.6      -- adhérence de base (arcade) sur asphalte
Config.LONG_MU = 1.45     -- les freins mordent plus fort que l'adhérence latérale

Config.SURFACES = {
	Asphalt   = {name = "Asphalte",        grip = 1.00, drag = 0.15, dust = nil},
	Pavement  = {name = "Pavés",           grip = 0.90, drag = 0.25, dust = nil},
	Cobblestone = {name = "Pavés",         grip = 0.88, drag = 0.30, dust = nil},
	Ground    = {name = "Gravier",         grip = 0.72, drag = 0.45, dust = {200, 172, 130}},
	Sandstone = {name = "Terre rouge",     grip = 0.70, drag = 0.50, dust = {196, 104, 60}},
	Mud       = {name = "Boue",            grip = 0.52, drag = 1.80, dust = {78, 56, 36}, mud = true},
	Salt      = {name = "Neige tassée",    grip = 0.46, drag = 0.55, dust = {245, 248, 255}},
	Ice       = {name = "Glace",           grip = 0.20, drag = 0.10, dust = {220, 240, 255}},
	Sand      = {name = "Sable",           grip = 0.58, drag = 2.30, dust = {236, 214, 160}, sand = true},
	WoodPlanks = {name = "Pont en bois",   grip = 0.85, drag = 0.30, dust = nil},
	Grass     = {name = "Herbe",           grip = 0.60, drag = 5.00, dust = {96, 128, 60}, offroad = true},
	LeafyGrass = {name = "Herbe haute",    grip = 0.58, drag = 5.50, dust = {150, 140, 70}, offroad = true},
	Snow      = {name = "Neige profonde",  grip = 0.40, drag = 6.00, dust = {255, 255, 255}, offroad = true},
	Rock      = {name = "Rocaille",        grip = 0.75, drag = 1.50, dust = {150, 120, 100}, offroad = true},
	Glacier   = {name = "Glace du lac",    grip = 0.18, drag = 0.20, dust = {220, 240, 255}},
	Water     = {name = "Eau",             grip = 0.50, drag = 6.00, dust = {200, 220, 240}, mud = true},
}
Config.DEFAULT_SURFACE = {name = "Bas-côté", grip = 0.65, drag = 3.0, dust = {120, 110, 90}, offroad = true}

-- couleurs des matériaux de terrain (appliquées une fois)
Config.MATERIAL_COLORS = {
	Ground = {168, 142, 104}, Sandstone = {178, 92, 52}, Salt = {226, 232, 240},
	Asphalt = {74, 76, 82}, Mud = {92, 66, 42}, Grass = {96, 140, 58},
	LeafyGrass = {178, 160, 84}, Snow = {242, 246, 250}, Sand = {226, 202, 140},
	Rock = {128, 112, 100}, Glacier = {170, 214, 236}, Ice = {196, 230, 248},
	WoodPlanks = {130, 92, 58}, Pavement = {150, 146, 140}, Cobblestone = {140, 134, 126},
}

---------------------------------------------------------------------------
-- Voitures (toutes originales)
-- ch : puissance, nm : couple, kg : masse, vmax : km/h
-- front : part du couple sur l'avant (1 = traction, 0 = propulsion, 0.44 = 4x4 44/56)
-- rear : répartition des masses vers l'arrière, travel : débattement (m), freq : raideur (Hz)
---------------------------------------------------------------------------
Config.CARS = {
	{id = "moineau", name = "Moineau 4", cls = "D", score = 281, ch = 75, nm = 110, kg = 830, vmax = 149, front = 0,
		rear = 0.48, travel = 0.30, freq = 1.05, grip = 0.95, gears = 4, price = 0, shape = "citadine",
		color = {120, 190, 70}, desc = "Citadine surélevée pour débuter. Penche, rebondit, glisse lentement : très indulgente."},
	{id = "pomme", name = "Pomme 2", cls = "D", score = 362, ch = 130, nm = 160, kg = 880, vmax = 177, front = 1,
		rear = 0.40, travel = 0.22, freq = 1.4, grip = 1.0, gears = 5, price = 1500, shape = "coupe",
		color = {220, 60, 50}, desc = "Petit coupé des années 60 au moteur pointu. Traction : pousse si on est gourmand, rentre au lever de pied."},
	{id = "puce", name = "Puce S", cls = "C", score = 438, ch = 110, nm = 120, kg = 690, vmax = 157, front = 1,
		rear = 0.38, travel = 0.20, freq = 1.6, grip = 1.04, gears = 4, price = 2500, shape = "mini",
		color = {250, 210, 60}, desc = "Mini joyeuse, une roue à chaque coin. Virevolte dans le serré, s'essouffle en ligne droite."},
	{id = "eclair", name = "Éclair T", cls = "C", score = 492, ch = 215, nm = 300, kg = 1200, vmax = 175, front = 0.45,
		rear = 0.47, travel = 0.25, freq = 1.4, grip = 1.02, gears = 5, price = 4500, shape = "compacte",
		turbo = {lag = 0.45}, nervous = true, color = {245, 245, 245},
		desc = "Compacte turbo à empattement court. 4x4 indulgente sur gravier, nerveuse sur les crêtes."},
	{id = "lynx", name = "Lynx 16V", cls = "B", score = 584, ch = 230, nm = 240, kg = 1150, vmax = 178, front = 0,
		rear = 0.50, travel = 0.24, freq = 1.5, grip = 1.03, gears = 5, price = 6500, shape = "cubique",
		color = {40, 110, 220}, desc = "Deux-portes cubique Groupe A. Propulsion : l'arrière glisse à l'accélérateur."},
	{id = "ondine", name = "Ondine RS", cls = "B", score = 648, ch = 300, nm = 400, kg = 1350, vmax = 191, front = 0.38,
		rear = 0.50, travel = 0.25, freq = 1.45, grip = 1.06, gears = 5, price = 9000, shape = "berline",
		turbo = {lag = 0.5}, color = {30, 60, 140},
		desc = "Berline 4 portes turbo. Tire fort dès que le turbo s'active, stable à haute vitesse."},
	{id = "scorpion", name = "Scorpion", cls = "A", score = 736, ch = 310, nm = 520, kg = 1050, vmax = 184, front = 0,
		rear = 0.60, travel = 0.45, freq = 0.95, grip = 1.0, gears = 5, price = 12000, shape = "buggy",
		sand = true, color = {230, 120, 30},
		desc = "Buggy de raid à moteur arrière. Flotte sur les bosses, l'arrière balaie large en sortie."},
	{id = "tempete", name = "Tempête T4", cls = "A", score = 828, ch = 470, nm = 490, kg = 1090, vmax = 195, front = 0.44,
		rear = 0.55, travel = 0.27, freq = 1.5, grip = 1.06, gears = 5, price = 16000, shape = "groupeb",
		turbo = {lag = 0.85}, color = {200, 30, 40},
		desc = "Groupe B à empattement court. Le turbo ne fait rien… puis tout. Coup de frein à main pour faire passer l'arrière."},
	{id = "volt", name = "Volt H1", cls = "A", score = 790, ch = 380, nm = 450, kg = 1260, vmax = 198, front = 0.42,
		rear = 0.52, travel = 0.27, freq = 1.55, grip = 1.12, brake = 19, gears = 5, price = 19000, shape = "rally1",
		hybrid = {ch = 134}, color = {20, 20, 30},
		desc = "Hybride : la batterie se recharge au freinage puis ajoute 134 ch dans le virage suivant. Meilleur grip et meilleurs freins."},
	{id = "tonnerre", name = "Tonnerre E", cls = "A", score = 842, ch = 1020, nm = 1420, kg = 2200, vmax = 200, front = 0.5,
		rear = 0.50, travel = 0.32, freq = 1.2, grip = 1.0, gears = 1, price = 22000, shape = "suv",
		electric = true, color = {60, 200, 190},
		desc = "SUV électrique : couple instantané, mais 2,2 tonnes à arrêter avant chaque épingle."},
	{id = "bison", name = "Bison V8", cls = "S", score = 893, ch = 850, nm = 940, kg = 2200, vmax = 204, front = 0,
		rear = 0.52, travel = 0.50, freq = 0.85, grip = 1.0, gears = 5, price = 26000, shape = "truck",
		sand = true, color = {255, 150, 30},
		desc = "Trophy truck V8. Flotte sur les bosses, lourd dans le serré : freiner tôt et laisser venir l'arrière en puissance."},
	{id = "comete", name = "Comète Bi", cls = "S", score = 892, ch = 450, nm = 500, kg = 1150, vmax = 230, front = 0.35,
		rear = 0.56, travel = 0.26, freq = 1.6, grip = 1.08, gears = 6, price = 32000, shape = "supercar",
		turbo = {lag = 0.3, lag2 = 0.9}, gamepass = "COMETE_GAMEPASS_ID", color = {250, 250, 250},
		desc = "Supercar biturbo : les deux turbos se réveillent l'un après l'autre. La plus rapide en pointe."},
}
Config.CAR_BY_ID = {}
for i, c in ipairs(Config.CARS) do
	c.index = i
	Config.CAR_BY_ID[c.id] = c
end

-- barres de stats sur 10
function Config.carStats(c)
	local pw = c.ch / c.kg * 1000
	local function bar(v, a, b) return math.max(1, math.min(10, math.floor((v - a) / (b - a) * 9 + 1.5))) end
	return {
		vitesse = bar(c.vmax, 145, 232),
		acceleration = bar(pw, 85, 480),
		adherence = bar(c.grip + (c.front > 0 and c.front < 1 and 0.05 or 0), 0.93, 1.15),
		maniabilite = bar(1 / c.kg * 1000 - c.travel, 0.0, 1.2),
	}
end

Config.PAINTS = {
	{name = "Origine", rgb = nil},
	{name = "Rouge rallye", rgb = {200, 30, 40}}, {name = "Bleu nuit", rgb = {25, 45, 110}},
	{name = "Vert forêt", rgb = {40, 110, 60}}, {name = "Jaune soleil", rgb = {250, 205, 40}},
	{name = "Orange piste", rgb = {245, 120, 25}}, {name = "Blanc glacier", rgb = {240, 244, 248}},
	{name = "Noir mat", rgb = {28, 28, 32}}, {name = "Turquoise", rgb = {40, 190, 190}},
	{name = "Violet", rgb = {120, 60, 180}}, {name = "Rose", rgb = {240, 120, 170}},
	{name = "Sable", rgb = {214, 190, 140}}, {name = "Bordeaux", rgb = {110, 20, 40}},
	{name = "Gris acier", rgb = {120, 128, 138}}, {name = "Or", rgb = {212, 175, 55}},
	{name = "Citron", rgb = {200, 230, 40}},
}
Config.GLOVES = {
	{id = "cuir", name = "Cuir noir", rgb = {30, 30, 30}},
	{id = "rouge", name = "Rouge course", rgb = {200, 30, 40}, price = 400},
	{id = "blanc", name = "Blanc", rgb = {235, 235, 235}, price = 400},
	{id = "bleu", name = "Bleu", rgb = {40, 90, 200}, price = 400},
	{id = "sable", name = "Sable du raid", rgb = {214, 180, 110}, event = 10},
	{id = "or", name = "Or (Maîtrise 10)", rgb = {212, 175, 55}, mastery = 10},
}

Config.CRATES = {
	paint = {name = "Caisse de peinture", price = 300},
	perf = {name = "Caisse de performance", price = 2500},
	glove = {name = "Caisse de gants", price = 600},
}

---------------------------------------------------------------------------
-- Progression
---------------------------------------------------------------------------
Config.CLASSES = {"D", "C", "B", "A", "S"}
Config.MASTERY_EXP = {0, 200, 500, 900, 1400, 2100, 3000, 4100, 5500, 7200} -- M1..M10
Config.LEVEL_EXP = 500  -- EXP par niveau joueur

Config.REWARDS = {
	finish = {exp = 100, cr = 50},
	medal = {
		bronze = {exp = 20, cr = 10}, argent = {exp = 40, cr = 20},
		["or"] = {exp = 60, cr = 30}, platine = {exp = 90, cr = 45},
	},
	firstMedal = {exp = 30, cr = 20},   -- première fois pour ce niveau de médaille
	firstOfDay = {exp = 50, cr = 40},
	coin = {exp = 0, cr = 5},            -- par pièce ramassée la première fois
}
Config.MEDALS = {"bronze", "argent", "or", "platine"}
Config.MEDAL_NAMES = {bronze = "Bronze", argent = "Argent", ["or"] = "Or", platine = "Platine"}
Config.MEDAL_COLORS = {bronze = {205, 127, 50}, argent = {200, 205, 215}, ["or"] = {255, 205, 50}, platine = {170, 230, 255}}
-- temps des médailles = temps de référence × facteur
Config.MEDAL_FACTORS = {platine = 1.22, ["or"] = 1.35, argent = 1.52, bronze = 1.72}

Config.CONTRACTS = {
	{id = "finish3", text = "Termine 3 étapes", goal = 3, cr = 150},
	{id = "gold1", text = "Obtiens une médaille d'or ou mieux", goal = 1, cr = 200},
	{id = "coins15", text = "Ramasse 15 pièces", goal = 15, cr = 120},
	{id = "clean2", text = "Termine 2 étapes sans pénalité", goal = 2, cr = 180},
	{id = "snow1", text = "Termine une étape enneigée", goal = 1, cr = 100},
	{id = "km5", text = "Parcours 5 km en course", goal = 5, cr = 150},
	{id = "fwd1", text = "Termine une étape en traction", goal = 1, cr = 100},
	{id = "hairpin10", text = "Passe 10 épingles", goal = 10, cr = 130},
}

---------------------------------------------------------------------------
-- Étapes (tracés originaux)
-- Commandes : {"S", longueur} ligne droite ; {"L"/"R", angle°, rayon} virage ; {"HL"}/{"HR"} épingle
-- {"surf", "Materiau"} change la surface ; {"deco", "type"} change le décor
-- f = "gue" | "pont" | "pontCouvert" | "saut" | "tunnel" | "arche" | "congeres" | "village" | "lac" | "plage"
-- elev : {distance, altitude} en m
---------------------------------------------------------------------------
Config.STAGES = {
	{
		id = "pins", name = "Lande aux Pins", country = "Finlande", seed = 101,
		desc = "Gravier rapide entre les pins, deux crêtes à sauter, un gué boueux et une épingle avant de finir sur le bitume de la ferme.",
		offroad = "Grass", deco = "pins", coins = 20,
		sky = {clock = 14.5, fog = {200, 220, 235}, ambient = {120, 130, 120}},
		elev = {{0, 0}, {250, 4}, {500, 9}, {800, 2}, {1100, 6}, {1400, 13}, {1700, 8}},
		path = {
			{"surf", "Ground"},
			{"S", 70}, {"R", 35, 70}, {"S", 70}, {"L", 60, 45}, {"S", 60, f = "saut"},
			{"R", 25, 130}, {"S", 80}, {"L", 85, 32}, {"S", 40},
			{"surf", "Mud"}, {"S", 45, f = "gue"}, {"surf", "Ground"},
			{"R", 70, 55}, {"S", 60}, {"L", 30, 90}, {"S", 70, f = "saut"}, {"S", 30},
			{"HR"}, {"S", 70}, {"L", 50, 40}, {"S", 40}, {"R", 80, 38},
			{"S", 50, f = "pont"}, {"L", 40, 70},
			{"surf", "Asphalt"}, {"deco", "ferme"}, {"S", 90}, {"R", 30, 80}, {"S", 110},
		},
	},
	{
		id = "marmottes", name = "Col des Marmottes", country = "France", seed = 202,
		desc = "Lacets de bitume au-dessus du lac, plateau de gravier, tunnel, puis neige tassée et congères jusqu'au col.",
		offroad = "Grass", deco = "sapins", coins = 22,
		sky = {clock = 11, fog = {205, 220, 240}, ambient = {125, 130, 140}},
		elev = {{0, 0}, {300, 4}, {600, 22}, {900, 30}, {1200, 36}, {1500, 48}, {1850, 55}},
		path = {
			{"surf", "Asphalt"}, {"deco", "lac"},
			{"S", 90}, {"L", 30, 120}, {"S", 80}, {"R", 45, 70}, {"S", 60}, {"L", 40, 80}, {"S", 70},
			{"HL"}, {"S", 70}, {"HR"}, {"S", 70}, {"HL"}, {"S", 50},
			{"surf", "Ground"}, {"deco", "sapins"},
			{"R", 60, 50}, {"S", 50}, {"L", 55, 40}, {"R", 40, 45}, {"S", 60},
			{"surf", "Asphalt"}, {"S", 70, f = "tunnel"},
			{"surf", "Salt"}, {"deco", "sapinsNeige"},
			{"L", 45, 60, f = "congeres"}, {"S", 60, f = "congeres"}, {"R", 80, 36, f = "congeres"},
			{"S", 40, f = "congeres"}, {"L", 60, 45, f = "congeres"}, {"S", 70}, {"R", 30, 90}, {"S", 80}, {"L", 40, 70}, {"S", 90},
		},
	},
	{
		id = "erables", name = "Route des Érables", country = "Canada", seed = 303,
		desc = "Gravier sous les érables rouges, pont sur la rivière, trois virages serrés, un grand saut et une arrivée au village.",
		offroad = "Grass", deco = "erables", coins = 26,
		sky = {clock = 16, fog = {235, 215, 190}, ambient = {140, 120, 110}},
		elev = {{0, 0}, {200, 6}, {420, 0}, {700, 18}, {1000, 34}, {1300, 46}, {1550, 60}},
		path = {
			{"surf", "Ground"},
			{"S", 60}, {"L", 40, 60}, {"S", 70}, {"R", 55, 50}, {"S", 60},
			{"surf", "WoodPlanks"}, {"S", 50, f = "pont"}, {"surf", "Ground"},
			{"L", 90, 22}, {"S", 20}, {"R", 95, 20}, {"S", 25}, {"L", 85, 24},
			{"S", 80}, {"R", 30, 100}, {"S", 70, f = "saut"}, {"S", 40},
			{"L", 60, 50}, {"S", 50}, {"R", 70, 40}, {"S", 60}, {"L", 35, 80}, {"S", 80}, {"R", 45, 60}, {"S", 70},
			{"surf", "Asphalt"}, {"deco", "village"},
			{"L", 40, 60}, {"S", 70, f = "village"}, {"R", 50, 45, f = "village"}, {"S", 90, f = "village"},
		},
	},
	{
		id = "gorges", name = "Gorges Rouges", country = "Australie", seed = 404,
		desc = "Terre rouge rapide, traversée de rivière, tunnel creusé dans la falaise, arche de grès et longue ligne droite finale.",
		offroad = "Rock", deco = "canyon", coins = 45,
		sky = {clock = 15, fog = {240, 200, 160}, ambient = {150, 120, 100}},
		elev = {{0, 0}, {400, 8}, {800, 0}, {1200, 20}, {1600, 40}, {2000, 60}, {2400, 45}, {2900, 30}},
		path = {
			{"surf", "Sandstone"},
			{"S", 100}, {"R", 40, 80}, {"S", 90}, {"L", 70, 50}, {"S", 70}, {"R", 35, 110},
			{"S", 60}, {"surf", "Mud"}, {"S", 40, f = "gue"}, {"surf", "Sandstone"},
			{"L", 60, 60}, {"S", 80}, {"R", 90, 35}, {"S", 50}, {"L", 50, 55}, {"S", 90, f = "saut"},
			{"R", 30, 120}, {"S", 70}, {"HL"}, {"S", 80}, {"R", 60, 45}, {"S", 60},
			{"surf", "Asphalt"}, {"S", 90, f = "tunnel"}, {"surf", "Sandstone"},
			{"L", 45, 70}, {"S", 80}, {"R", 70, 40}, {"S", 60, f = "arche"}, {"L", 30, 140}, {"S", 100}, {"R", 40, 90}, {"S", 120}, {"L", 60, 60}, {"S", 100}, {"R", 35, 100}, {"S", 120},
			{"S", 120}, {"R", 50, 60}, {"S", 70}, {"L", 80, 35}, {"S", 160},
		},
	},
	{
		id = "corniche", name = "Corniche Azur", country = "Grèce", seed = 505,
		desc = "Départ du port, sable de la plage, oliviers en terrasses, corniche au-dessus de la mer et arrivée au phare.",
		offroad = "LeafyGrass", deco = "oliviers", coins = 40,
		sky = {clock = 13, fog = {200, 225, 245}, ambient = {140, 140, 140}},
		elev = {{0, 0}, {300, 0}, {650, 1}, {900, 14}, {1250, 32}, {1600, 46}, {2050, 52}},
		path = {
			{"surf", "Pavement"}, {"deco", "village"},
			{"S", 70, f = "village"}, {"R", 60, 40, f = "village"}, {"S", 50, f = "village"},
			{"surf", "Sand"}, {"deco", "plage"},
			{"L", 30, 120, f = "plage"}, {"S", 120, f = "plage"}, {"R", 25, 150, f = "plage"}, {"S", 90, f = "plage"}, {"S", 80}, {"R", 30, 100, f = "plage"}, {"S", 90, f = "plage"},
			{"surf", "Ground"}, {"deco", "oliviers"},
			{"L", 80, 35}, {"S", 50}, {"HR"}, {"S", 60}, {"L", 50, 45}, {"S", 70},
			{"surf", "Asphalt"},
			{"R", 40, 70}, {"S", 80}, {"L", 70, 50}, {"S", 60}, {"R", 60, 40}, {"S", 90},
			{"L", 35, 90}, {"S", 70}, {"R", 80, 30}, {"S", 80}, {"L", 40, 80}, {"S", 100}, {"deco", "phare"}, {"S", 60},
		},
	},
	{
		id = "miroir", name = "Lac Miroir", country = "Norvège", seed = 606,
		desc = "Forêt enneigée entre les congères, deux épingles qui montent, une crête, un pont couvert et la traversée du lac gelé.",
		offroad = "Snow", deco = "sapinsNeige", coins = 28,
		sky = {clock = 10, fog = {215, 225, 238}, ambient = {140, 150, 165}},
		elev = {{0, 0}, {300, 5}, {600, 18}, {850, 30}, {1150, 35}, {1400, 18}, {1600, 4}, {2500, 4}},
		path = {
			{"surf", "Salt"},
			{"S", 60, f = "village"}, {"R", 40, 60}, {"S", 60, f = "congeres"}, {"L", 70, 40, f = "congeres"},
			{"S", 50, f = "congeres"}, {"R", 50, 50, f = "congeres"}, {"S", 40},
			{"HL"}, {"S", 60}, {"HR"}, {"S", 70},
			{"L", 30, 100}, {"S", 70, f = "saut"}, {"S", 40}, {"R", 60, 45}, {"S", 50},
			{"surf", "WoodPlanks"}, {"S", 45, f = "pontCouvert"}, {"surf", "Salt"},
			{"L", 50, 50}, {"S", 70}, {"R", 35, 80}, {"S", 60}, {"L", 40, 70}, {"S", 70}, {"R", 45, 60}, {"S", 60},
			{"surf", "Glacier"}, {"deco", "lac"},
			{"S", 120, f = "lac"}, {"L", 50, 90, f = "lac"}, {"S", 100, f = "lac"}, {"R", 80, 70, f = "lac"},
			{"S", 120, f = "lac"}, {"L", 40, 100, f = "lac"}, {"S", 100, f = "lac"}, {"R", 40, 110, f = "lac"}, {"S", 120, f = "lac"}, {"L", 50, 100, f = "lac"}, {"S", 100, f = "lac"},
		},
	},
	{
		id = "dunes", name = "Raid des Dunes", country = "Maroc", seed = 707, event = true,
		desc = "ÉVÉNEMENT — Grande boucle de raid : pistes de gravier, sable mou et oasis. Gagne des jetons de raid !",
		offroad = "Sand", deco = "desert", coins = 34,
		sky = {clock = 16.5, fog = {245, 215, 170}, ambient = {160, 135, 110}},
		elev = {{0, 0}, {700, 20}, {1400, 45}, {2300, 83}, {3000, 60}, {3700, 35}, {4300, 12}, {5100, 0}},
		path = {
			{"surf", "Ground"},
			{"S", 160}, {"L", 25, 160}, {"S", 260}, {"R", 40, 120}, {"S", 220},
			{"surf", "Sand"}, {"L", 35, 100}, {"S", 200}, {"R", 30, 140}, {"S", 200, f = "saut"},
			{"surf", "Ground"}, {"L", 30, 100}, {"S", 260}, {"R", 25, 120}, {"S", 200},
			{"L", 90, 140}, {"S", 160}, {"L", 90, 140},
			{"S", 240}, {"R", 30, 120}, {"S", 200}, {"surf", "Sand"}, {"L", 30, 120}, {"S", 220, f = "saut"},
			{"L", 25, 140}, {"S", 240}, {"surf", "Ground"}, {"R", 25, 140}, {"S", 240}, {"L", 40, 90},
			{"S", 180}, {"R", 40, 90}, {"S", 260},
		},
	},
}
Config.STAGE_BY_ID = {}
for i, s in ipairs(Config.STAGES) do
	s.index = i
	Config.STAGE_BY_ID[s.id] = s
end

Config.SNOW_STAGES = {marmottes = true, miroir = true}
Config.EVENT = {name = "Raid des Dunes", stage = "dunes", tokens = {bronze = 1, argent = 2, ["or"] = 3, platine = 4}}

return Config

-- Replay : rejoue l'enregistrement de la course avec des caméras de bord de route

local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Rallye")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)
local Track = require(Shared.Track)
local Ui = require(script.Parent.Ui)

local Replay = {}
local M = Config.M
local camera = workspace.CurrentCamera

-- data : frames, car, T, origin ; onEnd appelé à la fin ou quand on passe
function Replay.play(data, paintRGB, onEnd)
	local frames = data.frames
	if not frames or #frames < 2 then
		if onEnd then onEnd() end
		return
	end
	local model = Cars.build(data.car, paintRGB, {anchored = true})
	model.Name = "ReplayCar"
	model.Parent = workspace

	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Ui.make("ScreenGui", {Name = "Replay", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Parent = pg})
	-- bandes du format « clip vertical »
	Ui.make("Frame", {Size = UDim2.new(0.18, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.15, Parent = gui})
	Ui.make("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.18, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.15, Parent = gui})
	local rec = Ui.make("Frame", {Position = UDim2.new(0.2, 0, 0, 20), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Ui.C.red, Parent = gui})
	Ui.corner(rec, 8)
	Ui.label("REPLAY", {Position = UDim2.new(0.2, 24, 0, 14), Size = UDim2.fromOffset(200, 28), Font = Enum.Font.GothamBlack, TextSize = 24, Parent = gui})
	local tl = Ui.label("", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.8, -10, 0, 14), Size = UDim2.fromOffset(200, 28), Font = Enum.Font.GothamBlack,
		TextSize = 24, TextXAlignment = Enum.TextXAlignment.Right, Parent = gui})
	local skip = Ui.button("ENTRÉE : Passer", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(220, 44)}, nil, "secondary")
	skip.Parent = gui

	local done = false
	local conn, keyConn
	local function finish()
		if done then return end
		done = true
		conn:Disconnect()
		keyConn:Disconnect()
		gui:Destroy()
		model:Destroy()
		if onEnd then onEnd() end
	end
	skip.MouseButton1Click:Connect(finish)
	keyConn = UIS.InputBegan:Connect(function(io)
		if io.KeyCode == Enum.KeyCode.Return or io.KeyCode == Enum.KeyCode.ButtonA then finish() end
	end)

	local t0 = frames[1].t
	local tEnd = frames[#frames].t
	local t = t0
	local i = 1
	local shot, shotT, shotPos = 0, 99, nil
	local T, origin = data.T, data.origin
	conn = RunService.RenderStepped:Connect(function(dt)
		t = t + dt
		if t >= tEnd + 1.5 then finish() return end
		while frames[i + 1] and frames[i + 1].t <= t do i = i + 1 end
		local a, b = frames[i], frames[i + 1] or frames[i]
		local u = (b.t > a.t) and math.clamp((t - a.t) / (b.t - a.t), 0, 1) or 0
		local cf = a.cf:Lerp(b.cf, u)
		model:PivotTo(cf)
		tl.Text = Ui.fmt(math.max(0, t))
		rec.BackgroundTransparency = (math.floor(t * 2) % 2 == 0) and 0 or 0.7
		-- changement de plan toutes les 4 s
		shotT = shotT + dt
		if shotT > 4 then
			shotT = 0
			shot = (shot % 4) + 1
			-- caméra fixe placée sur le bord de la route, un peu plus loin
			local px = (cf.Position.X - origin.X) / M
			local pz = (cf.Position.Z - origin.Z) / M
			local idx = Track.nearest(T, px, pz, nil)
			local s = T.S[math.min(#T.S, idx + 25)]
			local side = (shot % 2 == 0) and 1 or -1
			shotPos = origin + Vector3.new((s.x + s.nx * side * (Config.HALF + 5)) * M, (s.y + 2) * M, (s.z + s.nz * side * (Config.HALF + 5)) * M)
		end
		camera.CameraType = Enum.CameraType.Scriptable
		if shot == 1 or shot == 3 then
			camera.CFrame = CFrame.lookAt(shotPos or cf.Position + Vector3.new(20, 10, 20), cf.Position)
			camera.FieldOfView = 50
		elseif shot == 2 then
			camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 22 * M, 0) - cf.LookVector * 12 * M, cf.Position)
			camera.FieldOfView = 60
		else
			camera.CFrame = CFrame.lookAt((cf * CFrame.new(1.8 * M, 0.3 * M, -5 * M)).Position, cf.Position + Vector3.new(0, 0.5 * M, 0))
			camera.FieldOfView = 70
		end
	end)
	shotT = 99
end

return Replay

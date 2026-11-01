-- Petits outils d'interface (création d'instances, boutons, thème)

local Ui = {}

Ui.C = {
	bg = Color3.fromRGB(16, 20, 26),
	panel = Color3.fromRGB(26, 32, 41),
	panel2 = Color3.fromRGB(36, 44, 56),
	acc = Color3.fromRGB(255, 201, 60),
	red = Color3.fromRGB(229, 72, 77),
	green = Color3.fromRGB(76, 195, 138),
	blue = Color3.fromRGB(70, 140, 230),
	text = Color3.fromRGB(244, 241, 232),
	dim = Color3.fromRGB(160, 166, 176),
	black = Color3.fromRGB(10, 10, 12),
}
local C = Ui.C

function Ui.rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end

function Ui.make(class, props, children)
	local o = Instance.new(class)
	if class == "Frame" or class == "TextLabel" or class == "TextButton" or class == "ScrollingFrame" or class == "ImageLabel" or class == "CanvasGroup" then
		o.BorderSizePixel = 0
	end
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		o.Font = Enum.Font.GothamMedium
		o.TextColor3 = C.text
		o.BackgroundTransparency = 1
		o.TextSize = 16
	end
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else o[k] = v end
	end
	for _, ch in ipairs(children or {}) do ch.Parent = o end
	if parent then o.Parent = parent end
	return o
end
local make = Ui.make

function Ui.corner(o, r)
	make("UICorner", {CornerRadius = UDim.new(0, r or 10), Parent = o})
	return o
end

function Ui.pad(o, p)
	make("UIPadding", {PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p), PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p), Parent = o})
	return o
end

function Ui.stroke(o, color, th)
	make("UIStroke", {Color = color or C.acc, Thickness = th or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o})
	return o
end

function Ui.list(o, padding, horizontal, align)
	return make("UIListLayout", {Padding = UDim.new(0, padding or 8), FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = align or Enum.HorizontalAlignment.Left, Parent = o})
end

function Ui.panel(props)
	local f = make("Frame", props)
	f.BackgroundColor3 = props.BackgroundColor3 or C.panel
	Ui.corner(f, 14)
	return f
end

function Ui.label(text, props)
	props = props or {}
	local l = make("TextLabel", props)
	l.Text = text
	l.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	l.TextWrapped = true
	return l
end

function Ui.button(text, props, onClick, style)
	props = props or {}
	local b = make("TextButton", props)
	b.Text = text
	b.AutoButtonColor = true
	b.BackgroundTransparency = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = props.TextSize or 17
	if style == "secondary" then
		b.BackgroundColor3 = C.panel2
		b.TextColor3 = C.text
	elseif style == "danger" then
		b.BackgroundColor3 = C.red
		b.TextColor3 = C.text
	else
		b.BackgroundColor3 = C.acc
		b.TextColor3 = Color3.fromRGB(26, 19, 0)
	end
	Ui.corner(b, 10)
	if onClick then b.MouseButton1Click:Connect(onClick) end
	return b
end

function Ui.bar(parent, props, frac, color)
	local back = make("Frame", props)
	back.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	back.BackgroundTransparency = 0.5
	back.Parent = parent
	Ui.corner(back, 4)
	local fill = make("Frame", {Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1), BackgroundColor3 = color or C.acc, Parent = back})
	Ui.corner(fill, 4)
	return back, fill
end

function Ui.clear(o)
	for _, ch in ipairs(o:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") and not ch:IsA("UICorner") and not ch:IsA("UIGridLayout") and not ch:IsA("UIStroke") then
			ch:Destroy()
		end
	end
end

function Ui.fmt(t)
	if not t then return "--:--.-" end
	local neg = t < 0
	t = math.abs(t)
	local m = math.floor(t / 60)
	local s = t - m * 60
	local str = string.format("%d:%04.1f", m, s)
	return neg and ("-" .. str) or str
end

function Ui.fmtDelta(d)
	if not d then return "" end
	return (d < 0 and "−" or "+") .. string.format("%.1f", math.abs(d))
end

function Ui.num(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^ ", ""))
end

return Ui

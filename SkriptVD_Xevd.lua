--!nonstrict
--==================================================================
-- XEVD Player Highlight v1.0
-- Единый LocalScript: Highlight игроков + GUI с вкладками.
-- Murder Mystery: Выжившие / Убийца (ровно один) / Нейтралы.
-- Куда: StarterPlayer → StarterPlayerScripts (LocalScript).
-- Открыть/закрыть: L  или  кнопка ⚙ в левом верхнем углу.
--==================================================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")
local camera      = workspace.CurrentCamera

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera
end)

--==================================================================
-- CONFIG
--==================================================================
local Config = {
	-- Флаги
	Enabled       = true,
	ShowSelf      = true,
	ShowSurvivors = true,
	ShowKillers   = true,
	ShowNeutral   = true,
	ShowName      = true,

	-- Производительность
	MaxDistance    = 350,
	UpdateInterval = 0.15,

	-- Highlight
	DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop,
	FillTransparency    = 0.50,
	OutlineTransparency = 0.10,

	-- Пороги HP
	HealthyThreshold = 99,
	InjuredThreshold = 2,

	-- Цвета команд
	SelfColor     = Color3.fromRGB(70, 150, 255),
	SurvivorColor = Color3.fromRGB(60, 220, 90),
	KillerColor   = Color3.fromRGB(255, 60, 60),
	NeutralColor  = Color3.fromRGB(200, 200, 210),

	-- Цвета HP-стадий (Fill)
	InjuredColor  = Color3.fromRGB(255, 180, 40),
	CrawlingColor = Color3.fromRGB(255, 40, 40),

	-- Ник
	NameFont        = Enum.Font.GothamBold,
	NameTextSize    = 14,
	NameStudsOffset = Vector3.new(0, 2.8, 0),

	-- GUI
	ToggleKey       = Enum.KeyCode.L,
	WindowAnchor    = 0.5,
	WindowTopOffset = 20,
	WindowSize      = Vector2.new(440, 540),

	-- Акцент темы
	AccentColor = Color3.fromRGB(150, 80, 255),

	-- Названия команд (нижний регистр). Дополняй под свою игру.
	SurvivorTeamNames = {
		["survivors"] = true, ["survivor"] = true,
		["innocents"] = true, ["innocent"] = true, ["sheriff"] = true,
		["выжившие"] = true, ["выживший"] = true,
		["мирные"] = true, ["шериф"] = true,
	},
	KillerTeamNames = {
		["killers"] = true, ["killer"] = true,
		["murderer"] = true, ["murderers"] = true,
		["убийцы"] = true, ["убийца"] = true,
		["маньяк"] = true, ["маньяки"] = true,
	},
}

--==================================================================
-- THEME
--==================================================================
local Theme = {
	WindowBg      = Color3.fromRGB(18, 18, 24),
	HeaderBg      = Color3.fromRGB(28, 28, 38),
	TabBarBg      = Color3.fromRGB(22, 22, 30),
	RowBg         = Color3.fromRGB(24, 24, 32),
	InputBg       = Color3.fromRGB(14, 14, 20),

	TextPrimary   = Color3.fromRGB(235, 235, 245),
	TextSecondary = Color3.fromRGB(165, 165, 180),
	TextMuted     = Color3.fromRGB(120, 120, 135),

	StrokeIdle    = Color3.fromRGB(60, 60, 75),
	ToggleOn      = Color3.fromRGB(60, 200, 100),
	ToggleOff     = Color3.fromRGB(60, 60, 75),
	CloseRed      = Color3.fromRGB(220, 70, 70),
	CloseRedHover = Color3.fromRGB(255, 90, 90),

	Radius        = 10,
	RowRadius     = 8,
	TabRadius     = 8,
	Padding       = 12,

	FontLogo      = Enum.Font.GothamBlack,
	FontBold      = Enum.Font.GothamBold,
	FontRegular   = Enum.Font.Gotham,
	FontMono      = Enum.Font.Code,

	LogoSize      = 22,
	SubSize       = 11,
	HeaderSize    = 11,
	TextSize      = 13,
	InputSize     = 13,
}

--==================================================================
-- TABS (легко добавлять новые)
--==================================================================
local Tabs = {
	{ id = "highlight", name = "Подсветка", order = 1 },
	{ id = "colors",    name = "Цвета",     order = 2 },
	{ id = "info",      name = "Инфо",      order = 3 },
	{ id = "about",     name = "О скрипте", order = 4 },
}

--==================================================================
-- УТИЛИТЫ
--==================================================================
local function hexToColor3(hex)
	if type(hex) ~= "string" then return nil end
	hex = hex:gsub("^#", ""):upper()
	if #hex ~= 6 or not hex:match("^%x+$") then return nil end
	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)
	if not r or not g or not b then return nil end
	return Color3.fromRGB(r, g, b)
end

local function color3ToHex(c)
	return string.format("#%02X%02X%02X",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5))
end

local function tweenColor(inst, prop, target, dur)
	TweenService:Create(inst,
		TweenInfo.new(dur or 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{[prop] = target}):Play()
end

--==================================================================
-- ДЕТЕКТ РОЛЕЙ / КОМАНД
--==================================================================
local function classifyRoleString(s)
	if not s or s == "" then return nil end
	local lower = s:lower()
	if Config.SurvivorTeamNames[lower] then return "survivor" end
	if Config.KillerTeamNames[lower] then return "killer" end
	return nil
end

local function detectFromTeam(player)
	local team = player.Team
	if not team then return nil end
	return classifyRoleString(team.Name)
end

local function detectFromAttributes(player)
	if player:GetAttribute("IsKiller") == true then return "killer" end
	local a = player:GetAttribute("Team")
	if type(a) == "string" then
		local c = classifyRoleString(a); if c then return c end
	end
	a = player:GetAttribute("Role")
	if type(a) == "string" then
		local c = classifyRoleString(a); if c then return c end
	end
	return nil
end

local function detectFromLeaderstats(player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then return nil end
	for _, obj in ipairs(ls:GetChildren()) do
		if obj:IsA("StringValue") then
			local c = classifyRoleString(obj.Value); if c then return c end
		elseif obj:IsA("BoolValue") and obj.Value then
			local c = classifyRoleString(obj.Name); if c then return c end
		end
	end
	return nil
end

local function detectFromCharacter(player)
	local char = player.Character
	if not char then return nil end
	local a = char:GetAttribute("Role")
	if type(a) == "string" then
		local c = classifyRoleString(a); if c then return c end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		local hr = hum:GetAttribute("Role")
		if type(hr) == "string" then
			local c = classifyRoleString(hr); if c then return c end
		end
	end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("StringValue") then
			local c = classifyRoleString(child.Value); if c then return c end
		elseif child:IsA("BoolValue") and child.Value then
			local c = classifyRoleString(child.Name); if c then return c end
		end
	end
	return nil
end

-- Fallback-поиск убийцы: если кто-то один отличается от большинства.
local fallbackKillerUserId = nil

local function computeFallbackKiller()
	local sigs, counts, list = {}, {}, {}
	for _, p in ipairs(Players:GetPlayers()) do
		local ch  = p.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then continue end
		local sig
		if p.Team then
			sig = "T|" .. p.Team.Name .. "|" .. tostring(p.Team.TeamColor.Number)
		else
			sig = "NONE"
		end
		sigs[p] = sig
		counts[sig] = (counts[sig] or 0) + 1
		table.insert(list, p)
	end

	local dominant, dCount = nil, 0
	for sig, c in pairs(counts) do
		if sig ~= "NONE" and c > dCount then dominant, dCount = sig, c end
	end
	if not dominant or dCount < 2 then fallbackKillerUserId = nil; return end

	local odd, oddCount = nil, 0
	for _, p in ipairs(list) do
		local s = sigs[p]
		if s ~= dominant and s ~= "NONE" then odd, oddCount = p, oddCount + 1 end
	end
	if oddCount == 1 and odd then fallbackKillerUserId = odd.UserId
	else fallbackKillerUserId = nil end
end

local function detectRole(player)
	local c = detectFromTeam(player);   if c then return c end
	c = detectFromAttributes(player);   if c then return c end
	c = detectFromLeaderstats(player);  if c then return c end
	c = detectFromCharacter(player);    if c then return c end

	if fallbackKillerUserId == player.UserId then return "killer" end

	-- Наследуем категорию, если команда совпадает с командой локального игрока.
	if player.Team and localPlayer.Team and player.Team == localPlayer.Team then
		local lc = classifyRoleString(localPlayer.Team.Name)
		if lc then return lc end
	end
	return "neutral"
end

local function detectKind(player)
	if player == localPlayer then return "self" end
	return detectRole(player)
end

local function getTeamColor(kind)
	if kind == "self" then return Config.SelfColor end
	if kind == "survivor" then return Config.SurvivorColor end
	if kind == "killer" then return Config.KillerColor end
	return Config.NeutralColor
end

local function getFillColor(kind, humanoid)
	local hp = humanoid.Health
	if hp >= Config.HealthyThreshold then return getTeamColor(kind)
	elseif hp >= Config.InjuredThreshold then return Config.InjuredColor
	else return Config.CrawlingColor end
end

local function allowedByKind(kind)
	if kind == "self" then return Config.ShowSelf end
	if kind == "survivor" then return Config.ShowSurvivors end
	if kind == "killer" then return Config.ShowKillers end
	if kind == "neutral" then return Config.ShowNeutral end
	return false
end

--==================================================================
-- СОСТОЯНИЕ ИГРОКОВ
--==================================================================
local states = {}

local function clearVisuals(state)
	if state.highlight then state.highlight:Destroy(); state.highlight = nil end
	if state.billboard then
		state.billboard:Destroy(); state.billboard = nil; state.nameLabel = nil
	end
end

local function addPlayer(p)
	if states[p] then return end
	states[p] = { highlight = nil, billboard = nil, nameLabel = nil }
end

local function removePlayer(p)
	local st = states[p]
	if not st then return end
	clearVisuals(st)
	states[p] = nil
end

for _, p in ipairs(Players:GetPlayers()) do addPlayer(p) end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)

--==================================================================
-- ACCENT REFERENCES
--==================================================================
local accentRefs = {}
local renderTabsActiveState = function() end  -- переопределится ниже

local function useAccent(inst, prop)
	table.insert(accentRefs, {inst = inst, prop = prop})
	inst[prop] = Config.AccentColor
end

local function refreshAccent()
	for _, r in ipairs(accentRefs) do r.inst[r.prop] = Config.AccentColor end
	renderTabsActiveState()
end

--==================================================================
-- SCREEN GUI / КНОПКА ⚙
--==================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "XEVD_Highlight"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local gear = Instance.new("TextButton")
gear.Name = "Gear"
gear.Size = UDim2.fromOffset(38, 38)
gear.Position = UDim2.fromOffset(8, 8)
gear.BackgroundColor3 = Theme.WindowBg
gear.BackgroundTransparency = 0.15
gear.Text = "⚙"
gear.Font = Theme.FontBold
gear.TextSize = 22
gear.AutoButtonColor = false
gear.Parent = screenGui

local gearCorner = Instance.new("UICorner")
gearCorner.CornerRadius = UDim.new(0, Theme.Radius)
gearCorner.Parent = gear

local gearStroke = Instance.new("UIStroke")
gearStroke.Transparency = 0.5
gearStroke.Thickness = 1.2
gearStroke.Parent = gear
useAccent(gearStroke, "Color")
useAccent(gear, "TextColor3")

gear.MouseEnter:Connect(function() tweenColor(gear, "TextColor3", Color3.fromRGB(255,255,255), 0.15) end)
gear.MouseLeave:Connect(function() tweenColor(gear, "TextColor3", Config.AccentColor, 0.15) end)

--==================================================================
-- ОКНО (CanvasGroup для fade) + Scaler (для scale)
--==================================================================
local container = Instance.new("CanvasGroup")
container.Name = "WindowContainer"
container.AnchorPoint = Vector2.new(Config.WindowAnchor, 0)
container.Position = UDim2.new(Config.WindowAnchor, 0, 0, Config.WindowTopOffset)
container.Size = UDim2.fromOffset(Config.WindowSize.X, Config.WindowSize.Y)
container.BackgroundTransparency = 1
container.GroupTransparency = 1
container.Visible = false
container.Parent = screenGui

local shadow = Instance.new("Frame")
shadow.Position = UDim2.fromOffset(6, 8)
shadow.Size = UDim2.new(1, 0, 1, 0)
shadow.BackgroundColor3 = Color3.new(0, 0, 0)
shadow.BackgroundTransparency = 0.55
shadow.BorderSizePixel = 0
shadow.ZIndex = 0
shadow.Parent = container

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, Theme.Radius + 2)
shadowCorner.Parent = shadow

local scaler = Instance.new("Frame")
scaler.Name = "Scaler"
scaler.AnchorPoint = Vector2.new(0.5, 0.5)
scaler.Position = UDim2.new(0.5, 0, 0.5, 0)
scaler.Size = UDim2.fromScale(1, 1)
scaler.BackgroundTransparency = 1
scaler.Parent = container

local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.fromScale(1, 1)
window.BackgroundColor3 = Theme.WindowBg
window.BackgroundTransparency = 0.06
window.BorderSizePixel = 0
window.ZIndex = 1
window.Parent = scaler

local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = UDim.new(0, Theme.Radius + 2)
winCorner.Parent = window

local winStroke = Instance.new("UIStroke")
winStroke.Transparency = 0.35
winStroke.Thickness = 1.2
winStroke.Parent = window
useAccent(winStroke, "Color")

--==================================================================
-- ЗАГОЛОВОК "XEVD"
--==================================================================
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = Theme.HeaderBg
titleBar.BackgroundTransparency = 0.05
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 2
titleBar.Parent = window

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, Theme.Radius + 2)
titleCorner.Parent = titleBar

local titleMask = Instance.new("Frame")
titleMask.Size = UDim2.new(1, 0, 0, 12)
titleMask.Position = UDim2.new(0, 0, 1, -12)
titleMask.BackgroundColor3 = titleBar.BackgroundColor3
titleMask.BackgroundTransparency = titleBar.BackgroundTransparency
titleMask.BorderSizePixel = 0
titleMask.ZIndex = 2
titleMask.Parent = titleBar

local titleDivider = Instance.new("Frame")
titleDivider.Size = UDim2.new(1, 0, 0, 1)
titleDivider.Position = UDim2.new(0, 0, 1, -1)
titleDivider.BackgroundTransparency = 0.7
titleDivider.BorderSizePixel = 0
titleDivider.ZIndex = 3
titleDivider.Parent = titleBar
useAccent(titleDivider, "BackgroundColor3")

local titleLogo = Instance.new("TextLabel")
titleLogo.BackgroundTransparency = 1
titleLogo.Position = UDim2.fromOffset(14, 2)
titleLogo.Size = UDim2.new(0, 130, 0, 26)
titleLogo.Text = "XEVD"
titleLogo.Font = Theme.FontLogo
titleLogo.TextSize = Theme.LogoSize
titleLogo.TextXAlignment = Enum.TextXAlignment.Left
titleLogo.ZIndex = 4
titleLogo.Parent = titleBar
useAccent(titleLogo, "TextColor3")

local titleSub = Instance.new("TextLabel")
titleSub.BackgroundTransparency = 1
titleSub.Position = UDim2.fromOffset(16, 26)
titleSub.Size = UDim2.new(1, -50, 0, 14)
titleSub.Text = "Player Highlight v1.0"
titleSub.Font = Theme.FontRegular
titleSub.TextSize = Theme.SubSize
titleSub.TextColor3 = Theme.TextMuted
titleSub.TextXAlignment = Enum.TextXAlignment.Left
titleSub.ZIndex = 4
titleSub.Parent = titleBar

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(28, 28)
closeButton.Position = UDim2.new(1, -36, 0.5, 0)
closeButton.AnchorPoint = Vector2.new(0, 0.5)
closeButton.BackgroundColor3 = Theme.CloseRed
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "×"
closeButton.Font = Theme.FontBold
closeButton.TextSize = 18
closeButton.AutoButtonColor = false
closeButton.ZIndex = 5
closeButton.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 7)
closeCorner.Parent = closeButton

closeButton.MouseEnter:Connect(function() tweenColor(closeButton, "BackgroundColor3", Theme.CloseRedHover, 0.15) end)
closeButton.MouseLeave:Connect(function() tweenColor(closeButton, "BackgroundColor3", Theme.CloseRed, 0.15) end)

--==================================================================
-- ТЕЛО: ЛЕВАЯ ПАНЕЛЬ ВКЛАДОК + ПРАВАЯ ОБЛАСТЬ
--==================================================================
local body = Instance.new("Frame")
body.Position = UDim2.fromOffset(0, 46)
body.Size = UDim2.new(1, 0, 1, -46)
body.BackgroundTransparency = 1
body.ZIndex = 1
body.Parent = window

local tabsList = Instance.new("Frame")
tabsList.Position = UDim2.fromOffset(12, 12)
tabsList.Size = UDim2.new(0, 110, 1, -24)
tabsList.BackgroundColor3 = Theme.TabBarBg
tabsList.BackgroundTransparency = 0.3
tabsList.BorderSizePixel = 0
tabsList.ZIndex = 2
tabsList.Parent = body

local tabsCorner = Instance.new("UICorner")
tabsCorner.CornerRadius = UDim.new(0, Theme.Radius)
tabsCorner.Parent = tabsList

local tabsPadding = Instance.new("UIPadding")
tabsPadding.PaddingTop = UDim.new(0, 8)
tabsPadding.PaddingBottom = UDim.new(0, 8)
tabsPadding.PaddingLeft = UDim.new(0, 6)
tabsPadding.PaddingRight = UDim.new(0, 6)
tabsPadding.Parent = tabsList

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.Padding = UDim.new(0, 6)
tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabsLayout.Parent = tabsList

local contentArea = Instance.new("Frame")
contentArea.Position = UDim2.new(0, 130, 0, 12)
contentArea.Size = UDim2.new(1, -142, 1, -24)
contentArea.BackgroundTransparency = 1
contentArea.ZIndex = 2
contentArea.Parent = body

--==================================================================
-- СОЗДАНИЕ ВКЛАДОК
--==================================================================
local tabFrames = {}
local tabButtons = {}
local activeTabId = nil

local function setTabActive(id)
	activeTabId = id
	for _, t in ipairs(Tabs) do
		local btn   = tabButtons[t.id]
		local frame = tabFrames[t.id]
		if btn and frame then
			if t.id == id then
				frame.Visible = true
				tweenColor(btn, "BackgroundColor3", Config.AccentColor, 0.2)
				tweenColor(btn, "TextColor3", Color3.fromRGB(255,255,255), 0.2)
			else
				frame.Visible = false
				tweenColor(btn, "BackgroundColor3", Theme.RowBg, 0.2)
				tweenColor(btn, "TextColor3", Theme.TextSecondary, 0.2)
			end
		end
	end
end

renderTabsActiveState = function()
	if activeTabId then setTabActive(activeTabId) end
end

for _, tab in ipairs(Tabs) do
	local btn = Instance.new("TextButton")
	btn.Name = tab.id
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = Theme.RowBg
	btn.TextColor3 = Theme.TextSecondary
	btn.Text = tab.name
	btn.Font = Theme.FontBold
	btn.TextSize = 13
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.AutoButtonColor = false
	btn.LayoutOrder = tab.order
	btn.ZIndex = 3
	btn.Parent = tabsList

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, Theme.TabRadius)
	btnCorner.Parent = btn

	local btnPad = Instance.new("UIPadding")
	btnPad.PaddingLeft = UDim.new(0, 10)
	btnPad.Parent = btn

	btn.MouseButton1Click:Connect(function()
		setTabActive(tab.id)
	end)

	tabButtons[tab.id] = btn

	local frame = Instance.new("ScrollingFrame")
	frame.Name = tab.id .. "Panel"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 4
	frame.ScrollBarImageColor3 = Config.AccentColor
	frame.CanvasSize = UDim2.new(0, 0, 0, 0)
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.Visible = false
	frame.ZIndex = 3
	frame.Parent = contentArea

	local framePad = Instance.new("UIPadding")
	framePad.PaddingTop = UDim.new(0, 4)
	framePad.PaddingBottom = UDim.new(0, 8)
	framePad.PaddingLeft = UDim.new(0, 4)
	framePad.PaddingRight = UDim.new(0, 4)
	framePad.Parent = frame

	local frameLayout = Instance.new("UIListLayout")
	frameLayout.Padding = UDim.new(0, 6)
	frameLayout.SortOrder = Enum.SortOrder.LayoutOrder
	frameLayout.Parent = frame

	tabFrames[tab.id] = frame
end

--==================================================================
-- КОМПОНЕНТЫ МЕНЮ
--==================================================================
local function makeSection(parent, order, title)
	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, 0, 0, 22)
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder = order
	wrap.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 100, 1, -4)
	label.Position = UDim2.new(0, 2, 0, 0)
	label.Text = title:upper()
	label.Font = Theme.FontBold
	label.TextSize = Theme.HeaderSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = wrap
	useAccent(label, "TextColor3")

	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.Position = UDim2.new(0, 108, 0.5, 0)
	line.Size = UDim2.new(1, -108, 0, 1)
	line.BackgroundTransparency = 0.75
	line.BorderSizePixel = 0
	line.Parent = wrap
	useAccent(line, "BackgroundColor3")
end

local function makeRow(parent, order)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 32)
	row.BackgroundColor3 = Theme.RowBg
	row.BackgroundTransparency = 0.35
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = parent

	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, Theme.RowRadius)
	rc.Parent = row

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = row

	return row
end

local function makeLabel(parent, text)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -110, 1, 0)
	l.Text = text
	l.Font = Theme.FontRegular
	l.TextSize = Theme.TextSize
	l.TextColor3 = Theme.TextPrimary
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function makeToggle(parent, order, text, initial, onChange)
	local row = makeRow(parent, order)
	makeLabel(row, text)

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(92, 24)
	btn.Position = UDim2.new(1, 0, 0.5, 0)
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Font = Theme.FontBold
	btn.TextSize = 11
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.AutoButtonColor = false
	btn.Parent = row

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 6)
	bc.Parent = btn

	local state = initial
	local function render(animate)
		local target = state and Theme.ToggleOn or Theme.ToggleOff
		btn.Text = state and "ВКЛ" or "ВЫКЛ"
		if animate then tweenColor(btn, "BackgroundColor3", target, 0.2)
		else btn.BackgroundColor3 = target end
	end
	render(false)

	btn.MouseButton1Click:Connect(function()
		state = not state
		render(true)
		onChange(state)
	end)
end

local function makeNumberInput(parent, order, text, initial, onChange)
	local row = makeRow(parent, order)
	makeLabel(row, text)

	local box = Instance.new("TextBox")
	box.Size = UDim2.fromOffset(110, 24)
	box.Position = UDim2.new(1, 0, 0.5, 0)
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.BackgroundColor3 = Theme.InputBg
	box.TextColor3 = Theme.TextPrimary
	box.Text = tostring(initial)
	box.Font = Theme.FontMono
	box.TextSize = Theme.InputSize
	box.ClearTextOnFocus = false
	box.Parent = row

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 6)
	bc.Parent = box

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.StrokeIdle
	stroke.Thickness = 1
	stroke.Parent = box

	box.Focused:Connect(function() tweenColor(stroke, "Color", Config.AccentColor, 0.15) end)
	box.FocusLost:Connect(function()
		tweenColor(stroke, "Color", Theme.StrokeIdle, 0.15)
		local n = tonumber(box.Text)
		if n and n > 0 then
			onChange(n)
			box.Text = tostring(math.floor(n))
		else
			box.Text = tostring(initial)
		end
	end)
end

local function makeColorInput(parent, order, text, initial, onChange)
	local row = makeRow(parent, order)
	makeLabel(row, text)

	local preview = Instance.new("Frame")
	preview.Size = UDim2.fromOffset(22, 22)
	preview.Position = UDim2.new(1, 0, 0.5, 0)
	preview.AnchorPoint = Vector2.new(1, 0.5)
	preview.BackgroundColor3 = initial
	preview.BorderSizePixel = 0
	preview.Parent = row

	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 5)
	pc.Parent = preview

	local ps = Instance.new("UIStroke")
	ps.Color = Theme.StrokeIdle
	ps.Parent = preview

	local box = Instance.new("TextBox")
	box.Size = UDim2.fromOffset(88, 24)
	box.Position = UDim2.new(1, -30, 0.5, 0)
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.BackgroundColor3 = Theme.InputBg
	box.TextColor3 = Theme.TextPrimary
	box.Text = color3ToHex(initial)
	box.Font = Theme.FontMono
	box.TextSize = Theme.InputSize
	box.ClearTextOnFocus = false
	box.Parent = row

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 6)
	bc.Parent = box

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.StrokeIdle
	stroke.Thickness = 1
	stroke.Parent = box

	box:GetPropertyChangedSignal("Text"):Connect(function()
		local c = hexToColor3(box.Text)
		if c then
			preview.BackgroundColor3 = c
			onChange(c)
		end
	end)

	box.Focused:Connect(function() tweenColor(stroke, "Color", Config.AccentColor, 0.15) end)
	box.FocusLost:Connect(function()
		tweenColor(stroke, "Color", Theme.StrokeIdle, 0.15)
		local c = hexToColor3(box.Text)
		if c then
			box.Text = color3ToHex(c)
		else
			box.Text = color3ToHex(initial)
			preview.BackgroundColor3 = initial
		end
	end)
end

--============================================================
-- ВКЛАДКА "ПОДСВЕТКА"
--============================================================
do
	local t = tabFrames["highlight"]

	makeSection(t, 1, "Основное")
	makeToggle(t, 2, "Подсветка", Config.Enabled, function(v) Config.Enabled = v end)
	makeToggle(t, 3, "Показывать себя", Config.ShowSelf, function(v) Config.ShowSelf = v end)
	makeToggle(t, 4, "Ник над головой", Config.ShowName, function(v)
		Config.ShowName = v
		if not v then
			for _, st in pairs(states) do
				if st.billboard then
					st.billboard:Destroy(); st.billboard = nil; st.nameLabel = nil
				end
			end
		end
	end)
	makeNumberInput(t, 5, "Дистанция (studs)", Config.MaxDistance, function(v)
		Config.MaxDistance = v
	end)

	makeSection(t, 6, "Команды")
	makeToggle(t, 7, "Показывать выживших",    Config.ShowSurvivors, function(v) Config.ShowSurvivors = v end)
	makeToggle(t, 8, "Показывать убийц",       Config.ShowKillers,   function(v) Config.ShowKillers   = v end)
	makeToggle(t, 9, "Показывать нейтральных", Config.ShowNeutral,   function(v) Config.ShowNeutral   = v end)
end

--============================================================
-- ВКЛАДКА "ЦВЕТА"
--============================================================
do
	local t = tabFrames["colors"]

	makeSection(t, 1, "Команды")
	makeColorInput(t, 2, "Себя",        Config.SelfColor,     function(c) Config.SelfColor     = c end)
	makeColorInput(t, 3, "Выжившие",    Config.SurvivorColor, function(c) Config.SurvivorColor = c end)
	makeColorInput(t, 4, "Убийцы",      Config.KillerColor,   function(c) Config.KillerColor   = c end)
	makeColorInput(t, 5, "Нейтральные", Config.NeutralColor,  function(c) Config.NeutralColor  = c end)

	makeSection(t, 6, "HP-стадии (Fill)")
	makeColorInput(t, 7, "Ранен",  Config.InjuredColor,  function(c) Config.InjuredColor  = c end)
	makeColorInput(t, 8, "Ползёт", Config.CrawlingColor, function(c) Config.CrawlingColor = c end)

	makeSection(t, 9, "Тема")
	makeColorInput(t, 10, "Акцент", Config.AccentColor, function(c)
		Config.AccentColor = c
		refreshAccent()
	end)
end

--============================================================
-- ВКЛАДКА "ИНФО"
--============================================================
local infoValues = {}

local function makeInfoRow(parent, order, labelText, key, withColor)
	local row = makeRow(parent, order)

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(0.5, 0, 1, 0)
	lbl.Text = labelText
	lbl.Font = Theme.FontRegular
	lbl.TextSize = Theme.TextSize
	lbl.TextColor3 = Theme.TextSecondary
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local valueOffset = withColor and -22 or 0

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.new(1, valueOffset, 0.5, 0)
	value.Size = UDim2.new(0.5, valueOffset, 1, 0)
	value.Text = "—"
	value.Font = Theme.FontBold
	value.TextSize = Theme.TextSize
	value.TextColor3 = Theme.TextPrimary
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextTruncate = Enum.TextTruncate.AtEnd
	value.Parent = row

	local colorFrame
	if withColor then
		colorFrame = Instance.new("Frame")
		colorFrame.Size = UDim2.fromOffset(14, 14)
		colorFrame.Position = UDim2.new(1, 0, 0.5, 0)
		colorFrame.AnchorPoint = Vector2.new(1, 0.5)
		colorFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		colorFrame.BorderSizePixel = 0
		colorFrame.Visible = false
		colorFrame.Parent = row

		local cfc = Instance.new("UICorner")
		cfc.CornerRadius = UDim.new(0, 4)
		cfc.Parent = colorFrame

		local cfs = Instance.new("UIStroke")
		cfs.Color = Theme.StrokeIdle
		cfs.Parent = colorFrame
	end

	infoValues[key] = { value = value, colorFrame = colorFrame }
end

do
	local t = tabFrames["info"]

	makeSection(t, 1, "Матч")
	makeInfoRow(t, 2, "Место",     "placeName")
	makeInfoRow(t, 3, "PlaceId",   "placeId")
	makeInfoRow(t, 4, "JobId",     "jobId")
	makeInfoRow(t, 5, "Игроков",   "players")

	makeSection(t, 6, "Я")
	makeInfoRow(t, 7, "Ник",       "myName")
	makeInfoRow(t, 8, "Команда",   "myTeam", true)
	makeInfoRow(t, 9, "Роль",      "myRole")
	makeInfoRow(t, 10, "HP",       "myHp")

	makeSection(t, 11, "Сейчас")
	makeInfoRow(t, 12, "Убийца",    "killer")
	makeInfoRow(t, 13, "Подсвечено", "highlighted")
end

--============================================================
-- ВКЛАДКА "О СКРИПТЕ"
--============================================================
do
	local t = tabFrames["about"]

	local aboutFrame = Instance.new("Frame")
	aboutFrame.Size = UDim2.new(1, 0, 0, 320)
	aboutFrame.BackgroundColor3 = Theme.RowBg
	aboutFrame.BackgroundTransparency = 0.35
	aboutFrame.BorderSizePixel = 0
	aboutFrame.LayoutOrder = 1
	aboutFrame.Parent = t

	local afc = Instance.new("UICorner")
	afc.CornerRadius = UDim.new(0, Theme.RowRadius)
	afc.Parent = aboutFrame

	local afp = Instance.new("UIPadding")
	afp.PaddingTop = UDim.new(0, 12)
	afp.PaddingBottom = UDim.new(0, 12)
	afp.PaddingLeft = UDim.new(0, 14)
	afp.PaddingRight = UDim.new(0, 14)
	afp.Parent = aboutFrame

	local aboutLabel = Instance.new("TextLabel")
	aboutLabel.BackgroundTransparency = 1
	aboutLabel.Size = UDim2.fromScale(1, 1)
	aboutLabel.Font = Theme.FontRegular
	aboutLabel.TextSize = 13
	aboutLabel.TextColor3 = Theme.TextPrimary
	aboutLabel.TextXAlignment = Enum.TextXAlignment.Left
	aboutLabel.TextYAlignment = Enum.TextYAlignment.Top
	aboutLabel.TextWrapped = true
	aboutLabel.Text = table.concat({
		"XEVD Player Highlight v1.0",
		"",
		"Клиентская система подсветки игроков через Instance Highlight.",
		"Murder Mystery: разделение по командам + HP-стадии.",
		"",
		"Хоткеи:",
		"   L — открыть/закрыть окно",
		"   ⚙ — кнопка в левом верхнем углу",
		"",
		"Возможности:",
		"   • Highlight на персонаже, AlwaysOnTop.",
		"   • Контур = цвет команды.",
		"   • Fill = цвет HP-стадии.",
		"   • Ник над головой (BillboardGui).",
		"   • Тумблеры для каждой категории.",
		"   • Настройка всех цветов и дистанции.",
		"",
		"Убийца подсвечивается всегда — даже если",
		"его команда не определена, он попадает",
		"в нейтральные либо ловится по большинству.",
	}, "\n")
	aboutLabel.Parent = aboutFrame
end

-- Активируем первую вкладку
setTabActive(Tabs[1].id)

--==================================================================
-- ОТКРЫТИЕ / ЗАКРЫТИЕ
--==================================================================
local isOpen = false
local slideOffset = 14

local function openWindow()
	if isOpen then return end
	isOpen = true
	container.Visible = true
	local targetPos = container.Position
	container.Position = UDim2.new(
		targetPos.X.Scale, targetPos.X.Offset,
		targetPos.Y.Scale, targetPos.Y.Offset - slideOffset
	)
	container.GroupTransparency = 1
	scaler.Size = UDim2.fromScale(0.96, 0.96)

	TweenService:Create(container,
		TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = targetPos, GroupTransparency = 0 }):Play()
	TweenService:Create(scaler,
		TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(1, 1) }):Play()
end

local function closeWindow()
	if not isOpen then return end
	isOpen = false
	local curPos = container.Position
	local t1 = TweenService:Create(container,
		TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = UDim2.new(
				curPos.X.Scale, curPos.X.Offset,
				curPos.Y.Scale, curPos.Y.Offset - slideOffset
			),
			GroupTransparency = 1,
		})
	TweenService:Create(scaler,
		TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = UDim2.fromScale(0.96, 0.96) }):Play()
	t1.Completed:Connect(function()
		container.Visible = false
		-- Возвращаем позицию, чтобы при следующем открытии слайд шёл от «нормальной».
		container.Position = UDim2.new(
			curPos.X.Scale, curPos.X.Offset,
			curPos.Y.Scale, curPos.Y.Offset
		)
	end)
	t1:Play()
end

local function toggleWindow()
	if isOpen then closeWindow() else openWindow() end
end

gear.MouseButton1Click:Connect(toggleWindow)
closeButton.MouseButton1Click:Connect(closeWindow)

--============================================================
-- ПЕРЕТАСКИВАНИЕ
--============================================================
do
	local dragging = false
	local dragStart, startPos

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = container.Position
		end
	end)

	titleBar.InputChanged:Connect(function(input)
		if not dragging or not dragStart or not startPos then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			container.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	titleBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

--============================================================
-- КЛАВИША L
--============================================================
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode ~= Config.ToggleKey then return end
	if UserInputService:GetFocusedTextBox() then return end
	toggleWindow()
end)

--==================================================================
-- ОБНОВЛЕНИЕ ОДНОГО ИГРОКА
--==================================================================
local function updatePlayer(player, state)
	local character = player.Character
	local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
	local head      = character and character:FindFirstChild("Head")
	local rootPart  = character and character:FindFirstChild("HumanoidRootPart")

	local alive = humanoid ~= nil and humanoid.Health > 0 and rootPart ~= nil

	local kind    = detectKind(player)
	local allowed = Config.Enabled and allowedByKind(kind)

	local inRange = false
	if alive and camera and rootPart then
		inRange = (camera.CFrame.Position - rootPart.Position).Magnitude <= Config.MaxDistance
	end

	if not (allowed and alive and inRange) then
		clearVisuals(state)
		return
	end

	-- Highlight
	if not state.highlight or state.highlight.Parent ~= character then
		if state.highlight then state.highlight:Destroy() end
		local h = Instance.new("Highlight")
		h.Name = "__XEVD_Highlight"
		h.Adornee = character
		h.DepthMode = Config.DepthMode
		h.Parent = character
		state.highlight = h
	end

	local h = state.highlight
	local outline = getTeamColor(kind)
	local fill    = getFillColor(kind, humanoid)
	if h then
		h.OutlineColor        = outline
		h.FillColor           = fill
		h.FillTransparency    = Config.FillTransparency
		h.OutlineTransparency = Config.OutlineTransparency
		h.DepthMode           = Config.DepthMode
	end

	-- Billboard с ником
	if Config.ShowName and head then
		if not state.billboard or state.billboard.Parent ~= head then
			if state.billboard then state.billboard:Destroy() end

			local bb = Instance.new("BillboardGui")
			bb.Name = "__XEVD_Name"
			bb.Size = UDim2.fromOffset(220, 28)
			bb.StudsOffset = Config.NameStudsOffset
			bb.AlwaysOnTop = true
			bb.Adornee = head

			local label = Instance.new("TextLabel")
			label.Name = "NameLabel"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = player.Name
			label.Font = Config.NameFont
			label.TextSize = Config.NameTextSize
			label.TextStrokeTransparency = 0.4
			label.Parent = bb

			bb.Parent = head
			state.billboard = bb
			state.nameLabel = label
		end

		local label = state.nameLabel
		if label then
			label.Text = player.Name
			label.TextColor3 = outline
		end
	elseif state.billboard then
		state.billboard:Destroy(); state.billboard = nil; state.nameLabel = nil
	end
end

--==================================================================
-- ГЛАВНЫЙ ЦИКЛ ПОДСВЕТКИ
--==================================================================
task.spawn(function()
	while true do
		task.wait(Config.UpdateInterval)

		if not Config.Enabled then
			for _, st in pairs(states) do clearVisuals(st) end
			continue
		end

		computeFall

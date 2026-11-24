-- BY Supremo Gestao v5.5 - Preset Config Supremo (Delta-safe)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

for _, name in ipairs({"SUPREMO_PANEL_GUI", "DARK_LAG_HUB", "DARK_LAG_FPS"}) do
	local old = playerGui:FindFirstChild(name)
	if old then
		pcall(function() old:Destroy() end)
	end
end

local config = {
	hubActive = true,
	panelOpen = true,
	minimizedToSquare = false,

	-- AIMBOT: ligado (ON), alcance extra 60 st, Ignorar time desligado
	aimAssistEnabled = true,
	punchAssistRange = 60,
	punchAssistStrength = 0.65,
	ignoreTeam = false,

	-- FOV: ativo em 60 sem desenhar o círculo na tela e sem extra
	fovEnabled = true,
	fovValue = 60,
	fovRadius = 120,
	fovOpacity = 0,
	showFovCircle = false,
	fovFilled = false,

	-- ESP: ligado (ON), modo Cheia, alcance max 500 m, sem Linhas e sem círculo extra
	espEnabled = true,
	espBox = false,
	espName = false,
	espDistance = false,
	espHealth = false,
	espLines = false,
	espStyle = "Cheia",
	espMaxDistance = 500,

	-- TEXTURA: ligada (ON) com tema rosa no mapa (Azul + Rosa / rosa no chão e blocos)
	mapVisualsEnabled = true,
	mapTheme = "Azul + Rosa",
	lineColorPreset = "Roxo",
	lagOptEnabled = true,
	spiderVisualEnabled = true,
	dashImpulse = 64,
	dashNoclipEnabled = false,
	zeroDelayJumpEnabled = true,
	zeroDelayDashEnabled = true,
	zeroDelayPunchEnabled = true,
	activeChannel = "Aimbot"
}

local savedProfiles = {
	["Padrao"] = table.clone(config),
	["Supremo"] = table.clone(config)
}

local espHighlights = {}
local originalFov = nil
local lastJumpAt = 0
local lastDashAt = 0
local lastPunchAt = 0

local function getCharacterRoot(char)
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
end

local function isEnemyPlayer(targetPlayer)
	if not targetPlayer or targetPlayer == player then return false end
	if config.ignoreTeam then return true end
	local okLocal, localTeam = pcall(function() return player.Team end)
	local okTarget, targetTeam = pcall(function() return targetPlayer.Team end)
	if okLocal and okTarget and localTeam and targetTeam then
		return localTeam ~= targetTeam
	end
	return true
end

local function triggerZeroDelayJump()
	if not config.hubActive or not config.zeroDelayJumpEnabled then return end
	local now = os.clock()
	if now - lastJumpAt < 0.06 then return end
	lastJumpAt = now
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			hum.Jump = true
		end)
	end
end

local function triggerZeroDelayDash()
	if not config.hubActive or not config.zeroDelayDashEnabled then return end
	local now = os.clock()
	if now - lastDashAt < 0.12 then return end
	lastDashAt = now
	local char = player.Character
	local root = getCharacterRoot(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end

	local moveDir = hum.MoveDirection
	if moveDir.Magnitude < 0.05 then
		local cam = Workspace.CurrentCamera
		moveDir = cam and Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z) or root.CFrame.LookVector
		if moveDir.Magnitude < 0.05 then
			moveDir = root.CFrame.LookVector
		end
	end
	moveDir = moveDir.Unit
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.new(
			moveDir.X * config.dashImpulse,
			math.max(root.AssemblyLinearVelocity.Y, 6),
			moveDir.Z * config.dashImpulse
		)
	end)
end

local function triggerZeroDelayPunch()
	if not config.hubActive or not config.zeroDelayPunchEnabled then return end
	local now = os.clock()
	if now - lastPunchAt < 0.08 then return end
	lastPunchAt = now
	local char = player.Character
	if not char then return end
	for _, item in ipairs(char:GetChildren()) do
		if item:IsA("Tool") then
			pcall(function() item:Activate() end)
		end
	end
end

local function applyRosaMapTheme()
	if not config.hubActive or not config.mapVisualsEnabled then return end
	pcall(function()
		Lighting.Ambient = Color3.fromRGB(165, 95, 145)
		Lighting.OutdoorAmbient = Color3.fromRGB(165, 95, 145)
		Lighting.FogColor = Color3.fromRGB(68, 16, 48)
		Lighting.FogEnd = 420
		Lighting.Brightness = 1.35
	end)

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and not obj:IsA("Terrain") then
			local humModel = obj:FindFirstAncestorOfClass("Model")
			local isChar = humModel and humModel:FindFirstChildOfClass("Humanoid")
			if not isChar then
				pcall(function()
					obj.Color = Color3.fromRGB(235, 85, 175)
					obj.Material = Enum.Material.SmoothPlastic
				end)
			end
		end
	end
end

local function applyCameraFov()
	local cam = Workspace.CurrentCamera
	if not cam or not config.hubActive or not config.fovEnabled then return end
	if originalFov == nil then
		local ok, cur = pcall(function() return cam.FieldOfView end)
		if ok and type(cur) == "number" then originalFov = cur end
	end
	pcall(function()
		cam.FieldOfView = config.fovValue
	end)
end

local function setFovValue(newVal)
	local num = tonumber(newVal)
	if not num then return end
	config.fovValue = math.clamp(math.floor(num + 0.5), 30, 120)
	config.fovEnabled = true
	config.showFovCircle = false
	config.fovFilled = false
	applyCameraFov()
end

local function updateEspCheia()
	local myChar = player.Character
	local myRoot = getCharacterRoot(myChar)

	if not config.hubActive or not config.espEnabled then
		for _, hl in pairs(espHighlights) do
			if hl then hl.Enabled = false end
		end
		return
	end

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer ~= player then
			local char = targetPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = getCharacterRoot(char)
			local dist = (myRoot and root) and (root.Position - myRoot.Position).Magnitude or 0
			local valid = isEnemyPlayer(targetPlayer) and char and char.Parent and hum and hum.Health > 0 and dist <= config.espMaxDistance

			if valid then
				local hl = espHighlights[targetPlayer]
				if not hl or not hl.Parent then
					hl = Instance.new("Highlight")
					hl.Name = "SUPREMO_ESP_CHEIA"
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Parent = playerGui
					espHighlights[targetPlayer] = hl
				end
				hl.Adornee = char
				hl.FillColor = Color3.fromRGB(220, 255, 40)
				hl.FillTransparency = 0.35
				hl.OutlineColor = Color3.fromRGB(220, 255, 40)
				hl.OutlineTransparency = 0
				hl.Enabled = true
			elseif espHighlights[targetPlayer] then
				espHighlights[targetPlayer].Enabled = false
			end
		end
	end
end

local function applySupremoPreset()
	config.hubActive = true
	config.aimAssistEnabled = true
	config.punchAssistRange = 60
	config.ignoreTeam = false

	config.fovEnabled = true
	config.fovValue = 60
	config.showFovCircle = false
	config.fovFilled = false

	config.espEnabled = true
	config.espStyle = "Cheia"
	config.espMaxDistance = 500
	config.espLines = false

	config.mapVisualsEnabled = true
	config.mapTheme = "Azul + Rosa"

	config.zeroDelayJumpEnabled = true
	config.zeroDelayDashEnabled = true
	config.zeroDelayPunchEnabled = true

	savedProfiles["Supremo"] = table.clone(config)
	applyCameraFov()
	applyRosaMapTheme()
	updateEspCheia()
end

pcall(function()
	UIS.JumpRequest:Connect(triggerZeroDelayJump)
	UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.Q then
			triggerZeroDelayDash()
		elseif input.KeyCode == Enum.KeyCode.F or input.UserInputType == Enum.UserInputType.MouseButton1 then
			triggerZeroDelayPunch()
		end
	end)
	RunService.RenderStepped:Connect(function()
		applyCameraFov()
		updateEspCheia()
	end)
end)

local function buildPanel()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SUPREMO_PANEL_GUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local miniBtn = Instance.new("TextButton")
	miniBtn.Name = "MiniSP"
	miniBtn.Size = UDim2.fromOffset(42, 42)
	miniBtn.Position = UDim2.new(0, 14, 0.85, 0)
	miniBtn.BackgroundColor3 = Color3.fromRGB(95, 38, 195)
	miniBtn.Text = "SP"
	miniBtn.Font = Enum.Font.GothamBold
	miniBtn.TextSize = 13
	miniBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	miniBtn.Visible = false
	miniBtn.Active = true
	miniBtn.Draggable = true
	miniBtn.Parent = gui
	Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(0, 8)

	local main = Instance.new("Frame")
	main.Name = "MainPanel"
	main.Size = UDim2.fromOffset(430, 270)
	main.Position = UDim2.new(0.5, -215, 0.22, 0)
	main.BackgroundColor3 = Color3.fromRGB(14, 8, 24)
	main.BorderSizePixel = 0
	main.Active = true
	main.Draggable = true
	main.Parent = gui
	Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", main)
	stroke.Color = Color3.fromRGB(175, 65, 255)
	stroke.Thickness = 2

	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 34)
	topBar.BackgroundColor3 = Color3.fromRGB(26, 14, 46)
	topBar.BorderSizePixel = 0
	topBar.Parent = main
	Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -90, 1, 0)
	title.Position = UDim2.fromOffset(12, 0)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 12
	title.TextColor3 = Color3.fromRGB(235, 190, 255)
	title.Text = "Supremo Gestão  v5.5"
	title.Parent = topBar

	local minBtn = Instance.new("TextButton")
	minBtn.Size = UDim2.fromOffset(26, 24)
	minBtn.Position = UDim2.new(1, -62, 0.5, -12)
	minBtn.BackgroundColor3 = Color3.fromRGB(65, 30, 115)
	minBtn.Text = "-"
	minBtn.Font = Enum.Font.GothamBold
	minBtn.TextSize = 16
	minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	minBtn.Parent = topBar
	Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(26, 24)
	closeBtn.Position = UDim2.new(1, -32, 0.5, -12)
	closeBtn.BackgroundColor3 = Color3.fromRGB(130, 25, 70)
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 13
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Parent = topBar
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

	local sideBar = Instance.new("Frame")
	sideBar.Size = UDim2.new(0, 130, 1, -44)
	sideBar.Position = UDim2.fromOffset(8, 40)
	sideBar.BackgroundColor3 = Color3.fromRGB(22, 13, 38)
	sideBar.BorderSizePixel = 0
	sideBar.Parent = main
	Instance.new("UICorner", sideBar).CornerRadius = UDim.new(0, 8)

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -150, 1, -44)
	content.Position = UDim2.fromOffset(144, 40)
	content.BackgroundColor3 = Color3.fromRGB(20, 11, 35)
	content.BorderSizePixel = 0
	content.Parent = main
	Instance.new("UICorner", content).CornerRadius = UDim.new(0, 8)

	local supremoBtn = Instance.new("TextButton")
	supremoBtn.Size = UDim2.new(1, -12, 0, 30)
	supremoBtn.Position = UDim2.fromOffset(6, 6)
	supremoBtn.BackgroundColor3 = Color3.fromRGB(115, 45, 215)
	supremoBtn.Text = "Config Supremo"
	supremoBtn.Font = Enum.Font.GothamBold
	supremoBtn.TextSize = 11
	supremoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	supremoBtn.Parent = sideBar
	Instance.new("UICorner", supremoBtn).CornerRadius = UDim.new(0, 6)

	local channels = {"Canal Aimbot", "Canal FOV", "Canal ESP", "Canal Textura"}
	local pages = {}

	for i, ch in ipairs(channels) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -12, 0, 28)
		b.Position = UDim2.fromOffset(6, 36 + i * 32)
		b.BackgroundColor3 = (i == 1) and Color3.fromRGB(95, 38, 175) or Color3.fromRGB(38, 22, 62)
		b.Text = ch
		b.Font = Enum.Font.GothamBold
		b.TextSize = 10
		b.TextColor3 = Color3.fromRGB(235, 215, 255)
		b.Parent = sideBar
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

		local p = Instance.new("Frame")
		p.Size = UDim2.fromScale(1, 1)
		p.BackgroundTransparency = 1
		p.Visible = (i == 1)
		p.Parent = content
		pages[ch] = p

		b.MouseButton1Click:Connect(function()
			for _, pg in pairs(pages) do pg.Visible = false end
			p.Visible = true
		end)
	end

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(1, -16, 0, 24)
	statusLbl.Position = UDim2.fromOffset(8, 182)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Font = Enum.Font.GothamBold
	statusLbl.TextSize = 10
	statusLbl.TextColor3 = Color3.fromRGB(215, 165, 255)
	statusLbl.Text = "Zero Delay: Pulo · Dash · Soco ativos"
	statusLbl.Parent = content

	local saveBtn = Instance.new("TextButton")
	saveBtn.Size = UDim2.new(1, -16, 0, 28)
	saveBtn.Position = UDim2.fromOffset(8, 150)
	saveBtn.BackgroundColor3 = Color3.fromRGB(125, 45, 215)
	saveBtn.Text = "Salvar perfil"
	saveBtn.Font = Enum.Font.GothamBold
	saveBtn.TextSize = 11
	saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	saveBtn.Parent = content
	Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 6)

	local function makeInfoLabel(parent, txt, y)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -16, 0, 28)
		l.Position = UDim2.fromOffset(8, y)
		l.BackgroundColor3 = Color3.fromRGB(34, 19, 58)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 10
		l.TextColor3 = Color3.fromRGB(245, 225, 255)
		l.Text = txt
		l.Parent = parent
		Instance.new("UICorner", l).CornerRadius = UDim.new(0, 6)
		return l
	end

	local aimLbl = makeInfoLabel(pages["Canal Aimbot"], "AIMBOT: ON | Alcance extra: 60 st | Ignorar time: OFF", 12)
	local fovLbl = makeInfoLabel(pages["Canal FOV"], "FOV: ATIVO (60) | Sem círculo na tela", 12)
	local espLbl = makeInfoLabel(pages["Canal ESP"], "ESP: ON | Cheia | Max: 500 m | Sem linhas/círculo", 12)
	local texLbl = makeInfoLabel(pages["Canal Textura"], "TEXTURA: ON | Rosa (Azul + Rosa / chão e blocos)", 12)

	-- Controles para mudar o FOV quanto quiser no Canal FOV
	local fovControls = Instance.new("Frame")
	fovControls.Size = UDim2.new(1, -16, 0, 34)
	fovControls.Position = UDim2.fromOffset(8, 48)
	fovControls.BackgroundTransparency = 1
	fovControls.Parent = pages["Canal FOV"]

	local minusFovBtn = Instance.new("TextButton")
	minusFovBtn.Size = UDim2.fromOffset(42, 30)
	minusFovBtn.Position = UDim2.fromOffset(0, 2)
	minusFovBtn.BackgroundColor3 = Color3.fromRGB(75, 32, 135)
	minusFovBtn.Text = "-5"
	minusFovBtn.Font = Enum.Font.GothamBold
	minusFovBtn.TextSize = 11
	minusFovBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	minusFovBtn.Parent = fovControls
	Instance.new("UICorner", minusFovBtn).CornerRadius = UDim.new(0, 6)

	local fovInput = Instance.new("TextBox")
	fovInput.Size = UDim2.fromOffset(82, 30)
	fovInput.Position = UDim2.fromOffset(48, 2)
	fovInput.BackgroundColor3 = Color3.fromRGB(34, 19, 58)
	fovInput.Text = tostring(config.fovValue)
	fovInput.PlaceholderText = "60"
	fovInput.ClearTextOnFocus = false
	fovInput.Font = Enum.Font.GothamBold
	fovInput.TextSize = 11
	fovInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	fovInput.Parent = fovControls
	Instance.new("UICorner", fovInput).CornerRadius = UDim.new(0, 6)

	local plusFovBtn = Instance.new("TextButton")
	plusFovBtn.Size = UDim2.fromOffset(42, 30)
	plusFovBtn.Position = UDim2.fromOffset(136, 2)
	plusFovBtn.BackgroundColor3 = Color3.fromRGB(115, 45, 215)
	plusFovBtn.Text = "+5"
	plusFovBtn.Font = Enum.Font.GothamBold
	plusFovBtn.TextSize = 11
	plusFovBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	plusFovBtn.Parent = fovControls
	Instance.new("UICorner", plusFovBtn).CornerRadius = UDim.new(0, 6)

	local function refreshLabels()
		aimLbl.Text = string.format("AIMBOT: %s | Alcance extra: %d st | Ignorar time: %s",
			config.aimAssistEnabled and "ON" or "OFF",
			config.punchAssistRange,
			config.ignoreTeam and "ON" or "OFF")
		fovLbl.Text = string.format("FOV: %s (%d) | Sem círculo na tela",
			config.fovEnabled and "ATIVO" or "OFF",
			config.fovValue)
		fovInput.Text = tostring(config.fovValue)
		espLbl.Text = string.format("ESP: %s | %s | Max: %d m | Sem linhas/círculo",
			config.espEnabled and "ON" or "OFF",
			config.espStyle,
			config.espMaxDistance)
		texLbl.Text = string.format("TEXTURA: %s | %s",
			config.mapVisualsEnabled and "ON" or "OFF",
			config.mapTheme)
	end

	minusFovBtn.MouseButton1Click:Connect(function()
		setFovValue(config.fovValue - 5)
		refreshLabels()
		statusLbl.Text = "FOV ajustado para " .. tostring(config.fovValue)
	end)

	plusFovBtn.MouseButton1Click:Connect(function()
		setFovValue(config.fovValue + 5)
		refreshLabels()
		statusLbl.Text = "FOV ajustado para " .. tostring(config.fovValue)
	end)

	fovInput.FocusLost:Connect(function()
		setFovValue(fovInput.Text)
		refreshLabels()
		statusLbl.Text = "FOV definido em " .. tostring(config.fovValue)
	end)

	supremoBtn.MouseButton1Click:Connect(function()
		applySupremoPreset()
		refreshLabels()
		statusLbl.Text = "Config Supremo aplicado e salvo!"
	end)

	saveBtn.MouseButton1Click:Connect(function()
		savedProfiles["Supremo"] = table.clone(config)
		statusLbl.Text = "Perfil Supremo salvo com sucesso!"
	end)

	minBtn.MouseButton1Click:Connect(function()
		main.Visible = false
		miniBtn.Visible = true
	end)

	miniBtn.MouseButton1Click:Connect(function()
		main.Visible = true
		miniBtn.Visible = false
	end)

	closeBtn.MouseButton1Click:Connect(function()
		config.hubActive = false
		for _, hl in pairs(espHighlights) do
			if hl then pcall(function() hl:Destroy() end) end
		end
		gui:Destroy()
	end)

	refreshLabels()
end

applySupremoPreset()
pcall(buildPanel)
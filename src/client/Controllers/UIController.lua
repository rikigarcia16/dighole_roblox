--!strict
-- HUD and screen-level UI: coins, depth/zone, backpack and energy bars, equipped tool,
-- objective hint, pickup feed, toasts, zone banners, note reader and the touch DIG button.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Fossils = require(ReplicatedStorage.Shared.Config.Fossils)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local UI = script.Parent.Parent.UI
local Build = require(UI.Build)
local Theme = require(UI.Theme)
local Story = require(ReplicatedStorage.Shared.Config.Story)
local ShopUI = require(UI.ShopUI)
local InventoryUI = require(UI.InventoryUI)
local MobilityUI = require(UI.MobilityUI)
local TutorialUI = require(UI.TutorialUI)
local Mobility = require(ReplicatedStorage.Shared.Config.Mobility)

local ClientState = require(script.Parent.ClientState)
local DigController = require(script.Parent.DigController)
local AmbienceController = require(script.Parent.AmbienceController)
local EffectsController = require(script.Parent.EffectsController)
local CounterController = require(script.Parent.CounterController)

local UIController = {}

local player = Players.LocalPlayer

local function pill(
	parent: Instance,
	name: string,
	position: UDim2,
	anchor: Vector2,
	size: UDim2,
	color: Color3
): (Frame, TextLabel)
	local frame = Build("Frame", {
		Name = name,
		AnchorPoint = anchor,
		Position = position,
		Size = size,
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.15,
		Parent = parent,
		[Build.Children] = { Build.corner(14), Build.stroke(Theme.stroke, 2, 0.2) },
	})
	local label = Build.label({
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		TextColor3 = color,
		MaxTextSize = 26,
		Parent = frame,
	})
	Build.textStroke().Parent = label
	return frame, label
end

local function bar(parent: Instance, name: string, order: number, color: Color3): (Frame, Frame, TextLabel)
	local frame = Build("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Parent = parent,
		[Build.Children] = { Build.corner(10), Build.stroke(Theme.stroke, 2, 0.2) },
	})
	local fill = Build("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		Parent = frame,
		[Build.Children] = { Build.corner(10) },
	})
	local label = Build.label({
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		ZIndex = 2,
		Parent = frame,
	})
	Build.textStroke().Parent = label
	return frame, fill, label
end

function UIController.start()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	local gui = Build("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = gui
	local function rescale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		uiScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720) * 1.15, 0.62, 1.15)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	-- Top bar -------------------------------------------------------------------------------------
	local _, coinsLabel =
		pill(gui, "Coins", UDim2.fromOffset(12, 10), Vector2.zero, UDim2.fromOffset(190, 46), Theme.coins)
	local _, depthLabel =
		pill(gui, "Depth", UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0), UDim2.fromOffset(300, 46), Theme.text)

	-- Left stack: bars + objective ---------------------------------------------------------------
	local left = Build("Frame", {
		Name = "Status",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 66),
		Size = UDim2.fromOffset(230, 200),
		Parent = gui,
		[Build.Children] = { Build.list(Enum.FillDirection.Vertical, 6) },
	})
	left:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Top
	local _, backpackFill, backpackLabel = bar(left, "Backpack", 1, Theme.backpack)
	local energyFrame, energyFill, energyLabel = bar(left, "Energy", 2, Theme.energy)
	-- Ordinary digging does not use energy; the bar returns with equipment that consumes it.
	energyFrame.Visible = false
	local toolFrame, toolLabel = pill(left, "Tool", UDim2.new(), Vector2.zero, UDim2.new(1, 0, 0, 30), Theme.text)
	toolFrame.LayoutOrder = 3
	local objective = Build("Frame", {
		Name = "Objective",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.25,
		LayoutOrder = 4,
		Parent = left,
		[Build.Children] = { Build.corner(10), Build.padding(8) },
	})
	local objectiveLabel = Build.label({
		Text = "",
		RichText = true,
		Font = Theme.bodyFont,
		TextScaled = false,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = objective,
	})

	-- Bottom-left buttons --------------------------------------------------------------------------
	local buttons = Build("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(560, 54),
		Parent = gui,
		[Build.Children] = { Build.list(Enum.FillDirection.Horizontal, 8) },
	})
	local backpackButton =
		Build.button("Mochila", Theme.backpack, { Size = UDim2.fromOffset(120, 50), LayoutOrder = 1, Parent = buttons })
	local surfaceButton = Build.button("↑ Superficie", Color3.fromRGB(70, 130, 200), {
		Size = UDim2.fromOffset(150, 50),
		LayoutOrder = 2,
		Visible = false,
		Parent = buttons,
	})

	-- Touch DIG button ----------------------------------------------------------------------------
	local digButton = Build("TextButton", {
		Name = "DigButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -150),
		Size = UDim2.fromOffset(104, 104),
		BackgroundColor3 = Theme.dig,
		Text = "CAVAR",
		Font = Theme.font,
		TextScaled = true,
		TextColor3 = Theme.text,
		Visible = UserInputService.TouchEnabled,
		Parent = gui,
		[Build.Children] = { Build.corner(52), Build.stroke(Theme.stroke, 3), Build.textStroke(), Build.padding(20) },
	})
	digButton.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			DigController.setHeld("touch", true)
			digButton.BackgroundColor3 = Theme.good:Lerp(Color3.new(1, 1, 1), 0.2)
		end
	end)
	digButton.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			DigController.setHeld("touch", false)
			digButton.BackgroundColor3 = Theme.dig
		end
	end)
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		if inputType == Enum.UserInputType.Touch then
			digButton.Visible = true
		elseif inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Keyboard then
			digButton.Visible = false
		end
	end)

	-- Pickup feed (right) -------------------------------------------------------------------------
	local feed = Build("Frame", {
		Name = "Feed",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.45, 0),
		Size = UDim2.fromOffset(220, 260),
		Parent = gui,
		[Build.Children] = { Build.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Right) },
	})
	feed:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Bottom
	local feedRows: { [string]: { frame: Frame, label: TextLabel, count: number, expires: number } } = {}
	local feedOrder = 0

	local function showPickup(resourceId: string, amount: number)
		local resource = Resources.get(resourceId)
		if not resource then
			return
		end
		local now = os.clock()
		local row = feedRows[resourceId]
		if row and row.frame.Parent then
			row.count += amount
			row.expires = now + 2.2
		else
			feedOrder += 1
			local frame = Build("Frame", {
				Size = UDim2.fromOffset(210, 34),
				BackgroundColor3 = Theme.panel,
				BackgroundTransparency = 0.2,
				LayoutOrder = feedOrder,
				Parent = feed,
				[Build.Children] = { Build.corner(10), Build.stroke(Resources.Rarities[resource.rarity].color, 2, 0.3) },
			})
			Build("Frame", {
				Size = UDim2.fromOffset(22, 22),
				Position = UDim2.fromOffset(6, 6),
				BackgroundColor3 = resource.color,
				Parent = frame,
				[Build.Children] = { Build.corner(6), Build.stroke(Theme.stroke, 1.5) },
			})
			local label = Build.label({
				Position = UDim2.fromOffset(36, 0),
				Size = UDim2.new(1, -42, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 18,
				Parent = frame,
			})
			Build.textStroke().Parent = label
			row = { frame = frame, label = label, count = amount, expires = now + 2.2 }
			feedRows[resourceId] = row
			-- keep the feed short
			local rows = {}
			for _, child in feed:GetChildren() do
				if child:IsA("Frame") then
					table.insert(rows, child)
				end
			end
			if #rows > 6 then
				table.sort(rows, function(a, b)
					return a.LayoutOrder < b.LayoutOrder
				end)
				rows[1]:Destroy()
			end
		end
		local r = assert(row)
		r.label.Text = string.format("+%d %s", r.count, resource.name)
		task.delay(2.3, function()
			if feedRows[resourceId] == r and os.clock() >= r.expires then
				feedRows[resourceId] = nil
				r.frame:Destroy()
			end
		end)
	end

	-- Toasts (top centre) --------------------------------------------------------------------------
	local toasts = Build("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(460, 200),
		Parent = gui,
		[Build.Children] = { Build.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center) },
	})
	toasts:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Top
	local toastColors = {
		error = Theme.danger,
		warning = Theme.backpack,
		success = Theme.good,
		sell = Theme.coins,
		discovery = Color3.fromRGB(150, 120, 255),
		info = Theme.energy,
		quest = Theme.accent,
		find = Color3.fromRGB(255, 150, 220),
	}
	local toastCount = 0
	local function toast(kind: string, text: string)
		toastCount += 1
		local frame = Build("Frame", {
			Size = UDim2.fromOffset(0, 36),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.panel,
			BackgroundTransparency = 0.1,
			LayoutOrder = toastCount,
			Parent = toasts,
			[Build.Children] = { Build.corner(12), Build.stroke(toastColors[kind] or Theme.text, 2), Build.padding(8) },
		})
		local label = Build.label({
			Text = text,
			TextScaled = false,
			TextSize = 17,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			TextColor3 = toastColors[kind] or Theme.text,
			Parent = frame,
		})
		Build.textStroke().Parent = label
		local children = {}
		for _, child in toasts:GetChildren() do
			if child:IsA("Frame") then
				table.insert(children, child)
			end
		end
		if #children > 3 then
			table.sort(children, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			children[1]:Destroy()
		end
		task.delay(3.2, function()
			if frame.Parent then
				TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
				TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				task.wait(0.3)
				frame:Destroy()
			end
		end)
		if kind == "error" then
			EffectsController.playUi("error")
		elseif kind == "sell" then
			EffectsController.playUi("sell")
		elseif kind == "quest" then
			EffectsController.playUi("purchase")
		end
	end

	-- Zone banner ----------------------------------------------------------------------------------
	local banner = Build("Frame", {
		Name = "ZoneBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(560, 110),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local bannerTitle = Build.label({ Size = UDim2.new(1, 0, 0, 62), MaxTextSize = 52, Parent = banner })
	Build.textStroke().Parent = bannerTitle
	local bannerSubtitle = Build.label({
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 0, 34),
		Font = Theme.bodyFont,
		MaxTextSize = 22,
		TextColor3 = Theme.textDim,
		Parent = banner,
	})
	Build.textStroke().Parent = bannerSubtitle
	local bannerToken = 0
	local function showBanner(zone: Zones.Zone, firstTime: boolean)
		bannerToken += 1
		local token = bannerToken
		bannerTitle.Text = string.format("ZONA %d · %s", zone.index, string.upper(zone.name))
		bannerTitle.TextColor3 = zone.accent
		bannerSubtitle.Text = if firstTime then (Story.ZoneIntro[zone.id] or zone.subtitle) else zone.subtitle
		banner.Visible = true
		for _, l in { bannerTitle, bannerSubtitle } do
			l.TextTransparency = 1
			TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
		end
		if firstTime then
			EffectsController.playUi("zone")
		end
		task.delay(if firstTime then 4 else 2.2, function()
			if token ~= bannerToken then
				return
			end
			for _, l in { bannerTitle, bannerSubtitle } do
				TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			end
			task.wait(0.6)
			if token == bannerToken then
				banner.Visible = false
			end
		end)
	end

	-- Note reader ----------------------------------------------------------------------------------
	local note = Build("Frame", {
		Name = "Note",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 430),
		BackgroundColor3 = Color3.fromRGB(245, 234, 204),
		Visible = false,
		ZIndex = 40,
		Parent = gui,
		[Build.Children] = { Build.corner(8), Build.stroke(Color3.fromRGB(120, 96, 60), 3), Build.padding(22) },
	})
	local noteTitle = Build.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 32),
		TextColor3 = Color3.fromRGB(70, 50, 30),
		MaxTextSize = 26,
		ZIndex = 41,
		Parent = note,
	})
	local noteBody = Build.label({
		Text = "",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -96),
		Font = Enum.Font.Merriweather,
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(60, 44, 28),
		ZIndex = 41,
		Parent = note,
	})
	local noteClose = Build.button("Cerrar", Color3.fromRGB(150, 110, 70), {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(150, 44),
		ZIndex = 41,
		Parent = note,
	})
	noteClose.Activated:Connect(function()
		note.Visible = false
	end)
	local function openText(title: string, body: string)
		noteTitle.Text = title
		noteBody.Text = body
		note.Visible = true
		EffectsController.playUi("ui_click")
	end
	local function openNote(noteId: string)
		local data = Story.Notes[noteId]
		if data then
			openText(data.title, data.body)
		end
	end
	Remotes.event("ShowNote").OnClientEvent:Connect(openNote)

	-- Panels -----------------------------------------------------------------------------------------
	local function getState()
		return ClientState.data
	end
	local shop = ShopUI.new(gui, { getState = getState, notify = toast, playUi = EffectsController.playUi })
	local inventory = InventoryUI.new(
		gui,
		{ getState = getState, playUi = EffectsController.playUi, openNote = openNote, openText = openText }
	)
	local mobility = MobilityUI.new(gui, buttons, {
		getState = getState,
		notify = toast,
		playUi = EffectsController.playUi,
		-- an open note must not stay behind the lift menu (Studio test 1)
		closeOverlays = function()
			note.Visible = false
			shop.close()
			inventory.close()
		end,
	})

	-- Settings: effects quality and camera punch (session only; see docs/GAMEPLAY_AUDIT.md) -------------
	local settingsButton = Build.button("⚙", Theme.card, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(46, 46),
		Parent = gui,
	})
	local settings = Build("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 64),
		Size = UDim2.fromOffset(260, 150),
		BackgroundColor3 = Theme.panel,
		Visible = false,
		ZIndex = 45,
		Parent = gui,
		[Build.Children] = { Build.corner(12), Build.stroke(Theme.stroke, 2), Build.padding(10) },
	})
	Build.label({
		Text = "Efectos visuales",
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		ZIndex = 46,
		Parent = settings,
	})
	local qualities = { { "Auto", nil }, { "Bajo", 0.3 }, { "Medio", 0.65 }, { "Alto", 1 } } :: { { any } }
	local qualityButtons: { TextButton } = {}
	local currentQuality = 1
	local shakeOn = true
	local function paintQuality()
		for i, b in qualityButtons do
			b.BackgroundColor3 = if i == currentQuality then Theme.accent else Theme.card
		end
	end
	local function saveSettings()
		Remotes.event("SaveSettings"):FireServer({ effects = currentQuality - 1, shake = shakeOn })
	end
	for i, q in qualities do
		local b = Build.button(q[1], Theme.card, {
			Position = UDim2.new((i - 1) / 4, 2, 0, 28),
			Size = UDim2.new(0.25, -4, 0, 36),
			ZIndex = 46,
			Parent = settings,
		})
		b.Activated:Connect(function()
			currentQuality = i
			AmbienceController.setEffectsScale(q[2])
			EffectsController.playUi("ui_click")
			paintQuality()
			saveSettings()
		end)
		qualityButtons[i] = b
	end
	paintQuality()
	local shakeButton = Build.button("Sacudida al golpear: Sí", Theme.card, {
		Position = UDim2.new(0, 0, 0, 80),
		Size = UDim2.new(1, 0, 0, 36),
		ZIndex = 46,
		Parent = settings,
	})
	shakeButton.Activated:Connect(function()
		shakeOn = not shakeOn
		EffectsController.setCameraShake(shakeOn)
		shakeButton.Text = "Sacudida al golpear: " .. (if shakeOn then "Sí" else "No")
		EffectsController.playUi("ui_click")
		saveSettings()
	end)
	-- saved preferences arrive with the first state
	local settingsApplied = false
	local function applySavedSettings(state: any)
		if settingsApplied or not state or not state.settings then
			return
		end
		settingsApplied = true
		local saved = state.settings
		currentQuality = math.clamp((saved.effects or 0) + 1, 1, #qualities)
		AmbienceController.setEffectsScale(qualities[currentQuality][2])
		paintQuality()
		shakeOn = saved.shake ~= false
		EffectsController.setCameraShake(shakeOn)
		shakeButton.Text = "Sacudida al golpear: " .. (if shakeOn then "Sí" else "No")
	end
	local tutorial = TutorialUI.new(gui)
	settingsButton.Activated:Connect(function()
		settings.Visible = not settings.Visible
		EffectsController.playUi("ui_click")
	end)

	backpackButton.Activated:Connect(function()
		EffectsController.playUi("ui_click")
		shop.close()
		inventory.toggle()
	end)
	surfaceButton.Activated:Connect(function()
		EffectsController.playUi("ui_click")
		Remotes.event("ReturnToSurface"):FireServer()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.ButtonY then
			shop.close()
			inventory.toggle()
		elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.DPadUp then
			if surfaceButton.Visible then
				Remotes.event("ReturnToSurface"):FireServer()
			elseif not mobility.freeReturn() then
				mobility.openBeacon()
			end
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local action = prompt:GetAttribute("Action")
		if action == "Shop" then
			inventory.close()
			shop.open()
		end
	end)

	-- Close the shop automatically when walking away from it.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if shop.isOpen() then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local near = false
				if root then
					local world = workspace:FindFirstChild("World")
					if world then
						for _, plotFolder in world:GetChildren() do
							local counter = plotFolder:FindFirstChild("ShopCounter") :: BasePart?
							if
								counter
								and (counter.Position - root.Position).Magnitude <= GameConfig.ShopDistance + 6
							then
								near = true
								break
							end
						end
					end
				end
				if not near then
					shop.close()
				end
			end
		end
	end)

	-- State bindings ---------------------------------------------------------------------------------
	local displayedCoins = 0
	local coinTween: Tween? = nil
	local coinValue = Instance.new("NumberValue")
	coinValue.Changed:Connect(function(value)
		coinsLabel.Text = "● " .. Format.number(value)
	end)

	local hasDug = false
	local hasSold = false
	local function updateObjective()
		local state = ClientState.data
		if not state then
			objectiveLabel.Text = "Cargando tu parcela..."
			return
		end
		local text
		local quest = state.quest
		if state.used >= state.capacity then
			text = "<b>Mochila llena:</b> vuelve a la superficie y vende en el carro verde."
		elseif quest then
			text = string.format(
				'<font color="#FFC440"><b>Misión %d/%d</b></font>  %s\n<b>%s / %s</b>  ·  <font color="#AAB0C4">%s</font>',
				quest.index,
				quest.total,
				quest.title,
				Format.number(quest.progress),
				Format.number(quest.target),
				if quest.id == "dig_10"
					then (if UserInputService.TouchEnabled
						then "Mantén pulsado CAVAR."
						else "Mantén clic izquierdo (o E) sobre el suelo.")
					else quest.hint
			)
			if quest.reward > 0 then
				text ..= string.format('\n<font color="#FFCD3C">Recompensa: ● %s</font>', Format.number(quest.reward))
			end
		elseif not hasDug and (state.maxDepth or 0) == 0 then
			text = if UserInputService.TouchEnabled
				then "<b>Objetivo:</b> mantén pulsado CAVAR para excavar tu terreno."
				else "<b>Objetivo:</b> mantén pulsado el clic izquierdo (o E) sobre el suelo para cavar."
		elseif not state.tools.reinforced_shovel and state.coins >= 100 then
			text = "<b>Objetivo:</b> compra la Pala reforzada en el garaje."
		elseif not hasSold and (state.discoveries.dirt or 0) > 0 and state.coins < 100 then
			text = "<b>Objetivo:</b> llena la mochila y véndela en la estación de venta."
		elseif (state.maxDepth or 0) < 50 then
			text = string.format("<b>Objetivo:</b> alcanza los 50 m (récord: %d m).", state.maxDepth or 0)
		else
			text = "<b>Objetivo:</b> sigue bajando. ¿Qué habrá más abajo?"
		end
		objectiveLabel.Text = text
	end

	local function onState(state: any)
		if not state then
			return
		end
		if coinTween then
			coinTween:Cancel()
		end
		if math.abs(state.coins - displayedCoins) > 0 then
			coinTween =
				TweenService:Create(coinValue, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Value = state.coins });
			(coinTween :: Tween):Play()
			displayedCoins = state.coins
		else
			coinsLabel.Text = "● " .. Format.number(state.coins)
		end
		local fraction = math.clamp(state.used / math.max(state.capacity, 1), 0, 1)
		TweenService:Create(backpackFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(fraction, 1) }):Play()
		backpackFill.BackgroundColor3 = if fraction >= 1 then Theme.danger else Theme.backpack
		backpackLabel.Text = string.format("Mochila  %d/%d", state.used, state.capacity)
		local tool = Tools.get(state.equippedTool)
		toolLabel.Text = if tool then string.format("%s · P%d", tool.name, tool.power) else ""
		if state.coins > 0 and (state.discoveries.dirt or 0) > 0 and state.used == 0 then
			hasSold = true
		end
		updateObjective()
		shop.refresh()
		inventory.refresh()
		mobility.refresh()
		applySavedSettings(state)
		tutorial.update(state)
	end
	coinsLabel.Text = "● 0"
	ClientState.changed:Connect(onState)
	if ClientState.data then
		onState(ClientState.data)
	end
	updateObjective()

	local function updateEnergy()
		local energy, max = ClientState.energy()
		local fraction = math.clamp(energy / math.max(max, 1), 0, 1)
		energyFill.Size = UDim2.fromScale(fraction, 1)
		energyFill.BackgroundColor3 = if fraction < 0.15 then Theme.danger else Theme.energy
		energyLabel.Text = string.format("Energía  %d/%d", math.floor(energy), max)
	end
	player:GetAttributeChangedSignal("Energy"):Connect(updateEnergy)
	player:GetAttributeChangedSignal("MaxEnergy"):Connect(updateEnergy)
	updateEnergy()

	AmbienceController.depthChanged:Connect(function(depth: number, zone: Zones.Zone)
		depthLabel.Text = string.format("↓ %s · %s", Format.depth(depth), zone.name)
		depthLabel.TextColor3 = if depth > 3 then zone.accent:Lerp(Color3.new(1, 1, 1), 0.4) else Theme.text
		surfaceButton.Visible = depth >= GameConfig.ReturnButtonMinDepth and depth <= Mobility.FreeReturnDepth
		mobility.setDepth(depth)
	end)
	AmbienceController.zoneChanged:Connect(function(zone: Zones.Zone)
		showBanner(zone, false)
	end)
	Remotes.event("ZoneEntered").OnClientEvent:Connect(function(zoneId: string, firstTime: boolean)
		for _, zone in Zones.List do
			if zone.id == zoneId then
				showBanner(zone, firstTime)
				toast("discovery", "¡Nueva zona descubierta: " .. zone.name .. "!")
			end
		end
	end)

	Remotes.event("Collected").OnClientEvent:Connect(function(resourceId: string, amount: number, isNew: boolean)
		showPickup(resourceId, amount)
		local resource = Resources.get(resourceId)
		if resource and (isNew or Resources.isRareOrBetter(resource)) then
			EffectsController.playUi(resource.sound)
		else
			EffectsController.playUi("pickup")
		end
	end)
	Remotes.event("Notify").OnClientEvent:Connect(toast)

	-- Epic / legendary discoveries: a short line under the zone banner; legendary also glows at the
	-- screen edges for a moment. Rare finds stay in the world (glint + chime) to avoid UI spam.
	local rareBanner = Build.label({
		Name = "RareBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(520, 44),
		MaxTextSize = 34,
		TextTransparency = 1,
		Parent = gui,
	})
	local rareStroke = Build.textStroke()
	rareStroke.Parent = rareBanner
	local edgeGlow = Build("Frame", {
		Name = "EdgeGlow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 0,
		Parent = gui,
	})
	local edgeStroke = Instance.new("UIStroke")
	edgeStroke.Thickness = 18
	edgeStroke.Transparency = 1
	edgeStroke.Parent = edgeGlow
	local rareToken = 0
	EffectsController.bigDiscovery:Connect(function(resource)
		rareToken += 1
		local token = rareToken
		local rarity = Resources.Rarities[resource.rarity]
		rareBanner.Text = string.format("¡%s! %s", string.upper(rarity.name), resource.name)
		rareBanner.TextColor3 = rarity.color
		rareBanner.TextTransparency = 0
		if rarity.order >= 5 then
			edgeStroke.Color = resource.color
			edgeStroke.Transparency = 0.35
			TweenService:Create(edgeStroke, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
		end
		task.delay(2.2, function()
			if token == rareToken then
				TweenService:Create(rareBanner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			end
		end)
	end)

	-- Fossil card: shown after an extraction. It is the moment of curiosity, so it stays until the
	-- player closes it (or 8 s), and it never blocks digging.
	local card = Build("Frame", {
		Name = "FossilCard",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -170),
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(46, 42, 36),
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
		[Build.Children] = {
			Build.corner(12),
			Build.stroke(Color3.fromRGB(226, 214, 184), 2),
			Build.padding(12),
			Build.list(Enum.FillDirection.Vertical, 4),
		},
	})
	local cardTitle = Build.label({ Size = UDim2.new(1, 0, 0, 26), MaxTextSize = 22, LayoutOrder = 1, Parent = card })
	Build.textStroke().Parent = cardTitle
	local cardMeta = Build.label({
		Size = UDim2.new(1, 0, 0, 18),
		Font = Theme.bodyFont,
		MaxTextSize = 14,
		TextColor3 = Theme.textDim,
		LayoutOrder = 2,
		RichText = true,
		Parent = card,
	})
	local cardLore = Build.label({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Merriweather,
		TextScaled = false,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(240, 232, 210),
		LayoutOrder = 3,
		Parent = card,
	})
	local cardToken = 0
	Remotes.event("FossilFound").OnClientEvent:Connect(function(speciesId: string, isNew: boolean, depth: number)
		local species = Fossils.get(speciesId)
		if not species then
			return
		end
		cardToken += 1
		local token = cardToken
		local rarity = Resources.Rarities[species.rarity]
		cardTitle.Text = species.name
		cardTitle.TextColor3 = rarity.color
		cardMeta.Text = string.format(
			"%s · %d m · %s",
			rarity.name,
			math.floor(depth),
			if isNew then "<b>nuevo en tu colección</b>" else "ya registrado"
		)
		cardLore.Text = species.lore
		card.Visible = true
		task.delay(8, function()
			if token == cardToken then
				card.Visible = false
			end
		end)
	end)

	-- Narrative lines (the Counter): calm, centred, no rarity colour.
	local function showNarrative(text: string)
		rareToken += 1
		local token = rareToken
		rareBanner.Text = text
		rareBanner.TextColor3 = Color3.fromRGB(200, 232, 255)
		rareBanner.TextTransparency = 1
		TweenService:Create(rareBanner, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
		task.delay(4, function()
			if token == rareToken then
				TweenService:Create(rareBanner, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
			end
		end)
	end
	EffectsController.narrative:Connect(showNarrative)
	CounterController.narrative:Connect(showNarrative)

	DigController.dug:Connect(function()
		if not hasDug then
			hasDug = true
			updateObjective()
		end
	end)
end

return UIController

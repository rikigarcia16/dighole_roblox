--!strict
-- Mobility HUD: rope button, rescue beacon (quote dialog + channel bar), lift menu, station install
-- hint and the fade used while the lift or the beacon moves the player. The server validates
-- everything; this module only shows prices and sends requests.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Mobility = require(ReplicatedStorage.Shared.Config.Mobility)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local MobilityRules = require(ReplicatedStorage.Shared.Util.MobilityRules)
local Build = require(script.Parent.Build)
local Theme = require(script.Parent.Theme)

local MobilityUI = {}

local player = Players.LocalPlayer
local BEACON_COLOR = Color3.fromRGB(230, 90, 60)

type Deps = {
	getState: () -> any,
	notify: (kind: string, text: string) -> (),
	playUi: (key: string) -> (),
}

local function dialog(parent: Instance, height: number): (Frame, TextLabel, TextLabel)
	local frame = Build("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, height),
		BackgroundColor3 = Theme.panel,
		Visible = false,
		ZIndex = 40,
		Parent = parent,
		[Build.Children] = { Build.corner(14), Build.stroke(Theme.stroke, 3) },
	})
	local title = Build.label({
		Text = "",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 30),
		ZIndex = 41,
		MaxTextSize = 24,
		Parent = frame,
	})
	local body = Build.label({
		Text = "",
		Font = Theme.bodyFont,
		RichText = true,
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(16, 46),
		Size = UDim2.new(1, -32, 1, -112),
		ZIndex = 41,
		Parent = frame,
	})
	return frame, title, body
end

-- The reset button would be a free trip out of any depth: turn it off (SetCore may not be ready yet).
local function disableReset()
	task.spawn(function()
		for _ = 1, 20 do
			local ok = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)
			if ok then
				return
			end
			task.wait(0.5)
		end
	end)
end

function MobilityUI.new(gui: ScreenGui, buttons: Frame, deps: Deps)
	disableReset()
	local depth = 0

	-- Buttons next to "Mochila" ------------------------------------------------------------------------
	local ropeButton = Build.button("Cuerda", Color3.fromRGB(150, 116, 74), {
		Size = UDim2.fromOffset(120, 50),
		LayoutOrder = 3,
		Visible = false,
		Parent = buttons,
	})
	local beaconButton = Build.button("Baliza", BEACON_COLOR, {
		Size = UDim2.fromOffset(120, 50),
		LayoutOrder = 4,
		Visible = false,
		Parent = buttons,
	})
	local installButton = Build.button("", Color3.fromRGB(70, 130, 200), {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -72),
		Size = UDim2.fromOffset(330, 40),
		Visible = false,
		Parent = gui,
	})

	-- Fade --------------------------------------------------------------------------------------------
	local fade = Build("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, -60),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 60,
		Parent = gui,
	})
	fade.Size = UDim2.new(1, 0, 1, 120)
	local function playFade(seconds: number)
		fade.Visible = true
		fade.BackgroundTransparency = 1
		local half = math.max(0.2, seconds * 0.45)
		TweenService:Create(fade, TweenInfo.new(half), { BackgroundTransparency = 0 }):Play()
		task.delay(seconds - half, function()
			local out = TweenService:Create(fade, TweenInfo.new(half), { BackgroundTransparency = 1 })
			out.Completed:Connect(function()
				fade.Visible = false
			end)
			out:Play()
		end)
	end
	Remotes.event("LiftRide").OnClientEvent:Connect(function(seconds: number)
		if type(seconds) == "number" and seconds > 0 and seconds < 10 then
			deps.playUi("ui_click")
			playFade(seconds)
		end
	end)

	-- Beacon: quote dialog ------------------------------------------------------------------------------
	local beaconDialog, beaconTitle, beaconBody = dialog(gui, 260)
	beaconTitle.Text = "Baliza de rescate"
	beaconTitle.TextColor3 = BEACON_COLOR
	local beaconYes = Build.button("Activar", BEACON_COLOR, {
		Position = UDim2.new(0.5, 6, 1, -58),
		Size = UDim2.new(0.5, -22, 0, 44),
		ZIndex = 41,
		Parent = beaconDialog,
	})
	local beaconNo = Build.button("Cancelar", Theme.card, {
		Position = UDim2.new(0, 16, 1, -58),
		Size = UDim2.new(0.5, -22, 0, 44),
		ZIndex = 41,
		Parent = beaconDialog,
	})

	local function openBeacon()
		local ok, quote = pcall(function()
			return Remotes.func("RescueQuote"):InvokeServer()
		end)
		if not ok or type(quote) ~= "table" then
			deps.notify("error", "La baliza no responde. Inténtalo otra vez.")
			return
		end
		local price
		if quote.free then
			price = "Gratis a esta profundidad."
		elseif quote.waived > 0 then
			price = string.format(
				'Coste: <b>%s</b> monedas. Solo tienes %s: pagas <font color="#FFCD3C"><b>%s</b></font> y el resto se perdona.',
				Format.number(quote.cost),
				Format.number(quote.pay),
				Format.number(quote.pay)
			)
		else
			price = string.format('Coste: <font color="#FFCD3C"><b>%s</b></font> monedas.', Format.number(quote.cost))
		end
		beaconBody.Text = string.format(
			"Te subirá hasta <b>%s</b>.\n%s\nConservas la mochila, tus hallazgos y tu progreso.\n"
				.. '<font color="#AAB0C4">Quédate quieto %d s: moverte o cavar la cancela.</font>',
			quote.destinationName,
			price,
			Mobility.Rescue.channelSeconds
		)
		beaconDialog.Visible = true
	end

	-- Beacon: channel bar -------------------------------------------------------------------------------
	local channel = Build("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromOffset(320, 64),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 35,
		Parent = gui,
		[Build.Children] = { Build.corner(12), Build.stroke(Theme.stroke, 2) },
	})
	Build.label({
		Text = "Baliza activa · no te muevas",
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -110, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 36,
		MaxTextSize = 18,
		Parent = channel,
	})
	local channelTrack = Build("Frame", {
		Position = UDim2.fromOffset(10, 38),
		Size = UDim2.new(1, -110, 0, 14),
		BackgroundColor3 = Theme.card,
		ZIndex = 36,
		Parent = channel,
		[Build.Children] = { Build.corner(7) },
	})
	local channelFill = Build("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = BEACON_COLOR,
		ZIndex = 37,
		Parent = channelTrack,
		[Build.Children] = { Build.corner(7) },
	})
	local channelCancel = Build.button("Cancelar", Theme.card, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(90, 44),
		ZIndex = 36,
		Parent = channel,
	})
	local channelTween: Tween? = nil
	local function hideChannel()
		channel.Visible = false
		if channelTween then
			channelTween:Cancel()
			channelTween = nil
		end
	end

	beaconYes.Activated:Connect(function()
		beaconDialog.Visible = false
		deps.playUi("ui_click")
		Remotes.event("RescueStart"):FireServer()
	end)
	beaconNo.Activated:Connect(function()
		beaconDialog.Visible = false
	end)
	channelCancel.Activated:Connect(function()
		Remotes.event("RescueCancel"):FireServer()
	end)
	Remotes.event("RescueState").OnClientEvent:Connect(function(state: string, info: any)
		if state == "channel" and type(info) == "number" then
			channel.Visible = true
			channelFill.Size = UDim2.fromScale(0, 1)
			channelTween = TweenService:Create(channelFill, TweenInfo.new(info, Enum.EasingStyle.Linear), {
				Size = UDim2.fromScale(1, 1),
			});
			(channelTween :: Tween):Play()
		elseif state == "cancelled" then
			hideChannel()
			if type(info) == "string" and info ~= "" then
				deps.notify("info", info)
			end
		elseif state == "done" then
			hideChannel()
		end
	end)

	-- Lift menu -------------------------------------------------------------------------------------------
	local liftDialog, liftTitle, liftBody = dialog(gui, 320)
	liftTitle.Text = "Montacargas"
	liftTitle.TextColor3 = Theme.accent
	liftBody.Text = ""
	local liftList = Build("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -32, 1, -116),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 41,
		Parent = liftDialog,
		[Build.Children] = { Build.list(Enum.FillDirection.Vertical, 6) },
	})
	local liftClose = Build.button("Cerrar", Theme.card, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0.5, 0, 0, 44),
		ZIndex = 41,
		Parent = liftDialog,
	})
	liftClose.Activated:Connect(function()
		liftDialog.Visible = false
	end)

	local function travel(destination: string)
		liftDialog.Visible = false
		local ok, result = pcall(function()
			return Remotes.func("LiftTravel"):InvokeServer(destination)
		end)
		if not ok or type(result) ~= "table" then
			deps.notify("error", "El montacargas no responde.")
		elseif not result.ok then
			deps.notify("error", result.message)
		end
	end

	local function openLift()
		local state = deps.getState()
		for _, child in liftList:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local stations: { MobilityRules.Station } =
			table.clone(if state and state.mobility then state.mobility.stations else {})
		table.sort(stations, function(a: MobilityRules.Station, b: MobilityRules.Station)
			return a.d < b.d
		end)
		local entries = { { id = "surface", text = "Superficie" } }
		for _, station in stations do
			local def = Mobility.StationById[station.id]
			table.insert(entries, {
				id = station.id,
				text = string.format("%s · %d m", if def then def.name else station.id, station.d),
			})
		end
		for i, entry in entries do
			local button = Build.button(entry.text, Color3.fromRGB(70, 130, 200), {
				Size = UDim2.new(1, -8, 0, 42),
				LayoutOrder = i,
				ZIndex = 42,
				Parent = liftList,
			})
			button.Activated:Connect(function()
				deps.playUi("ui_click")
				travel(entry.id)
			end)
		end
		if #stations == 0 then
			Build.button("Instala estaciones al llegar a cada zona", Theme.panelLight, {
				Size = UDim2.new(1, -8, 0, 36),
				LayoutOrder = 99,
				AutoButtonColor = false,
				ZIndex = 42,
				Parent = liftList,
			})
		end
		liftDialog.Visible = true
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt:GetAttribute("Action") == "Lift" then
			openLift()
		end
	end)

	-- Requests -----------------------------------------------------------------------------------------
	local function placeRope()
		deps.playUi("ui_click")
		Remotes.event("PlaceRope"):FireServer()
	end
	ropeButton.Activated:Connect(placeRope)
	beaconButton.Activated:Connect(function()
		deps.playUi("ui_click")
		openBeacon()
	end)
	installButton.Activated:Connect(function()
		deps.playUi("ui_click")
		Remotes.event("InstallStation"):FireServer()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL1 then
			if ropeButton.Visible then
				placeRope()
			end
		elseif input.KeyCode == Enum.KeyCode.H then
			if installButton.Visible then
				Remotes.event("InstallStation"):FireServer()
			end
		end
	end)

	-- State ----------------------------------------------------------------------------------------------
	local function refresh()
		local state = deps.getState()
		local mobility = state and state.mobility
		if not mobility then
			return
		end
		ropeButton.Text = "Cuerda ×" .. mobility.ropes
		ropeButton.Visible = mobility.ropes > 0 and depth > 1
		beaconButton.Visible = depth > Mobility.FreeReturnDepth
		local def = MobilityRules.installable(depth, mobility.stations)
		installButton.Visible = def ~= nil
		if def then
			local affordable = state.coins >= def.cost
			installButton.Text = string.format("[H] Instalar %s · ● %s", def.name, Format.number(def.cost))
			installButton.BackgroundColor3 = if affordable then Color3.fromRGB(70, 130, 200) else Theme.card
		end
	end

	local api = {}
	function api.setDepth(meters: number)
		depth = meters
		refresh()
	end
	api.refresh = refresh
	-- The old "Superficie" button only covers the first metres; deeper down the beacon takes over.
	function api.freeReturn(): boolean
		return depth <= Mobility.FreeReturnDepth
	end
	api.openBeacon = openBeacon
	return api
end

return MobilityUI

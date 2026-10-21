--!strict
-- Garage shop: tools, upgrades and expedition gear with previews, stats comparison and purchase confirmation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Mobility = require(ReplicatedStorage.Shared.Config.Mobility)
local Gear = require(ReplicatedStorage.Shared.Config.Gear)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local ToolModels = require(ReplicatedStorage.Shared.Util.ToolModels)
local Build = require(script.Parent.Build)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)

local ShopUI = {}

local CONFIRM_THRESHOLD = 1000

type Deps = {
	getState: () -> any,
	notify: (kind: string, text: string) -> (),
	playUi: (key: string) -> (),
}

local function statLine(parent: Instance, order: number, name: string, value: string, diff: number?)
	local diffText = ""
	if diff and math.abs(diff) > 1e-6 then
		local better = diff > 0
		diffText = string.format(
			' <font color="#%s">(%s%s)</font>',
			if better then "6EDC6E" else "F05050",
			if better then "+" else "",
			Format.number(diff)
		)
	end
	Build.label({
		Text = name .. ": <b>" .. value .. "</b>" .. diffText,
		RichText = true,
		Font = Theme.bodyFont,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18),
		MaxTextSize = 15,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function preview(parent: Instance, toolId: string): (ViewportFrame, Model)
	local viewport = Build("ViewportFrame", {
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = Theme.panelLight,
		LayoutOrder = 0,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -0.5),
		Parent = parent,
		[Build.Children] = { Build.corner(10) },
	})
	local model = ToolModels.buildModel(toolId)
	model:PivotTo(CFrame.Angles(0, math.rad(90), math.rad(-35)))
	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 0, size.Magnitude * 1.7), cf.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport, model
end

function ShopUI.new(parent: Instance, deps: Deps)
	local modal = Modal.new(parent, "Garaje", Color3.fromRGB(70, 130, 200))
	local shopRemote = Remotes.func("Shop")

	local coinsLabel = Build.label({
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.coins,
		Parent = modal.headerExtra,
	})
	Build.textStroke().Parent = coinsLabel

	local scroll = Build("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = modal.body,
	})
	local grid = Build("UIGridLayout", {
		CellSize = UDim2.fromOffset(186, 268),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = scroll,
	})
	Build.padding(4).Parent = scroll

	-- Confirmation dialog --------------------------------------------------------------------------
	local confirm = Build("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 170),
		BackgroundColor3 = Theme.panelLight,
		Visible = false,
		ZIndex = 30,
		Parent = modal.root,
		[Build.Children] = { Build.corner(14), Build.stroke(Theme.stroke, 3) },
	})
	local confirmText = Build.label({
		Text = "",
		Font = Theme.bodyFont,
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 80),
		RichText = true,
		ZIndex = 31,
		MaxTextSize = 20,
		Parent = confirm,
	})
	local confirmYes = Build.button("Comprar", Theme.good, {
		Position = UDim2.new(0.5, 6, 1, -58),
		Size = UDim2.new(0.5, -22, 0, 44),
		ZIndex = 31,
		Parent = confirm,
	})
	local confirmNo = Build.button("Cancelar", Theme.card, {
		Position = UDim2.new(0, 16, 1, -58),
		Size = UDim2.new(0.5, -22, 0, 44),
		ZIndex = 31,
		Parent = confirm,
	})
	local pendingAction: (() -> ())? = nil
	confirmYes.Activated:Connect(function()
		confirm.Visible = false
		local action = pendingAction
		pendingAction = nil
		if action then
			action()
		end
	end)
	confirmNo.Activated:Connect(function()
		confirm.Visible = false
		pendingAction = nil
	end)

	local function request(action: string, id: string)
		local ok, result = pcall(function()
			return shopRemote:InvokeServer(action, id)
		end)
		if not ok or type(result) ~= "table" then
			deps.notify("error", "No se pudo completar la compra. Inténtalo de nuevo.")
			deps.playUi("error")
			return
		end
		deps.notify(if result.ok then "success" else "error", result.message)
		deps.playUi(if result.ok then "purchase" else "error")
	end

	local function purchase(action: string, id: string, name: string, price: number)
		if price >= CONFIRM_THRESHOLD then
			confirmText.Text = string.format(
				'¿Comprar <b>%s</b> por <font color="#FFCD3C">%s</font> monedas?',
				name,
				Format.number(price)
			)
			pendingAction = function()
				request(action, id)
			end
			confirm.Visible = true
		else
			request(action, id)
		end
	end

	local currentTab = "tools"
	local spinning: { Model } = {}

	local function card(order: number): Frame
		return Build("Frame", {
			BackgroundColor3 = Theme.card,
			LayoutOrder = order,
			Parent = scroll,
			[Build.Children] = {
				Build.corner(12),
				Build.stroke(Theme.stroke, 2),
				Build.padding(8),
				Build.list(Enum.FillDirection.Vertical, 3, Enum.HorizontalAlignment.Center),
			},
		})
	end

	local function render()
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		table.clear(spinning)
		local state = deps.getState()
		if not state then
			return
		end
		coinsLabel.Text = "● " .. Format.number(state.coins)
		local equipped = Tools.get(state.equippedTool) or Tools.get(Tools.DefaultToolId)
		assert(equipped)

		if currentTab == "tools" then
			grid.CellSize = UDim2.fromOffset(186, 268)
			for _, tool in Tools.List do
				local owned = state.tools[tool.id] == true
				if tool.purchasable or owned then
					local c = card(tool.order)
					local _, model = preview(c, tool.id)
					table.insert(spinning, model)
					Build.label({
						Text = tool.name,
						Size = UDim2.new(1, 0, 0, 24),
						LayoutOrder = 1,
						MaxTextSize = 20,
						Parent = c,
					})
					local stats = Build("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 78),
						LayoutOrder = 2,
						Parent = c,
						[Build.Children] = { Build.list(Enum.FillDirection.Vertical, 1) },
					})
					local area = #Grid.sphereOffsets(tool.radius)
					local equippedArea = #Grid.sphereOffsets(equipped.radius)
					statLine(stats, 1, "Potencia", tostring(tool.power), tool.power - equipped.power)
					statLine(stats, 2, "Área", area .. " bloques", area - equippedArea)
					statLine(
						stats,
						3,
						"Golpes/s",
						string.format("%.1f", 1 / tool.cooldown),
						math.floor((1 / tool.cooldown - 1 / equipped.cooldown) * 10 + 0.5) / 10
					)

					local button
					if state.equippedTool == tool.id then
						button = Build.button("Equipado", Theme.panelLight, { AutoButtonColor = false })
					elseif owned then
						button = Build.button("Equipar", Color3.fromRGB(70, 130, 200))
						button.Activated:Connect(function()
							deps.playUi("ui_click")
							request("equipTool", tool.id)
						end)
					else
						local affordable = state.coins >= tool.price
						button = Build.button(
							"● " .. Format.number(tool.price),
							if affordable then Theme.good else Theme.card
						)
						button.TextColor3 = if affordable then Theme.text else Theme.coins
						button.Activated:Connect(function()
							deps.playUi("ui_click")
							purchase("buyTool", tool.id, tool.name, tool.price)
						end)
					end
					button.Size = UDim2.new(1, 0, 0, 40)
					button.LayoutOrder = 3
					button.Parent = c
				end
			end
		elseif currentTab == "gear" then
			grid.CellSize = UDim2.fromOffset(250, 200)
			local rope = Mobility.Rope
			local carried = if state.mobility then state.mobility.ropes else 0
			local c = card(1)
			Build.label({
				Text = "Cuerda",
				Size = UDim2.new(1, 0, 0, 26),
				LayoutOrder = 1,
				MaxTextSize = 22,
				Parent = c,
			})
			Build.label({
				Text = string.format(
					"Cuélgala sobre un hueco abierto (máx. %d m) para bajar y volver a subir. Se recoge desde arriba (F).",
					math.floor(rope.maxLength / 4)
				),
				Font = Theme.bodyFont,
				TextColor3 = Theme.textDim,
				Size = UDim2.new(1, 0, 0, 46),
				LayoutOrder = 2,
				MaxTextSize = 14,
				TextWrapped = true,
				Parent = c,
			})
			Build.label({
				Text = string.format("Llevas <b>%d/%d</b> · tecla <b>Q</b> para colgarla", carried, rope.maxCarried),
				RichText = true,
				Font = Theme.bodyFont,
				Size = UDim2.new(1, 0, 0, 22),
				LayoutOrder = 3,
				MaxTextSize = 16,
				Parent = c,
			})
			local button
			if carried >= rope.maxCarried then
				button = Build.button("Llevas el máximo", Theme.panelLight, { AutoButtonColor = false })
			else
				local affordable = state.coins >= rope.price
				button = Build.button(
					"Comprar · ● " .. Format.number(rope.price),
					if affordable then Theme.good else Theme.card
				)
				button.Activated:Connect(function()
					deps.playUi("ui_click")
					request("buyRope", "rope")
				end)
			end
			button.Size = UDim2.new(1, 0, 0, 40)
			button.LayoutOrder = 4
			button.Parent = c
			-- special equipment: bought once, kept forever
			local owned = state.gear or {}
			for _, def in Gear.List do
				local g = card(1 + def.order)
				Build.label({
					Text = def.name,
					Size = UDim2.new(1, 0, 0, 26),
					LayoutOrder = 1,
					MaxTextSize = 22,
					Parent = g,
				})
				Build.label({
					Text = def.description,
					Font = Theme.bodyFont,
					TextColor3 = Theme.textDim,
					Size = UDim2.new(1, 0, 0, 46),
					LayoutOrder = 2,
					MaxTextSize = 14,
					TextWrapped = true,
					Parent = g,
				})
				Build.label({
					Text = "Tecla <b>" .. def.key .. "</b>",
					RichText = true,
					Font = Theme.bodyFont,
					Size = UDim2.new(1, 0, 0, 22),
					LayoutOrder = 3,
					MaxTextSize = 16,
					Parent = g,
				})
				local gearButton
				if owned[def.id] then
					gearButton = Build.button("Lo tienes", Theme.panelLight, { AutoButtonColor = false })
				else
					local affordable = state.coins >= def.price
					gearButton = Build.button(
						"Comprar · ● " .. Format.number(def.price),
						if affordable then Theme.good else Theme.card
					)
					gearButton.Activated:Connect(function()
						deps.playUi("ui_click")
						purchase("buyGear", def.id, def.name, def.price)
					end)
				end
				gearButton.Size = UDim2.new(1, 0, 0, 40)
				gearButton.LayoutOrder = 4
				gearButton.Parent = g
			end
		else
			grid.CellSize = UDim2.fromOffset(250, 170)
			for _, track in Upgrades.List do
				if track.hidden then
					continue
				end
				local level = state.upgrades[track.id] or 1
				local current = track.levels[level]
				local nextLevel = track.levels[level + 1]
				local c = card(track.order)
				Build.label({
					Text = track.name,
					Size = UDim2.new(1, 0, 0, 26),
					LayoutOrder = 1,
					MaxTextSize = 22,
					Parent = c,
				})
				Build.label({
					Text = track.description,
					Font = Theme.bodyFont,
					TextColor3 = Theme.textDim,
					Size = UDim2.new(1, 0, 0, 30),
					LayoutOrder = 2,
					MaxTextSize = 14,
					TextWrapped = true,
					Parent = c,
				})
				local valueText = string.format(
					"Nivel %d/%d · <b>%s %s</b>",
					level,
					#track.levels,
					Format.number(current.value),
					track.unit
				)
				if nextLevel then
					valueText ..= string.format(
						' → <font color="#6EDC6E"><b>%s</b></font>',
						Format.number(nextLevel.value)
					)
				end
				Build.label({
					Text = valueText,
					RichText = true,
					Font = Theme.bodyFont,
					Size = UDim2.new(1, 0, 0, 22),
					LayoutOrder = 3,
					MaxTextSize = 16,
					Parent = c,
				})
				local button
				if nextLevel then
					local affordable = state.coins >= nextLevel.price
					button = Build.button(
						"Mejorar · ● " .. Format.number(nextLevel.price),
						if affordable then Theme.good else Theme.card
					)
					button.Activated:Connect(function()
						deps.playUi("ui_click")
						purchase("buyUpgrade", track.id, track.name .. " nivel " .. (level + 1), nextLevel.price)
					end)
				else
					button = Build.button("Máximo", Theme.panelLight, { AutoButtonColor = false })
				end
				button.Size = UDim2.new(1, 0, 0, 40)
				button.LayoutOrder = 4
				button.Parent = c
			end
		end
	end

	-- Highlight inside the tab switch itself: a separate Activated connection could run before the
	-- switch and paint the previous tab (Studio test 2 and 3).
	local highlightTabs: () -> () = function() end
	local toolsTab = modal:addTab("Herramientas", 1, function()
		currentTab = "tools"
		highlightTabs()
		render()
	end)
	local upgradesTab = modal:addTab("Mejoras", 2, function()
		currentTab = "upgrades"
		highlightTabs()
		render()
	end)

	local gearTab = modal:addTab("Equipo", 3, function()
		currentTab = "gear"
		highlightTabs()
		render()
	end)

	highlightTabs = function()
		toolsTab.BackgroundColor3 = if currentTab == "tools" then Theme.accent else Theme.card
		upgradesTab.BackgroundColor3 = if currentTab == "upgrades" then Theme.accent else Theme.card
		gearTab.BackgroundColor3 = if currentTab == "gear" then Theme.accent else Theme.card
	end

	local spinConnection: RBXScriptConnection? = nil
	modal.onClose = function()
		confirm.Visible = false
		if spinConnection then
			spinConnection:Disconnect()
			spinConnection = nil
		end
	end

	local api = {}
	function api.open()
		modal:open()
		highlightTabs()
		render()
		if not spinConnection then
			spinConnection = RunService.RenderStepped:Connect(function(dt)
				for _, model in spinning do
					if model.Parent then
						model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 0.8, 0))
					end
				end
			end)
		end
	end
	function api.close()
		modal:close()
	end
	function api.isOpen(): boolean
		return modal:isOpen()
	end
	function api.refresh()
		if modal:isOpen() then
			highlightTabs()
			render()
		end
	end
	return api
end

return ShopUI

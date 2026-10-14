--!strict
-- Backpack contents and the discovery log (every resource in the game, found or not).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Build = require(script.Parent.Build)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)

local InventoryUI = {}

type Deps = { getState: () -> any, playUi: (key: string) -> () }

local function swatch(parent: Instance, resource: Resources.Resource, discovered: boolean): Frame
	local frame = Build("Frame", {
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = if discovered then resource.color else Theme.panelLight,
		Parent = parent,
		[Build.Children] = {
			Build.corner(10),
			Build.stroke(if discovered then Resources.Rarities[resource.rarity].color else Theme.stroke, 2),
		},
	})
	local glyph = Build.label({ Text = if discovered then resource.icon else "?", MaxTextSize = 22, Parent = frame })
	Build.textStroke().Parent = glyph
	return frame
end

function InventoryUI.new(parent: Instance, deps: Deps)
	local modal = Modal.new(parent, "Mochila", Color3.fromRGB(200, 120, 50))
	local currentTab = "backpack"

	local summary = Build.label({
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		RichText = true,
		Parent = modal.headerExtra,
	})
	Build.textStroke().Parent = summary

	local scroll = Build("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.body,
	})
	Build("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 54),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	local footer = Build.label({
		Text = "",
		Font = Theme.bodyFont,
		TextColor3 = Theme.textDim,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		MaxTextSize = 16,
		TextWrapped = true,
		Parent = modal.body,
	})

	local function row(order: number): Frame
		return Build("Frame", {
			BackgroundColor3 = Theme.card,
			LayoutOrder = order,
			Parent = scroll,
			[Build.Children] = {
				Build.corner(10),
				Build.padding(7),
				Build.list(Enum.FillDirection.Horizontal, 10),
			},
		})
	end

	local function render()
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local state = deps.getState()
		if not state then
			return
		end

		if currentTab == "backpack" then
			local total, items = 0, 0
			for _, resource in Resources.List do
				local count = state.inventory[resource.id]
				if count and count > 0 then
					items += 1
					total += count * resource.value
					local r = row(resource.order)
					swatch(r, resource, true)
					Build.label({
						Text = string.format(
							'<b>%s</b>  x%d\n<font color="#%s">%s</font> · %s c/u',
							resource.name,
							count,
							Resources.Rarities[resource.rarity].color:ToHex(),
							Resources.Rarities[resource.rarity].name,
							Format.number(resource.value)
						),
						RichText = true,
						Font = Theme.bodyFont,
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.new(1, -50, 1, 0),
						MaxTextSize = 16,
						Parent = r,
					})
				end
			end
			summary.Text = string.format(
				'%d/%d · <font color="#FFCD3C">● %s</font>',
				state.used,
				state.capacity,
				Format.number(total)
			)
			footer.Text = if items == 0
				then "Tu mochila está vacía. Cava para encontrar minerales."
				else "Vende todo en el carro de la estación de venta, junto a tu agujero."
		else
			local found = 0
			for _, resource in Resources.List do
				local count = state.discoveries[resource.id] or 0
				local discovered = count > 0
				if discovered then
					found += 1
				end
				local r = row(resource.order)
				swatch(r, resource, discovered)
				local text
				if discovered then
					text = string.format(
						'<b>%s</b>\n<font color="#%s">%s</font> · encontrados: %s',
						resource.name,
						Resources.Rarities[resource.rarity].color:ToHex(),
						Resources.Rarities[resource.rarity].name,
						Format.number(count)
					)
				else
					local hint = if resource.spawn
						then string.format("Se rumorea que aparece a partir de %d m", resource.spawn.minDepth)
						else "Material de roca de alguna capa profunda"
					text = "<b>???</b>\n" .. hint
				end
				Build.label({
					Text = text,
					RichText = true,
					Font = Theme.bodyFont,
					TextColor3 = if discovered then Theme.text else Theme.textDim,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -50, 1, 0),
					MaxTextSize = 15,
					Parent = r,
				})
			end
			summary.Text = string.format("%d/%d descubiertos", found, #Resources.List)
			footer.Text = "Cada nuevo descubrimiento te da una recompensa en monedas."
		end
	end

	local backpackTab, logTab
	local function highlightTabs()
		backpackTab.BackgroundColor3 = if currentTab == "backpack" then Theme.accent else Theme.card
		logTab.BackgroundColor3 = if currentTab == "log" then Theme.accent else Theme.card
	end
	backpackTab = modal:addTab("Mochila", 1, function()
		currentTab = "backpack"
		highlightTabs()
		render()
	end)
	logTab = modal:addTab("Descubrimientos", 2, function()
		currentTab = "log"
		highlightTabs()
		render()
	end)

	local sellButton = Build.button("Vender todo", Theme.good, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(150, 38),
		Parent = modal.tabBar.Parent,
	})
	sellButton.Position = UDim2.new(1, -14, 0, 60)
	sellButton.Activated:Connect(function()
		deps.playUi("ui_click")
		Remotes.event("Sell"):FireServer()
	end)

	local api = {}
	function api.open()
		modal:open()
		highlightTabs()
		render()
	end
	function api.close()
		modal:close()
	end
	function api.toggle()
		if modal:isOpen() then
			modal:close()
		else
			api.open()
		end
	end
	function api.isOpen(): boolean
		return modal:isOpen()
	end
	function api.refresh()
		if modal:isOpen() then
			render()
		end
	end
	return api
end

return InventoryUI

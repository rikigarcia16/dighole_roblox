--!strict
-- Shared window chrome for full panels (shop, backpack): title bar, close button, tabs, body.

local TweenService = game:GetService("TweenService")

local Build = require(script.Parent.Build)
local Theme = require(script.Parent.Theme)

local Modal = {}
Modal.__index = Modal

export type Modal = typeof(setmetatable(
	{} :: {
		root: Frame,
		body: Frame,
		tabBar: Frame,
		titleLabel: TextLabel,
		headerExtra: Frame,
		scale: UIScale,
		onClose: (() -> ())?,
	},
	Modal
))

function Modal.new(parent: Instance, title: string, accent: Color3): Modal
	local scale = Instance.new("UIScale")
	local root = Build("Frame", {
		Name = title .. "Modal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.92, 0.82),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 20,
		Parent = parent,
		[Build.Children] = {
			Build.corner(18),
			Build.stroke(Theme.stroke, 3),
			Build("UISizeConstraint", { MaxSize = Vector2.new(820, 560) }),
			scale,
		},
	})

	local header = Build("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = accent,
		Parent = root,
		[Build.Children] = { Build.corner(18) },
	})
	-- square off the header's bottom corners
	Build("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = header,
	})

	local titleLabel = Build.label({
		Text = title,
		Size = UDim2.new(0.5, 0, 0, 36),
		Position = UDim2.new(0, 18, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 30,
		Parent = header,
	})
	Build.textStroke().Parent = titleLabel

	local headerExtra = Build("Frame", {
		Name = "Extra",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -64, 0, 8),
		Size = UDim2.new(0.4, 0, 0, 36),
		Parent = header,
	})

	local self = setmetatable({
		root = root,
		body = nil :: any,
		tabBar = nil :: any,
		titleLabel = titleLabel,
		headerExtra = headerExtra,
		scale = scale,
		onClose = nil,
	}, Modal)

	local close = Build.button("X", Theme.danger, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(40, 36),
		Parent = header,
	})
	close.Activated:Connect(function()
		self:close()
	end)

	self.tabBar = Build("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 60),
		Size = UDim2.new(1, -28, 0, 38),
		Parent = root,
		[Build.Children] = { Build.list(Enum.FillDirection.Horizontal, 8) },
	})

	self.body = Build("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 104),
		Size = UDim2.new(1, -28, 1, -116),
		Parent = root,
	})

	return self
end

function Modal.addTab(self: Modal, text: string, order: number, onSelect: () -> ()): TextButton
	local tab = Build.button(text, Theme.card, {
		Size = UDim2.new(0, 120, 1, 0),
		LayoutOrder = order,
		Parent = self.tabBar,
	})
	tab.Activated:Connect(onSelect)
	return tab
end

function Modal.isOpen(self: Modal): boolean
	return self.root.Visible
end

function Modal.open(self: Modal)
	if self.root.Visible then
		return
	end
	self.root.Visible = true
	self.scale.Scale = 0.85
	TweenService:Create(self.scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

function Modal.close(self: Modal)
	if not self.root.Visible then
		return
	end
	self.root.Visible = false
	if self.onClose then
		self.onClose()
	end
end

return Modal

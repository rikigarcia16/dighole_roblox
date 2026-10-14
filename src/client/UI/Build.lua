--!strict
-- Tiny declarative helper for building Instances in code.
--   Build("Frame", { Size = ..., [Build.Children] = { ... } })

local Theme = require(script.Parent.Theme)

local Build = {}
Build.Children = newproxy(false)

setmetatable(Build, {
	__call = function(_, className: string, props: { [any]: any }?): any
		local instance = Instance.new(className)
		local children
		if props then
			for key, value in props do
				if key == Build.Children then
					children = value
				elseif key ~= "Parent" then
					(instance :: any)[key] = value
				end
			end
		end
		if children then
			for _, child in children do
				child.Parent = instance
			end
		end
		if props and props.Parent then
			instance.Parent = props.Parent
		end
		return instance
	end,
})

function Build.corner(radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	return c
end

function Build.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.stroke
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

function Build.textStroke(): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = Theme.stroke
	s.Thickness = 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	return s
end

function Build.padding(px: number): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	return p
end

function Build.list(direction: Enum.FillDirection, spacing: number, align: Enum.HorizontalAlignment?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction
	l.Padding = UDim.new(0, spacing)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	return l
end

function Build.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.font,
		TextColor3 = Theme.text,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in props do
		if k ~= "MaxTextSize" then
			defaults[k] = v
		end
	end
	local label = Build("TextLabel", defaults)
	if props.TextScaled ~= false then
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = props.MaxTextSize or 28
		limit.Parent = label
	end
	return label
end

function Build.button(text: string, color: Color3, props: { [string]: any }?): TextButton
	local button = Build("TextButton", {
		Text = text,
		Font = Theme.font,
		TextColor3 = Theme.text,
		TextScaled = true,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		[Build.Children] = { Build.corner(10) :: Instance, Build.stroke(Theme.stroke, 2), Build.textStroke() },
	})
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.Parent = button
	local padding = Build.padding(6)
	padding.Parent = button
	if props then
		for k, v in props do
			(button :: any)[k] = v
		end
	end
	return button
end

return Build

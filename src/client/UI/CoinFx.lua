--!strict
-- Feedback on the coin counter (UIController): a gain makes the pill jump and glow, shows a "+N"
-- that rises and fades and, for a big gain (a sale, a quest reward), sends a few coins flying from
-- the middle of the screen into the counter; a spend shakes it with a red "-N". Short and pooled-free
-- (a handful of instances per event, destroyed after), never a full-screen flash.

local TweenService = game:GetService("TweenService")

local Format = require(game:GetService("ReplicatedStorage").Shared.Util.Format)
local Theme = require(script.Parent.Theme)

local CoinFx = {}

local BIG_GAIN = 20 -- coins: from here on the gain also sends flying coins
local MAX_FLYING = 8

export type Api = { changed: (old: number, new: number) -> () }

function CoinFx.new(gui: ScreenGui, pillFrame: Frame): Api
	local scale = Instance.new("UIScale")
	scale.Parent = pillFrame
	local stroke = pillFrame:FindFirstChildOfClass("UIStroke")
	local baseStrokeColor = if stroke then stroke.Color else Theme.coins
	local basePosition = pillFrame.Position

	local function floatingText(text: string, color: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0, 0)
		label.Position = UDim2.new(0, 0, 1, 2)
		label.Size = UDim2.new(1, 0, 0, 26)
		label.Font = Theme.font
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.ZIndex = 5
		local strokeText = Instance.new("UIStroke")
		strokeText.Thickness = 2
		strokeText.Color = Color3.new(0, 0, 0)
		strokeText.Transparency = 0.3
		strokeText.Parent = label
		label.Parent = pillFrame
		local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(label, info, { Position = UDim2.new(0, 0, 1, 30), TextTransparency = 1 }):Play()
		TweenService:Create(strokeText, info, { Transparency = 1 }):Play()
		task.delay(1.2, function()
			label:Destroy()
		end)
	end

	local function jump(color: Color3)
		scale.Scale = 1.18
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		if stroke then
			stroke.Color = color
			TweenService:Create(stroke, TweenInfo.new(0.6), { Color = baseStrokeColor }):Play()
		end
	end

	local function shake()
		local steps = { -6, 6, -4, 4, 0 }
		task.spawn(function()
			for _, dx in steps do
				pillFrame.Position = basePosition + UDim2.fromOffset(dx, 0)
				task.wait(0.035)
			end
			pillFrame.Position = basePosition
		end)
	end

	-- Coins flying from the middle of the screen into the counter, one after another.
	local function flyingCoins(count: number, onArrive: () -> ())
		local target = pillFrame.AbsolutePosition + Vector2.new(24, pillFrame.AbsoluteSize.Y / 2)
		local screen = gui.AbsoluteSize
		for i = 1, count do
			task.delay((i - 1) * 0.06, function()
				local coin = Instance.new("TextLabel")
				coin.BackgroundTransparency = 1
				coin.AnchorPoint = Vector2.new(0.5, 0.5)
				coin.Size = UDim2.fromOffset(26, 26)
				coin.Font = Theme.font
				coin.TextScaled = true
				coin.Text = "●"
				coin.TextColor3 = Theme.coins
				coin.ZIndex = 20
				local s = Instance.new("UIStroke")
				s.Thickness = 2
				s.Color = Color3.fromRGB(120, 80, 10)
				s.Parent = coin
				local spread = Vector2.new((math.random() - 0.5) * 140, (math.random() - 0.5) * 80)
				local start = screen / 2 + spread
				coin.Position = UDim2.fromOffset(start.X, start.Y)
				coin.Parent = gui
				local tween = TweenService:Create(
					coin,
					TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(16, 16) }
				)
				tween.Completed:Connect(function()
					coin:Destroy()
					onArrive()
				end)
				tween:Play()
			end)
		end
	end

	local api = {}
	function api.changed(old: number, new: number)
		local delta = new - old
		if delta > 0 then
			floatingText("+" .. Format.number(delta), Theme.coins)
			if delta >= BIG_GAIN then
				local count = math.clamp(math.floor(math.log10(delta) * 3), 3, MAX_FLYING)
				flyingCoins(count, function()
					jump(Theme.coins)
				end)
			else
				jump(Theme.coins)
			end
		elseif delta < 0 then
			floatingText("−" .. Format.number(-delta), Theme.danger)
			shake()
		end
	end
	return api
end

return CoinFx

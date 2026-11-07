--!strict
-- What the player gets, shown in the world (client only, presentational):
--   * breaking an ore cell: one to three glowing chips pop out of the rock and fly into the player
--   * a rare (or better) find: a big gem rises out of the rock, turns in a beam of its colour with
--     its name over it, then flies to the player; the rarer, the longer and brighter
--   * selling: the ore leaves the player and lands in the sell cart, which answers with a fountain
--     of coins
-- Ordinary rock gives nothing here (its debris is enough): the hierarchy is rock < ore < rare.
-- Every piece is a few anchored, non-colliding parts destroyed within ~2 s.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Resources = require(ReplicatedStorage.Shared.Config.Resources)

local LootController = {}

local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "THNE_Loot"

local MAX_LIVE = 40
local live = 0

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function piece(size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Shape = shape or Enum.PartType.Block
	p.Parent = folder
	return p
end

-- Moves `p` along an arc from `from` to wherever `target()` is at the end, spinning and shrinking.
local function fly(
	p: BasePart,
	from: Vector3,
	target: () -> Vector3?,
	seconds: number,
	height: number,
	done: (() -> ())?
)
	local start = os.clock()
	local size = p.Size
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / seconds, 0, 1)
		local to = target() or from
		local e = t * t * (3 - 2 * t)
		local pos = from:Lerp(to, e) + Vector3.new(0, math.sin(t * math.pi) * height, 0)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(t * 9, t * 7, 0)
		p.Size = size * (1 - 0.6 * t)
		if t >= 1 then
			conn:Disconnect()
			p:Destroy()
			live -= 1
			if done then
				done()
			end
		end
	end)
end

local function toPlayer(): Vector3?
	local r = rootPosition()
	return r and r + Vector3.new(0, 1, 0)
end

-- Ore chips popping out of a broken cell.
function LootController.oreBroken(position: Vector3, resource: Resources.Resource)
	if not resource.isOre or live > MAX_LIVE then
		return
	end
	local order = Resources.Rarities[resource.rarity].order
	for i = 1, math.clamp(order, 1, 3) do
		live += 1
		local chip = piece(Vector3.one * 0.55, resource.color)
		local from = position + Vector3.new((math.random() - 0.5) * 1.5, 0.5, (math.random() - 0.5) * 1.5)
		task.delay((i - 1) * 0.07, function()
			fly(chip, from, toPlayer, 0.55 + math.random() * 0.15, 3 + math.random() * 1.5, nil)
		end)
	end
end

-- A rare or better find: rise, show itself, then come to the player.
function LootController.bigFind(position: Vector3, resourceId: string)
	local resource = Resources.get(resourceId)
	if not resource then
		return
	end
	local rarity = Resources.Rarities[resource.rarity]
	local order = rarity.order
	if order < 3 then
		return
	end
	live += 1
	local hold = if order >= 5 then 1.6 elseif order >= 4 then 1.1 else 0.7
	local gem = piece(Vector3.new(1.1, 1.5, 1.1) * (0.9 + order * 0.12), resource.color)
	gem.CFrame = CFrame.new(position)
	local glow = Instance.new("PointLight")
	glow.Color = resource.color
	glow.Range = 10 + order * 3
	glow.Brightness = 2
	glow.Parent = gem
	local beam = piece(Vector3.new(14, 1.6, 1.6), resource.color, Enum.PartType.Cylinder)
	beam.Transparency = 0.6
	beam.CFrame = CFrame.new(position + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90))
	TweenService:Create(beam, TweenInfo.new(hold + 0.6), { Transparency = 1, Size = Vector3.new(14, 0.2, 0.2) }):Play()
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 46)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = gem
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = resource.name
	label.TextColor3 = rarity.color
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	-- rise and turn in the beam
	local up = position + Vector3.new(0, 3, 0)
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local rise = math.min(1, t / 0.35)
		gem.CFrame = CFrame.new(position:Lerp(up, 1 - (1 - rise) ^ 3) + Vector3.new(0, math.sin(t * 4) * 0.2, 0))
			* CFrame.Angles(0, t * 3, math.rad(15))
		if t >= hold then
			conn:Disconnect()
			beam:Destroy()
			gui:Destroy()
			fly(gem, gem.Position, toPlayer, 0.6, 2, nil)
		end
	end)
end

-- Selling: the load flies from the player into the cart, then coins spring out of it.
function LootController.sold(colors: { Color3 })
	local from = rootPosition()
	if not from then
		return
	end
	local cart: BasePart? = nil
	local world = workspace:FindFirstChild("World")
	if world then
		for _, plot in world:GetChildren() do
			if plot:GetAttribute("Owner") == player.UserId then
				cart = plot:FindFirstChild("SellCart") :: BasePart?
			end
		end
	end
	if not cart then
		return
	end
	local target = cart.Position + Vector3.new(0, 1.5, 0)
	local count = math.clamp(#colors * 2, 6, 10)
	for i = 1, count do
		task.delay((i - 1) * 0.05, function()
			live += 1
			local chip = piece(Vector3.one * 0.6, colors[(i - 1) % #colors + 1])
			fly(chip, from + Vector3.new(0, 1.5, 0), function()
				return target
			end, 0.5, 4, nil)
		end)
	end
	task.delay(0.55 + count * 0.05, function()
		for i = 1, 14 do
			live += 1
			local coin = piece(Vector3.new(0.25, 1.1, 1.1), Color3.fromRGB(255, 205, 60), Enum.PartType.Cylinder)
			coin.Material = Enum.Material.Metal
			local dir = Vector3.new(math.cos(i * 0.9), 0, math.sin(i * 0.9))
			local landing = target + dir * (2 + math.random() * 3) - Vector3.new(0, 1.2, 0)
			task.delay(i * 0.02, function()
				fly(coin, target, function()
					return landing
				end, 0.7, 4 + math.random() * 2, nil)
			end)
		end
	end)
end

function LootController.start()
	folder.Parent = workspace
	local EffectsController = require(script.Parent.EffectsController)
	EffectsController.oreBroken:Connect(LootController.oreBroken)
	EffectsController.bigFind:Connect(LootController.bigFind)
end

return LootController

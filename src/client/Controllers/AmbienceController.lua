--!strict
-- Depth-driven ambience: lighting/fog per zone, the player's head lamp and zone banners.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local AmbienceController = {}
AmbienceController.depthChanged = Signal.new() -- (depthMeters, zone)
AmbienceController.zoneChanged = Signal.new() -- (zone)

local player = Players.LocalPlayer
local UNDERGROUND_DEPTH = 3

local surface = {
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	FogColor = Lighting.FogColor,
	FogEnd = Lighting.FogEnd,
}

local currentKey = ""
local lamp: PointLight? = nil

local function ensureLamp(): PointLight?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return nil
	end
	if lamp and lamp.Parent == head then
		return lamp
	end
	local light = Instance.new("PointLight")
	light.Name = "HeadLamp"
	light.Range = 26
	light.Brightness = 0
	light.Color = Color3.fromRGB(255, 236, 200)
	light.Shadows = false
	light.Parent = head
	lamp = light
	return light
end

local function apply(depth: number)
	local zone = Zones.at(depth)
	local underground = depth > UNDERGROUND_DEPTH
	local key = (if underground then "u" else "s") .. zone.id
	if key == currentKey then
		return
	end
	local previousZoneId = currentKey:sub(2)
	currentKey = key

	local goal
	if underground then
		goal = {
			Ambient = zone.lighting.ambient,
			OutdoorAmbient = zone.lighting.ambient,
			FogColor = zone.lighting.fogColor,
			FogEnd = zone.lighting.fogEnd,
		}
	else
		goal = surface
	end
	TweenService:Create(Lighting, TweenInfo.new(1.5), goal):Play()

	local light = ensureLamp()
	if light then
		local brightness = if underground then math.max(zone.lighting.lampBrightness, 0.8) else 0
		TweenService:Create(light, TweenInfo.new(1), { Brightness = brightness }):Play()
	end

	if previousZoneId ~= zone.id then
		AmbienceController.zoneChanged:Fire(zone)
	end
end

function AmbienceController.start()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		local a = Instance.new("Atmosphere")
		a.Density = 0.28
		a.Offset = 0.2
		a.Color = Color3.fromRGB(199, 214, 230)
		a.Decay = Color3.fromRGB(120, 140, 170)
		a.Glare = 0.2
		a.Haze = 1.2
		a.Parent = Lighting
	end

	task.spawn(function()
		local lastDepth = -1
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local depth = Grid.depthMetersFromY(root.Position.Y - 3)
				if math.floor(depth) ~= lastDepth then
					lastDepth = math.floor(depth)
					AmbienceController.depthChanged:Fire(depth, Zones.at(depth))
				end
				apply(depth)
				if lamp == nil or lamp.Parent == nil then
					currentKey = "" -- character respawned: re-apply to recreate the lamp
				end
			end
			task.wait(0.2)
		end
	end)
end

return AmbienceController

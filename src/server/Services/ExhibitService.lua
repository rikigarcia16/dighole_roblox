--!strict
-- The house display case. Pieces of the story (resources with `keep`: the antique fragment, the
-- relic, the artifact) are not sold with the rest of the backpack. At the case, F exhibits every
-- kept piece not shown yet (one unit each); exhibiting all three completes the "relics" collection
-- (Config/Collections), which pays more than selling them and adds to the journal.
--
-- Shown pieces are saved in profile.collection.exhibit and rebuilt in the case on join, so the
-- house reflects how far the player has gone.

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Collections = require(ReplicatedStorage.Shared.Config.Collections)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)

local ExhibitService = {}

local INTERACT_DISTANCE = 12

-- Case slot order: the "relics" set order.
local ORDER: { string } = {}
for _, set in Collections do
	if set.kind == "exhibit" then
		for _, id in set.items or {} do
			table.insert(ORDER, id)
		end
	end
end

local shown: { [any]: Folder } = {}

local function displayModel(resource: Resources.Resource, at: Vector3, parent: Instance)
	local stand = Instance.new("Part")
	stand.Name = "Stand"
	stand.Anchored = true
	stand.Size = Vector3.new(1.4, 0.3, 1.4)
	stand.CFrame = CFrame.new(at - Vector3.new(0, 0.6, 0))
	stand.Color = Color3.fromRGB(60, 46, 34)
	stand.Material = Enum.Material.Wood
	stand.Parent = parent
	local piece = Instance.new("Part")
	piece.Name = resource.id
	piece.Anchored = true
	piece.CanCollide = false
	piece.Size = Vector3.new(0.9, 0.9, 0.9)
	piece.CFrame = CFrame.new(at) * CFrame.Angles(math.rad(20), math.rad(35), 0)
	piece.Color = resource.color
	piece.Material = if resource.rarity == "Unique" or resource.rarity == "Epic"
		then Enum.Material.Neon
		else Enum.Material.Marble
	piece.Parent = parent
	piece:SetAttribute("SpinSpeed", 0.35)
	CollectionService:AddTag(piece, "THNE_Spin") -- turns slowly in the case (AmbientLifeController)
end

local function rebuild(plot: any, profile: any)
	local old = shown[plot]
	if old then
		old:Destroy()
		shown[plot] = nil
	end
	if not plot.folder or not plot.points then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Exhibit"
	for i, id in ORDER do
		local resource = Resources.get(id)
		local slot = plot.points.vitrine[i]
		if resource and slot and profile.collection.exhibit[id] then
			displayModel(resource, slot, folder)
		end
	end
	folder.Parent = plot.folder
	shown[plot] = folder
end

local function near(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude <= INTERACT_DISTANCE
end

-- Exhibits every kept piece the player carries that is not in the case yet. Returns how many.
function ExhibitService.exhibit(player: Player): number
	local profile = PlayerDataService.get(player)
	local plot = PlotService.get(player)
	if not profile or not plot then
		return 0
	end
	local added = {}
	for _, id in ORDER do
		local count = profile.inventory[id] or 0
		if count > 0 and not profile.collection.exhibit[id] then
			profile.inventory[id] = if count > 1 then count - 1 else nil
			profile.collection.exhibit[id] = true
			local resource = Resources.get(id)
			table.insert(added, if resource then resource.name else id)
		end
	end
	if #added == 0 then
		local missing = 0
		for _, id in ORDER do
			if not profile.collection.exhibit[id] then
				missing += 1
			end
		end
		StateService.notify(
			player,
			"info",
			if missing == 0
				then "La vitrina está completa."
				else "No llevas nada nuevo que exponer. Faltan " .. missing .. " pieza(s): búscalas bajo tierra.",
			"exhibit_none",
			4
		)
		return 0
	end
	rebuild(plot, profile)
	StateService.notify(player, "discovery", "Expuesto en la vitrina: " .. table.concat(added, ", "))
	StateService.push(player)
	return #added
end

function ExhibitService.start()
	PlotService.onReady(function(player, plot)
		local profile = PlayerDataService.get(player)
		if profile then
			rebuild(plot, profile)
		end
	end)
	PlotService.onReleased(function(plot)
		local old = shown[plot]
		if old then
			old:Destroy()
			shown[plot] = nil
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("Action") ~= "Exhibit" then
			return
		end
		local plot = PlotService.get(player)
		local cabinet = prompt.Parent
		-- only your own house's case
		if
			not plot
			or not plot.folder
			or not cabinet
			or not cabinet:IsA("BasePart")
			or not cabinet:IsDescendantOf(plot.folder)
			or not near(player, cabinet :: BasePart)
		then
			return
		end
		ExhibitService.exhibit(player)
	end)
end

return ExhibitService

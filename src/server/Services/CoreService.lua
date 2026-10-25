--!strict
-- "El fondo" (Config/Anomalies.Rooms.core) and the bedrock under it: the end of the story.
--   * The room is built with its sector and revealed when a doorway opens.
--   * One interaction: lay your hand on the empty third column. The wall engraves your number of
--     blocks dug, letter by letter, under E. and the older diggers, and the ancestral tool is yours.
--   * With the ancestral tool, the bedrock at the bottom of the plot gives way after a few swings:
--     white light, and you come out on the lawn of your own plot, the hole in front of you as on the
--     first day. Nothing is dug below the bedrock: breaking it is this interaction, not a cell.
--
-- State lives in the player's profile (anomalies.core). Only the plot owner engraves in their own
-- room; anyone allowed to dig the plot can break its bedrock with their own ancestral tool.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Anomalies = require(ReplicatedStorage.Shared.Config.Anomalies)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Caves = require(script.Parent.Parent.Logic.Caves)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local SpecialsService = require(script.Parent.SpecialsService)
local FxService = require(script.Parent.FxService)
local DiggingService = require(script.Parent.DiggingService)
local CoreRoomBuilder = require(script.Parent.CoreRoomBuilder)

local CoreService = {}

local INTERACT_DISTANCE = 12
local ENGRAVE_SECONDS = 3
local BREAK_LIGHT_SECONDS = 1.6 -- the white light fills the screen before the player is moved
local BEDROCK_FORGET_SECONDS = 12 -- swings further apart than this start the count again

type Core = { plot: any, room: CoreRoomBuilder.Room, revealed: boolean, busy: boolean }

local cores: { [any]: Core } = {}
local bedrockHits: { [Player]: { count: number, last: number } } = {}
local breaking: { [Player]: boolean } = {}

local function ownerProfile(plot: any): any?
	return plot.owner and PlayerDataService.get(plot.owner)
end

local function columnText(name: string, count: number): string
	return name .. " — " .. CoreRoomBuilder.spaced(count)
end

local function showColumn(core: Core, name: string, count: number)
	core.room.column.Text = columnText(name, count)
	core.room.column.MaxVisibleGraphemes = -1
	core.room.model:SetAttribute("Engraved", true)
	core.room.hand.Transparency = 0.85
end

local function grantTool(player: Player, profile: any): boolean
	if profile.tools[Anomalies.CoreToolId] then
		return false
	end
	profile.tools[Anomalies.CoreToolId] = true
	return true
end

local function engrave(player: Player, core: Core)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local state = profile.anomalies.core
	if state.engraved or core.busy then
		return
	end
	core.busy = true
	core.room.handPrompt.Enabled = false
	state.found = true
	state.engraved = true
	state.engravedCount = profile.stats.cellsDug
	state.engravedAt = os.time()

	-- the wall cuts the number letter by letter
	local column = core.room.column
	column.Text = columnText(player.Name, state.engravedCount)
	column.MaxVisibleGraphemes = 0
	local letters = utf8.len(column.Text) or #column.Text
	local cut = Instance.new("NumberValue")
	cut.Changed:Connect(function(value: number)
		column.MaxVisibleGraphemes = math.floor(value)
	end)
	local tween = TweenService:Create(cut, TweenInfo.new(ENGRAVE_SECONDS * 0.8, Enum.EasingStyle.Linear), {
		Value = letters,
	})
	tween.Completed:Connect(function()
		cut:Destroy()
	end)
	tween:Play()
	core.room.model:SetAttribute("Engraved", true) -- the two rhythms stop (CoreController)
	FxService.special(player, core.room.hand.Position, "core_engraved", nil)

	task.delay(ENGRAVE_SECONDS, function()
		core.busy = false
		if core.room.model.Parent then
			showColumn(core, player.Name, state.engravedCount)
		end
		local granted = grantTool(player, profile)
		if player.Parent then
			StateService.notify(player, "discovery", "El diario ha crecido: «El fondo»")
			if granted then
				local tool = Tools.get(Anomalies.CoreToolId)
				StateService.notify(
					player,
					"success",
					string.format(
						"Tienes la %s. Equípala en el garaje.",
						if tool then tool.name else "herramienta ancestral"
					)
				)
			end
			StateService.push(player)
		end
	end)
	StateService.push(player)
end

local function build(plot: any, sector: Caves.Sector, folder: Folder)
	if sector.anomalyId ~= "core" or cores[plot] then
		return
	end
	local profile = ownerProfile(plot)
	if not profile then
		return
	end
	local room = CoreRoomBuilder.build(plot, folder)
	local core: Core = { plot = plot, room = room, revealed = false, busy = false }
	cores[plot] = core
	local state = profile.anomalies.core
	if state.engraved then
		showColumn(core, plot.owner.Name, state.engravedCount)
	end
end

local function onRevealed(plot: any, sectorIndex: number, system: number, finder: Player?)
	if sectorIndex ~= Anomalies.Rooms.core.sector then
		return
	end
	local core = cores[plot]
	local sector = Caves.sector(plot.seed, sectorIndex)
	if not core or sector.anomalySystem ~= system or core.revealed then
		return
	end
	core.revealed = true
	core.room.model:SetAttribute("Revealed", true)
	local profile = ownerProfile(plot)
	if profile then
		core.room.handPrompt.Enabled = not profile.anomalies.core.engraved
		profile.anomalies.core.found = true
	end
	if finder then
		local finderProfile = PlayerDataService.get(finder)
		if finderProfile and finder ~= plot.owner then
			finderProfile.anomalies.core.found = true
		end
		FxService.special(finder, core.room.center + Vector3.new(0, 4, 0), "core_found", nil)
		StateService.notify(finder, "discovery", "Nueva entrada en el diario: «El fondo»")
		StateService.push(finder)
	end
	if plot.owner and plot.owner ~= finder then
		StateService.push(plot.owner)
	end
end

local function near(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude <= INTERACT_DISTANCE
end

-- The bedrock gives way: white light, then the lawn of the player's own plot.
local function breakThrough(player: Player, profile: any, position: Vector3)
	breaking[player] = true
	bedrockHits[player] = nil
	profile.anomalies.core.loops += 1
	local loops = profile.anomalies.core.loops
	FxService.personal(player, position, "bedrock_break")
	task.delay(BREAK_LIGHT_SECONDS, function()
		breaking[player] = nil
		if not player.Parent then
			return
		end
		PlotService.teleportToSurface(player)
		StateService.notify(
			player,
			"discovery",
			if loops == 1 then "Debajo del fondo estaba el jardín." else "El agujero da la vuelta otra vez."
		)
		StateService.push(player)
	end)
	StateService.push(player)
end

-- A swing at the bedrock (DiggingService has checked plot, reach and cooldown).
local function onBedrock(player: Player, _plot: any, position: Vector3)
	local profile = PlayerDataService.get(player)
	if not profile or breaking[player] then
		return
	end
	if profile.equippedTool ~= Anomalies.CoreToolId or not profile.anomalies.core.engraved then
		StateService.notify(
			player,
			"info",
			"La roca madre no se deja rayar. Ninguna herramienta de arriba la toca.",
			"bedrock",
			5
		)
		FxService.broadcast(player, position, "core_matter", false, profile.equippedTool, nil, -1)
		return
	end
	local now = os.clock()
	local hits = bedrockHits[player]
	if not hits or now - hits.last > BEDROCK_FORGET_SECONDS then
		hits = { count = 0, last = now }
		bedrockHits[player] = hits
	end
	hits.count += 1
	hits.last = now
	local progress = math.min(1, hits.count / Anomalies.BedrockHits)
	FxService.broadcast(player, position, "core_matter", false, profile.equippedTool, nil, progress)
	if hits.count >= Anomalies.BedrockHits then
		breakThrough(player, profile, position)
	end
end

function CoreService.start()
	SpecialsService.onSectorBuilt(build)
	SpecialsService.onSystemRevealed(onRevealed)
	DiggingService.setBedrockHandler(onBedrock)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("Action") ~= "CoreEngrave" then
			return
		end
		for _, core in cores do
			if prompt:IsDescendantOf(core.room.model) then
				if not core.revealed or not near(player, core.room.hand) then
					return
				end
				if core.plot.owner ~= player then
					StateService.notify(player, "info", "Esta columna espera otra mano.", "core_foreign", 4)
					return
				end
				engrave(player, core)
				return
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		bedrockHits[player] = nil
		breaking[player] = nil
	end)
	PlotService.onReleased(function(plot)
		cores[plot] = nil -- the model is destroyed with the plot's Underground folder
	end)
end

return CoreService

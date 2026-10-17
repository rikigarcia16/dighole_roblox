--!strict
-- The Counter: a machine at the bottom of the Forgotten Mines that has been counting every block
-- its plot owner digs.
--
--   * built when its sector is generated (SpecialsService hook), sealed until a doorway is dug
--   * three rings: only the plot owner can turn them; turns are validated and saved
--   * solving runs a short sequence (CounterSequence) that reveals the owner's exact number of
--     blocks dug (profile.stats.cellsDug, kept by DiggingService), then keeps showing it live
--   * the reward is narrative (journal) plus a permanent lift station in the room
--
-- Counter state lives in the plot owner's profile (anomalies.counter), so it survives leaving.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Anomalies = require(ReplicatedStorage.Shared.Config.Anomalies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Caves = require(script.Parent.Parent.Logic.Caves)
local CounterPuzzle = require(script.Parent.Parent.Logic.CounterPuzzle)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local SpecialsService = require(script.Parent.SpecialsService)
local FxService = require(script.Parent.FxService)
local CounterRoomBuilder = require(script.Parent.CounterRoomBuilder)

local AnomalyService = {}

local SEQUENCE_SECONDS = 7
local TURN_COOLDOWN = 0.25
local INTERACT_DISTANCE = 12

type Counter = {
	plot: any,
	room: CounterRoomBuilder.Room,
	puzzle: CounterPuzzle.State,
	revealed: boolean,
	busy: boolean, -- sequence playing
}

local counters: { [any]: Counter } = {}
local lastTurn: { [Player]: number } = {}

-- Called after the room is unlocked: MobilityService installs the station (set by MobilityService).
local stationGranted: ((Player, string, CFrame) -> ())? = nil
function AnomalyService.setStationGranter(callback: (Player, string, CFrame) -> ())
	stationGranted = callback
end

function AnomalyService.counterOf(plot: any): Counter?
	return counters[plot]
end

local function ownerProfile(plot: any): any?
	return plot.owner and PlayerDataService.get(plot.owner)
end

local function setPrompts(counter: Counter)
	local active = counter.revealed and not counter.puzzle.solved and not counter.busy
	for _, handle in counter.room.handles do
		local prompt = handle:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = active
		end
	end
	local tabletPrompt = counter.room.tablet:FindFirstChildOfClass("ProximityPrompt")
	if tabletPrompt then
		tabletPrompt.Enabled = counter.revealed
	end
end

local function publishRings(counter: Counter)
	for r, ring in counter.room.rings do
		ring:SetAttribute("Index", counter.puzzle.rings[r])
		ring:SetAttribute("Locked", CounterPuzzle.isLocked(counter.plot.seed, counter.puzzle, r))
	end
end

local function publishCount(counter: Counter)
	local profile = ownerProfile(counter.plot)
	if profile and counter.puzzle.solved and not counter.busy then
		counter.room.model:SetAttribute("Count", profile.stats.cellsDug)
	end
end

local function build(plot: any, sector: Caves.Sector, folder: Folder)
	if not sector.counterSystem or counters[plot] then
		return
	end
	local profile = ownerProfile(plot)
	if not profile then
		return
	end
	local stored = profile.anomalies.counter
	local puzzle =
		CounterPuzzle.sanitize(plot.seed, if stored.solved then { solved = true } else { rings = stored.rings })
	local room = CounterRoomBuilder.build(plot, CounterPuzzle.solution(plot.seed), folder)
	local counter: Counter = { plot = plot, room = room, puzzle = puzzle, revealed = false, busy = false }
	counters[plot] = counter
	room.model:SetAttribute("Solved", puzzle.solved)
	publishRings(counter)
	publishCount(counter)
	setPrompts(counter)
end

local function onRevealed(plot: any, sectorIndex: number, system: number, finder: Player?)
	if sectorIndex ~= Anomalies.CounterSector then
		return
	end
	local counter = counters[plot]
	if not counter or Caves.sector(plot.seed, sectorIndex).counterSystem ~= system or counter.revealed then
		return
	end
	counter.revealed = true
	counter.room.model:SetAttribute("Revealed", true)
	setPrompts(counter)
	local profile = ownerProfile(plot)
	if profile and not profile.anomalies.counter.found then
		profile.anomalies.counter.found = true
	end
	if finder then
		local finderProfile = PlayerDataService.get(finder)
		if finderProfile and finder ~= plot.owner then
			finderProfile.anomalies.counter.found = true
		end
		-- No quest marker: a banner and a change of sound tell the player this place is different.
		FxService.special(finder, counter.room.center + Vector3.new(0, 4, 0), "counter_found", nil)
		StateService.notify(finder, "discovery", "Nueva entrada en el diario: «Una sala que nadie excavó»")
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

local function solve(counter: Counter, player: Player)
	local profile = ownerProfile(counter.plot)
	if not profile then
		return
	end
	local count = profile.stats.cellsDug
	local stored = profile.anomalies.counter
	stored.solved = true
	stored.found = true
	stored.solvedCount = count
	stored.solvedAt = os.time()
	stored.rings = table.clone(counter.puzzle.rings)
	counter.busy = true
	setPrompts(counter)

	-- Everyone nearby sees the sequence; the number shown is the owner's.
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if other == player or (root and (root.Position - counter.room.center).Magnitude < 160) then
			Remotes.event("CounterSequence"):FireClient(other, counter.room.model, count)
		end
	end

	task.delay(SEQUENCE_SECONDS, function()
		counter.busy = false
		counter.room.model:SetAttribute("Solved", true)
		publishCount(counter)
		setPrompts(counter)
		if not player.Parent then
			return
		end
		StateService.notify(player, "discovery", "Nueva entrada en el diario: «Nos está contando»")
		if stationGranted then
			stationGranted(player, "counter", counter.room.stationSpot)
		end
		StateService.push(player)
	end)
	StateService.push(player)
end

local function turnRing(player: Player, counter: Counter, ring: number)
	if counter.plot.owner ~= player then
		StateService.notify(player, "info", "La máquina no reacciona a tu mano.", "counter_foreign", 4)
		return
	end
	if not counter.revealed or counter.puzzle.solved or counter.busy then
		return
	end
	local now = os.clock()
	if lastTurn[player] and now - lastTurn[player] < TURN_COOLDOWN then
		return
	end
	lastTurn[player] = now
	local changed, lockedNow, solvedNow = CounterPuzzle.rotate(counter.plot.seed, counter.puzzle, ring)
	if not changed then
		return
	end
	local profile = ownerProfile(counter.plot)
	if profile then
		profile.anomalies.counter.rings = table.clone(counter.puzzle.rings)
	end
	publishRings(counter)
	if lockedNow then
		FxService.special(player, counter.room.handles[ring].Position, "counter_lock", nil)
	end
	if solvedNow then
		solve(counter, player)
	end
end

local function findCounter(prompt: ProximityPrompt): Counter?
	for _, counter in counters do
		if prompt:IsDescendantOf(counter.room.model) then
			return counter
		end
	end
	return nil
end

function AnomalyService.start()
	SpecialsService.onSectorBuilt(build)
	SpecialsService.onSystemRevealed(onRevealed)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local action = prompt:GetAttribute("Action")
		if action ~= "CounterRing" and action ~= "CounterTablet" then
			return
		end
		local counter = findCounter(prompt)
		local parentPart = prompt.Parent
		if not counter or not parentPart or not parentPart:IsA("BasePart") or not near(player, parentPart) then
			return
		end
		if action == "CounterTablet" then
			if counter.revealed then
				SpecialsService.readNote(player, "stone_tablet")
			end
		else
			local ring = prompt:GetAttribute("Ring")
			if type(ring) == "number" then
				turnRing(player, counter, ring)
			end
		end
	end)

	-- The machine keeps counting: refresh the display whenever the owner's state changes.
	StateService.beforePush(function(player)
		local plot = PlotService.get(player)
		local counter = plot and counters[plot]
		if counter then
			publishCount(counter)
		end
	end)

	StateService.addSnapshotProvider(function(_player, profile, snapshot)
		snapshot.anomalies = profile.anomalies
	end)

	PlotService.onReleased(function(plot)
		counters[plot] = nil -- the model is destroyed with the plot's Underground folder
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastTurn[player] = nil
	end)
end

return AnomalyService

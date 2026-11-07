--!strict
-- What the game reports to Roblox Analytics, derived from the profile (pure, testable).
--
-- Nothing here is saved: the service takes a baseline when the player joins and reports only what
-- becomes true during the session, so a returning player never re-sends old milestones.
--
-- * Onboarding funnel: ordered steps. Roblox counts each step once per player and treats a skipped
--   step as completed, so every step must imply the previous ones in normal play.
-- * Milestones: custom events with at most three string fields (Roblox limit), fixed event names
--   and values bounded by the game's own content (zones, tools, notes…), never by player input.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Tools = require(Shared.Config.Tools)
local Resources = require(Shared.Config.Resources)

local AnalyticsPlan = {}

export type Step = { name: string, reached: (profile: any) -> boolean }
export type Milestone = { event: string, value: number, field: string }

local function zoneIndex(zoneId: string): number
	for i, zone in Zones.List do
		if zone.id == zoneId then
			return i
		end
	end
	return 0
end

local function toolIndex(toolId: string): number
	for i, tool in Tools.List do
		if tool.id == toolId then
			return i
		end
	end
	return 0
end

local function foundOre(profile: any): boolean
	for resourceId, count in profile.discoveries do
		local resource = Resources.get(resourceId)
		if resource and resource.isOre and count > 0 then
			return true
		end
	end
	return false
end

-- Logged with LogOnboardingFunnelStepEvent(player, index, name). Keep the order: a later step
-- implies the earlier ones.
AnalyticsPlan.Onboarding = {
	{
		name = "Entra en la parcela",
		reached = function(_profile)
			return true
		end,
	},
	{
		name = "Primer golpe",
		reached = function(profile)
			return profile.stats.cellsDug > 0
		end,
	},
	{ name = "Primer mineral", reached = foundOre },
	{
		name = "Primera venta",
		reached = function(profile)
			return profile.stats.sales > 0
		end,
	},
	{
		name = "Segunda herramienta",
		reached = function(profile)
			for toolId in profile.tools do
				if toolId ~= Tools.DefaultToolId then
					return true
				end
			end
			return false
		end,
	},
	{
		name = "25 m",
		reached = function(profile)
			return profile.stats.maxDepth >= 25
		end,
	},
	{
		name = "Minas Olvidadas",
		reached = function(profile)
			return profile.zonesReached.forgotten_mines == true
		end,
	},
	{
		name = "Primera estación",
		reached = function(profile)
			return #profile.mobility.stations > 0
		end,
	},
	{
		name = "Cuevas de Cristal",
		reached = function(profile)
			return profile.zonesReached.crystal_caves == true
		end,
	},
} :: { Step }

-- Highest step index whose condition holds, counting only an unbroken run from step 1.
function AnalyticsPlan.onboardingStep(profile: any): number
	local reached = 0
	for i, step in AnalyticsPlan.Onboarding do
		if not step.reached(profile) then
			break
		end
		reached = i
	end
	return reached
end

-- Every milestone currently true for the profile, keyed by a stable id.
function AnalyticsPlan.milestones(profile: any): { [string]: Milestone }
	local out: { [string]: Milestone } = {}
	for zoneId, reached in profile.zonesReached do
		if reached and zoneIndex(zoneId) > 0 then
			out["zone:" .. zoneId] = { event = "ZonaAlcanzada", value = zoneIndex(zoneId), field = "Zona - " .. zoneId }
		end
	end
	for toolId, owned in profile.tools do
		if owned and toolIndex(toolId) > 1 then
			out["tool:" .. toolId] =
				{ event = "HerramientaConseguida", value = toolIndex(toolId), field = "Herramienta - " .. toolId }
		end
	end
	for noteId, read in profile.clues do
		if read then
			out["clue:" .. noteId] = { event = "NotaLeida", value = 1, field = "Nota - " .. noteId }
		end
	end
	for featId, earned in profile.feats do
		if earned then
			out["feat:" .. featId] = { event = "HazanaConseguida", value = 1, field = "Hazana - " .. featId }
		end
	end
	for gearId, owned in profile.gear do
		if owned then
			out["gear:" .. gearId] = { event = "EquipoConseguido", value = 1, field = "Equipo - " .. gearId }
		end
	end
	for i, station in profile.mobility.stations do
		out["station:" .. i] = { event = "EstacionInstalada", value = i, field = "Estacion - " .. tostring(station.id) }
	end
	local anomalies = profile.anomalies
	local story = {
		{ "counter_found", anomalies.counter.found },
		{ "counter_solved", anomalies.counter.solved },
		{ "workshop_found", anomalies.workshop.found },
		{ "workshop_hung", anomalies.workshop.hung },
		{ "core_found", anomalies.core.found },
		{ "core_engraved", anomalies.core.engraved },
		{ "core_looped", anomalies.core.loops > 0 },
	}
	for _, entry in story do
		if entry[2] == true then
			out["story:" .. entry[1]] = { event = "Historia", value = 1, field = "Paso - " .. entry[1] }
		end
	end
	return out
end

-- Milestones in `current` that were not in `previous`, in a stable order (zones and tools first,
-- so a burst reads naturally in the event log).
function AnalyticsPlan.newMilestones(previous: { [string]: Milestone }, current: { [string]: Milestone }): { Milestone }
	local keys = {}
	for key in current do
		if not previous[key] then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local out = {}
	for _, key in keys do
		table.insert(out, current[key])
	end
	return out
end

-- Where the player came from: the LaunchData of a Roblox share link. Only known codes are kept so a
-- hand-made link cannot fill the analytics with arbitrary values.
AnalyticsPlan.Origins = {
	ig_bio = true,
	ig_stories = true,
	ig_reels = true,
	ig_post = true,
	ig_beta = true,
	tiktok = true,
	youtube = true,
	creador = true,
	ads = true,
	otro = true,
} :: { [string]: boolean }

function AnalyticsPlan.origin(launchData: any): string
	if type(launchData) ~= "string" or launchData == "" then
		return "ninguno"
	end
	local code = string.lower(string.sub(launchData, 1, 24))
	if AnalyticsPlan.Origins[code] then
		return code
	end
	-- creator links: "creador_<name>" all count as "creador" (names would blow the cardinality)
	if string.sub(code, 1, 8) == "creador_" then
		return "creador"
	end
	return "otro"
end

return AnalyticsPlan

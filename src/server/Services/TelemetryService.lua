--!strict
-- Reports progress to Roblox Analytics (onboarding funnel + custom events). See docs/marketing/09.
--
-- Roblox only accepts these events from servers of a published game: in Studio every call is a
-- no-op here, so playtests never pollute the real dashboards. All calls are wrapped in pcall: a
-- failing analytics call must never break gameplay.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local AnalyticsPlan = require(script.Parent.Parent.Logic.AnalyticsPlan)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)

local TelemetryService = {}

type Session = { step: number, milestones: { [string]: AnalyticsPlan.Milestone }, origin: string }
local sessions: { [Player]: Session } = {}

local enabled = not RunService:IsStudio() and game.PlaceId ~= 0

local function fields(a: string, b: string?): { [string]: string }
	local out = { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = a }
	if b then
		out[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = b
	end
	return out
end

local function call(fn: () -> ())
	if not enabled then
		return
	end
	local ok, err = pcall(fn)
	if not ok then
		warn("[Telemetry] " .. tostring(err))
	end
end

-- A custom event outside the profile milestones (a sale, a purchase, an invite).
function TelemetryService.event(player: Player, eventName: string, value: number, field: string)
	local session = sessions[player]
	local origin = if session then session.origin else "ninguno"
	call(function()
		AnalyticsService:LogCustomEvent(player, eventName, value, fields(field, "Origen - " .. origin))
	end)
end

local function logSteps(player: Player, session: Session, upTo: number)
	for index = session.step + 1, upTo do
		local name = AnalyticsPlan.Onboarding[index].name
		call(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, index, name, fields("Origen - " .. session.origin))
		end)
	end
	session.step = math.max(session.step, upTo)
end

local function update(player: Player)
	local session = sessions[player]
	local profile = PlayerDataService.get(player)
	if not session or not profile then
		return
	end
	logSteps(player, session, AnalyticsPlan.onboardingStep(profile))
	local current = AnalyticsPlan.milestones(profile)
	for _, milestone in AnalyticsPlan.newMilestones(session.milestones, current) do
		call(function()
			AnalyticsService:LogCustomEvent(
				player,
				milestone.event,
				milestone.value,
				fields(milestone.field, "Origen - " .. session.origin)
			)
		end)
	end
	session.milestones = current
end

function TelemetryService.start()
	PlayerDataService.onLoaded(function(player, profile)
		local origin = "ninguno"
		local ok, joinData = pcall(function()
			return player:GetJoinData()
		end)
		if ok and type(joinData) == "table" then
			origin = AnalyticsPlan.origin((joinData :: any).LaunchData)
		end
		local session: Session = {
			step = AnalyticsPlan.onboardingStep(profile),
			milestones = AnalyticsPlan.milestones(profile),
			origin = origin,
		}
		sessions[player] = session
		-- step 1 on every join: Roblox counts it once per player, and it starts the funnel for new ones
		if session.step >= 1 then
			call(function()
				AnalyticsService:LogOnboardingFunnelStepEvent(
					player,
					1,
					AnalyticsPlan.Onboarding[1].name,
					fields("Origen - " .. origin)
				)
			end)
		end
		TelemetryService.event(player, "Sesion", 1, "Tipo - " .. (if session.step <= 1 then "nuevo" else "vuelve"))
	end)
	StateService.beforePush(update)
	-- Invites are sent by Roblox's own prompt on the client; the count is only used for analytics,
	-- so it is clamped and rate-limited and never grants anything.
	local inviteLimiter = RateLimiter.new(0.2, 2)
	Remotes.event("InviteSent").OnServerEvent:Connect(function(player, count)
		if type(count) ~= "number" or count ~= count or not inviteLimiter:allow(player) then
			return
		end
		local friends = math.clamp(math.floor(count), 1, 50)
		TelemetryService.event(player, "Invitacion", friends, "Tipo - amigos")
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		inviteLimiter:forget(player)
	end)
end

return TelemetryService

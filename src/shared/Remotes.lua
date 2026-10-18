--!strict
-- Single source of truth for network endpoints. The server creates them, clients wait for them.
--
-- Client -> Server
--   Dig(targetPosition: Vector3)                   request one hit at a world position
--   ReturnToSurface()                               teleport back to the plot surface
--   Sell()                                          sell the backpack (must be near the sell station)
--   SaveSettings({ effects?, shake?, tutorialDone? })  player preferences (validated, saved)
--   GearLamp(on)                                   toggle the powerful lamp (drains the battery)
--   GearPulse() -> { ok, found, kind, band, direction, message }   resonance detector pulse
--   GearHook(target: Vector3) -> { ok, point, normal, message }      grappling hook check
--   SellItem(resourceId)                            sell one kept piece (relic), near the sell station
--   Shop(action: string, id: string) -> result      RemoteFunction: "buyTool" | "equipTool" | "buyUpgrade"
--   GetState() -> snapshot                          RemoteFunction: initial state
-- Server -> Client
--   State(snapshot)                                 full state after any change
--   DigFx(player, position, resourceId, broke, toolId?, highlightId?)  hit feedback for nearby players
--   Collected(resourceId, amount, isNew)            item pickup popup
--   Notify(kind: string, text: string)              toast message
--   ZoneEntered(zoneId: string, firstTime: boolean)
--   SpecialFx(player, position, kind, resourceId?)  geode / fossil / chest / cave moments
--   CounterSequence(model, count)                 play the Counter's reveal sequence
--   FossilFound(speciesId, isNew, depth)          show the fossil card after an extraction
--   ShowNote(noteId: string)                       open a story note (after server validation)
--   LiftRide(seconds)                              fade out/in while the lift or beacon moves you
--   RescueState(state, info)                       "channel" (seconds) | "cancelled" (reason) | "done"
-- Mobility (Client -> Server)
--   PlaceRope() / InstallStation() / RescueStart() / RescueCancel()
--   RescueQuote() -> Quote?                        RemoteFunction: beacon price at the current spot
--   LiftTravel(destination) -> { ok, message }     RemoteFunction: "surface" or an owned station id

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
	"Dig",
	"ReturnToSurface",
	"Sell",
	"State",
	"DigFx",
	"Collected",
	"Notify",
	"ZoneEntered",
	"ShowNote",
	"SpecialFx",
	"FossilFound",
	"CounterSequence",
	"PlaceRope",
	"InstallStation",
	"RescueStart",
	"RescueCancel",
	"LiftRide",
	"RescueState",
	"SellItem",
	"SaveSettings",
	"GearLamp",
}
local FUNCTIONS = { "Shop", "GetState", "RescueQuote", "LiftTravel", "GearPulse", "GearHook" }

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for _, name in EVENTS do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		for _, name in FUNCTIONS do
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes

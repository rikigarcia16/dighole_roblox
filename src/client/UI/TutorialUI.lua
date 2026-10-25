--!strict
-- First-minutes hints (Util/TutorialLogic): one short line above the buttons and, when the step is
-- about a place, a marker over it ("CAVA AQUÍ" over the hole, "VENDER" on the sell cart, "GARAJE" on
-- the shop counter). When
-- the player passes the tutorial depth it is marked done in the settings and never shows again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TutorialLogic = require(ReplicatedStorage.Shared.Util.TutorialLogic)
local Build = require(script.Parent.Build)
local Theme = require(script.Parent.Theme)

local TutorialUI = {}

local player = Players.LocalPlayer
local TARGET_ACTION = { sell = "Sell", shop = "Shop", dig = "DigMarker" }
local TARGET_TEXT = { sell = "▼ VENDER", shop = "▼ GARAJE", dig = "▼ CAVA AQUÍ" }

-- The prompt part of an action inside the local player's own plot folder ("DigMarker": the part of
-- that name at the centre of the hole).
local function targetPart(action: string): BasePart?
	local world = workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	for _, folder in world:GetChildren() do
		if folder:GetAttribute("Owner") == player.UserId then
			if action == "DigMarker" then
				return folder:FindFirstChild("DigMarker", true) :: BasePart?
			end
			for _, d in folder:GetDescendants() do
				if
					d:IsA("ProximityPrompt")
					and d:GetAttribute("Action") == action
					and d.Parent
					and d.Parent:IsA("BasePart")
				then
					return d.Parent :: BasePart
				end
			end
		end
	end
	return nil
end

function TutorialUI.new(gui: ScreenGui)
	local hint = Build("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(520, 46),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
		[Build.Children] = { Build.corner(12), Build.stroke(Theme.accent, 2), Build.padding(8) },
	})
	local label = Build.label({
		Text = "",
		Font = Theme.bodyFont,
		TextWrapped = true,
		MaxTextSize = 18,
		Parent = hint,
	})

	local marker = Instance.new("BillboardGui")
	marker.Name = "THNE_TutorialMarker"
	marker.AlwaysOnTop = true
	marker.Size = UDim2.fromOffset(190, 46)
	marker.StudsOffset = Vector3.new(0, 6, 0)
	marker.Enabled = false
	local markerLabel = Build.label({
		Text = "",
		TextColor3 = Theme.accent,
		MaxTextSize = 30,
		Parent = marker,
	})
	Build.textStroke().Parent = markerLabel
	marker.Parent = player:WaitForChild("PlayerGui")

	local currentId: string? = nil
	local savedDone = false
	local bob: Tween? = nil
	local retrying = false
	local latest: any = nil

	local api = {}
	function api.update(state: any)
		latest = state
		local step = TutorialLogic.step(state, UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		if not step then
			hint.Visible = false
			marker.Enabled = false
			-- finished by playing (not just "nothing to show yet"): remember it
			if
				not savedDone
				and state
				and (state.maxDepth or 0) >= TutorialLogic.FinishDepth
				and not (state.settings and state.settings.tutorialDone)
			then
				savedDone = true
				Remotes.event("SaveSettings"):FireServer({ tutorialDone = true })
			end
			currentId = nil
			return
		end
		if step.id ~= currentId then
			currentId = step.id
			label.Text = step.text
			hint.Visible = true
			hint.BackgroundTransparency = 1
			TweenService:Create(hint, TweenInfo.new(0.4), { BackgroundTransparency = 0.15 }):Play()
		end
		local target = step.target and TARGET_ACTION[step.target]
		local part = target and targetPart(target)
		marker.Adornee = part
		marker.Enabled = part ~= nil
		-- the plot may not be assigned or streamed in yet: look again shortly
		if target and not part and not retrying then
			retrying = true
			task.delay(1, function()
				retrying = false
				api.update(latest)
			end)
		end
		if part and step.target then
			markerLabel.Text = TARGET_TEXT[step.target]
			if not bob then
				local tween = TweenService:Create(
					marker,
					TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ StudsOffset = Vector3.new(0, 7.2, 0) }
				)
				tween:Play()
				bob = tween
			end
		end
	end
	return api
end

return TutorialUI

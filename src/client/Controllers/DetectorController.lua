--!strict
-- "Metal detector" feedback: story landmarks the player has not read yet glow through the rock
-- when the player gets close, and revealed chests get a golden outline so they stand out in dark
-- caves. Purely visual; the server still validates every interaction.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ClientState = require(script.Parent.ClientState)

local DetectorController = {}

local player = Players.LocalPlayer
local LANDMARK_RANGE = 30
local CHEST_RANGE = 40

local highlights: { [Model]: Highlight } = {}

local function setHighlight(model: Model, enabled: boolean, color: Color3, throughWalls: boolean)
	local existing = highlights[model]
	if not enabled then
		if existing then
			existing:Destroy()
			highlights[model] = nil
		end
		return
	end
	if existing then
		return
	end
	local h = Instance.new("Highlight")
	h.Adornee = model
	h.FillTransparency = 1
	h.OutlineColor = color
	h.OutlineTransparency = 0.1
	h.DepthMode = if throughWalls then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
	h.Parent = model
	highlights[model] = h
end

function DetectorController.start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local clues = ClientState.data and ClientState.data.clues or {}
			for model, h in highlights do
				if not model.Parent then
					h:Destroy()
					highlights[model] = nil
				end
			end
			if root then
				for _, instance in CollectionService:GetTagged("THNE_Landmark") do
					if instance:IsA("Model") then
						local noteId = instance:GetAttribute("NoteId")
						local near = (instance:GetPivot().Position - root.Position).Magnitude <= LANDMARK_RANGE
						setHighlight(instance, near and not clues[noteId], Color3.fromRGB(120, 230, 255), true)
					end
				end
				for tag, color in
					{ THNE_Chest = Color3.fromRGB(255, 205, 60), THNE_Geode = Color3.fromRGB(190, 140, 255) }
				do
					for _, instance in CollectionService:GetTagged(tag) do
						if instance:IsA("Model") then
							local visible = instance:GetAttribute("Revealed") == true
								and instance:GetAttribute("Opened") ~= true
							local near = (instance:GetPivot().Position - root.Position).Magnitude <= CHEST_RANGE
							setHighlight(instance, visible and near, color, false)
						end
					end
				end
			end
		end
	end)
end

return DetectorController

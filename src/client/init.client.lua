--!strict
-- Client bootstrap.

local Controllers = script:WaitForChild("Controllers")

local order = {
	"ClientState",
	"EffectsController",
	"AmbienceController",
	"AmbientLifeController",
	"DigController",
	"DetectorController",
	"CounterController",
	"UIController",
	"SoundTestController",
}

for _, name in order do
	local controller = require(Controllers:WaitForChild(name)) :: any
	if controller.start then
		local ok, err = pcall(controller.start)
		if not ok then
			warn("[Client] failed to start " .. name .. ": " .. tostring(err))
		end
	end
end

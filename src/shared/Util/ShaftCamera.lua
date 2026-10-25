--!strict
-- Camera inside narrow shafts (pure; CameraController feeds it raycasts, tests check it offline).
-- In a one-cell shaft the default camera sits behind the character, inside or against the walls,
-- and below a few metres the picture became unreadable (Studio playtest). There the camera rises
-- above the character and looks down the shaft, with a small tilt so "forward" keeps its meaning.

local ShaftCamera = {}

ShaftCamera.SideRays = 8
ShaftCamera.SideReach = 6 -- studs: a one or two cell shaft (4-8 studs wide) has walls this close
ShaftCamera.MinSideHits = 6 -- walls on nearly every side
ShaftCamera.MinOpenAbove = 10 -- studs of open space above: a tunnel with a low roof is not a shaft
ShaftCamera.MinDepth = 6 -- studs of the head below the surface: a dent in the lawn is not a shaft
ShaftCamera.MaxHeight = 16 -- studs above the character's head at most
ShaftCamera.CeilingMargin = 1.5
ShaftCamera.Tilt = 0.12 -- horizontal offset per stud of height (keeps the view upright, stays in the shaft)
ShaftCamera.EnterSeconds = 0.25
ShaftCamera.ExitSeconds = 0.6

-- Unit horizontal directions of the side rays.
function ShaftCamera.directions(): { Vector3 }
	local list = {}
	for i = 0, ShaftCamera.SideRays - 1 do
		local a = i / ShaftCamera.SideRays * math.pi * 2
		table.insert(list, Vector3.new(math.cos(a), 0, math.sin(a)))
	end
	return list
end

-- `sideHits`: side rays that met a wall within SideReach; `openAbove`: studs of free space above
-- the head (math.huge when nothing); `depth`: studs of the head below the surface.
function ShaftCamera.inShaft(sideHits: number, openAbove: number, depth: number): boolean
	return depth >= ShaftCamera.MinDepth
		and sideHits >= ShaftCamera.MinSideHits
		and openAbove >= ShaftCamera.MinOpenAbove
end

-- Wedged: in a one-cell shaft the rounded terrain walls can hold the character up over an open
-- drop (Studio playtest: stuck 24 studs above the floor, out of the shovel's reach). True when the
-- character is still, held up, in a shaft, and the floor straight below is far.
ShaftCamera.WedgeSeconds = 0.5
ShaftCamera.WedgeFloor = 6 -- studs from the root to the floor below: standing is ~3
ShaftCamera.WedgeSpeed = 1 -- studs/s: below this the character counts as still

function ShaftCamera.wedged(inShaft: boolean, speed: number, floorDistance: number, climbing: boolean): boolean
	return inShaft and not climbing and speed < ShaftCamera.WedgeSpeed and floorDistance > ShaftCamera.WedgeFloor
end

-- Hysteresis: the state only flips after the condition held for a while, so the camera does not
-- jump while the player walks along the edge of a shaft. Returns the new state and timer.
function ShaftCamera.step(active: boolean, wanted: boolean, timer: number, dt: number): (boolean, number)
	if wanted == active then
		return active, 0
	end
	timer += dt
	local needed = if wanted then ShaftCamera.EnterSeconds else ShaftCamera.ExitSeconds
	if timer >= needed then
		return wanted, 0
	end
	return active, timer
end

-- Where the camera goes: above the head, below any ceiling, pulled back a little against `forward`
-- (horizontal unit vector) and looking at the character's feet.
function ShaftCamera.target(head: Vector3, forward: Vector3, openAbove: number): CFrame
	local height = math.clamp(openAbove - ShaftCamera.CeilingMargin, 3, ShaftCamera.MaxHeight)
	local eye = head + Vector3.new(0, height, 0) - forward * (height * ShaftCamera.Tilt)
	local feet = head - Vector3.new(0, 4, 0)
	return CFrame.lookAt(eye, feet)
end

return ShaftCamera

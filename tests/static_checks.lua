-- Static consistency checks over the source tree (run: luaucheck run tests/static_checks.lua).
-- They catch mistakes that compile fine but break at runtime in Roblox.
local failures = 0
local function fail(message)
	failures += 1
	print("  FAIL " .. message)
end

local remotesSource = readfile("src/shared/Remotes.lua")
local declared = {}
for block in remotesSource:gmatch("local EVENTS = (%b{})") do
	for name in block:gmatch('"([%w_]+)"') do declared["event:" .. name] = true end
end
for block in remotesSource:gmatch("local FUNCTIONS = (%b{})") do
	for name in block:gmatch('"([%w_]+)"') do declared["func:" .. name] = true end
end

local sounds = readfile("src/shared/Config/Sounds.lua")
local checked = 0
for _, path in listfiles("src") do
	if path:sub(-4) == ".lua" then
		local source = readfile(path)
		for kind, name in source:gmatch('Remotes%.(%a+)%("([%w_]+)"%)') do
			checked += 1
			if not declared[kind .. ":" .. name] then
				fail(string.format("%s uses Remotes.%s(%q) which is not declared in Remotes.lua", path, kind, name))
			end
		end
		-- ProximityPrompt actions handled by the server must be set somewhere
		for key in source:gmatch('playAt%("([%w_]+)"') do
			if not sounds:find("\n\t" .. key .. " =", 1, true) then
				fail(path .. " plays unknown sound " .. key)
			end
		end
		for key in source:gmatch('playUi%("([%w_]+)"') do
			if not sounds:find("\n\t" .. key .. " =", 1, true) then
				fail(path .. " plays unknown UI sound " .. key)
			end
		end
	end
end
print(string.format("static checks: %d remote uses verified, %d failures", checked, failures))
if failures > 0 then error("static checks failed", 0) end

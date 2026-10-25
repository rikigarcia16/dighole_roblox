-- Runs the offline tests with Lune (https://github.com/lune-org/lune) instead of the luaucheck
-- binary, which needs Rust to build. Same globals as tools/luaucheck/src/main.rs:
--   loadfile(path), loadwrapped(path, header), readfile(path), listfiles(dir)
--
--   lune run tools/lune/run.luau run tests/run.lua
--   lune run tools/lune/run.luau check src/shared/Config/Feats.lua ...

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local args = process.args
local mode = args[1] or "check"

local env = {}
setmetatable(env, { __index = getfenv(1) })

local function compile(source: string, name: string)
	return luau.load(source, { debugName = name, environment = env })
end

env.loadfile = function(path: string)
	return compile(fs.readFile(path), path)
end

env.loadwrapped = function(path: string, header: string)
	return compile(header .. " " .. fs.readFile(path), path)
end

env.readfile = function(path: string): string
	return fs.readFile(path)
end

env.listfiles = function(dir: string): { string }
	local out = {}
	local function walk(d: string)
		local names = fs.readDir(d)
		table.sort(names)
		for _, name in names do
			local p = d .. "/" .. name
			if fs.isDir(p) then
				walk(p)
			else
				table.insert(out, p)
			end
		end
	end
	walk(dir)
	return out
end

local failed = false
if mode == "check" then
	for i = 2, #args do
		local ok, err = pcall(luau.compile, fs.readFile(args[i]))
		if not ok then
			failed = true
			print("SYNTAX " .. args[i] .. ": " .. tostring(err))
		end
	end
elseif mode == "run" then
	local path = args[2]
	local ok, err = pcall(function()
		compile(fs.readFile(path), path)()
	end)
	if not ok then
		failed = true
		print("ERROR: " .. tostring(err))
	end
end
process.exit(if failed then 1 else 0)

-- Minimal Roblox environment shim so pure modules can be unit-tested outside Studio.
-- Run with a Luau runtime that exposes `loadfile(path) -> function` (see tests/README.md).

local H = {}

-- Value types ------------------------------------------------------------------------------
local Vector3 = {}
Vector3.__index = Vector3
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vector3.__tostring = function(v)
	return string.format("(%g, %g, %g)", v.X, v.Y, v.Z)
end

local Color3 = {}
function Color3.fromRGB(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255 }
end
function Color3.new(r, g, b)
	return { R = r, G = g, B = b }
end

local function enumProxy(prefix)
	return setmetatable({}, {
		__index = function(t, k)
			local v = prefix .. "." .. k
			rawset(t, k, v)
			return v
		end,
	})
end
local Enum = setmetatable({}, {
	__index = function(t, k)
		local v = enumProxy("Enum." .. k)
		rawset(t, k, v)
		return v
	end,
})

-- Virtual instance tree backed by the filesystem -------------------------------------------
local moduleCache = {}
local Node = {}

local function tryLoad(path)
	local ok, fn = pcall(loadfile, path)
	if ok then
		return fn
	end
	if
		not tostring(fn):find("No such file")
		and not tostring(fn):find("cannot find")
		and not tostring(fn):find("os error 2")
	then
		error(fn, 0)
	end
	return nil
end

local function makeNode(path, name, parent)
	local node = { __path = path, __name = name, __parent = parent, __children = {} }
	return setmetatable(node, Node)
end

Node.__index = function(self, key)
	if key == "Parent" then
		return rawget(self, "__parent")
	end
	if key == "Name" then
		return rawget(self, "__name")
	end
	if key == "WaitForChild" or key == "FindFirstChild" then
		return function(this, childName)
			return this[childName]
		end
	end
	local children = rawget(self, "__children")
	local child = children[key]
	if not child then
		child = makeNode(rawget(self, "__path") .. "/" .. key, key, self)
		children[key] = child
	end
	return child
end

-- Injected names become locals of the module (see `loadwrapped` in tools/luaucheck), not a
-- setfenv environment: setfenv would disable Luau's fast paths and distort benchmarks.
local HEADER = "local script, require, game, Vector3, Color3, Enum, workspace, Region3, CFrame, task, Random = ...;"

local function tryLoadWrapped(path)
	local ok, fn = pcall(loadwrapped, path, HEADER)
	if ok then
		return fn
	end
	local message = tostring(fn)
	if not message:find("os error 2") then
		error(fn, 0)
	end
	return nil
end

local function requireNode(node)
	local path = rawget(node, "__path")
	if moduleCache[path] ~= nil then
		return moduleCache[path]
	end
	local fn = tryLoadWrapped(path .. ".lua") or tryLoadWrapped(path .. "/init.lua")
	assert(fn, "module not found: " .. path)
	local g = H.globals
	local result =
		fn(node, requireNode, H.game, Vector3, Color3, Enum, g.workspace, g.Region3, g.CFrame, g.task, g.Random)
	moduleCache[path] = result
	return result
end

local services = {}
local game = {}
function game:GetService(name)
	local s = services[name]
	assert(s, "service not mocked: " .. name)
	return s
end
H.game = game

function H.mount(serviceName, childName, path)
	local service = services[serviceName]
	if not service then
		service = makeNode("<" .. serviceName .. ">", serviceName, nil)
		services[serviceName] = service
	end
	local children = rawget(service, "__children")
	children[childName] = makeNode(path, childName, service)
end

H.globals = {}
H.require = requireNode
H.Vector3 = Vector3
H.Color3 = Color3
H.Enum = Enum

function H.module(serviceName, ...)
	local node = game:GetService(serviceName)
	for _, part in { ... } do
		node = node[part]
	end
	return requireNode(node)
end

-- Tiny test framework ------------------------------------------------------------------------
local passed, failed = 0, 0
function H.test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

function H.eq(actual, expected, message)
	if actual ~= expected then
		error(
			string.format("%s: expected %s, got %s", message or "values differ", tostring(expected), tostring(actual)),
			2
		)
	end
end

function H.ok(cond, message)
	if not cond then
		error(message or "assertion failed", 2)
	end
end

function H.finish()
	print(string.format("\n%d passed, %d failed", passed, failed))
	if failed > 0 then
		error("tests failed", 0)
	end
end

return H

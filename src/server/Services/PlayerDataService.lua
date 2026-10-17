--!strict
-- Loads and saves player profiles through DataStoreService.
--
-- Robustness measures:
--   * Session lock stored next to the data ({ data, lock = { jobId, time } }). A server only writes
--     a record it holds the lock for, so two servers can never overwrite each other's progress.
--   * Locks are refreshed on every autosave; a lock older than SessionLockTimeout is treated as
--     abandoned (crashed server) and may be taken over.
--   * Every DataStore call is retried with backoff. If the DataStore is unavailable (e.g. Studio
--     without API access) the player still plays on a temporary profile that is never written,
--     so a failed load can never overwrite real data with an empty profile.
--   * Profiles are versioned and reconciled (see Logic/ProfileSchema) on load.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ProfileSchema = require(script.Parent.Parent.Logic.ProfileSchema)

type Profile = ProfileSchema.Profile

type Session = {
	player: Player,
	key: string,
	profile: Profile,
	canSave: boolean,
	saving: boolean,
	released: boolean,
}

local PlayerDataService = {}

local sessions: { [Player]: Session } = {}
local loading: { [Player]: boolean } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}
local beforeSaveCallbacks: { (Player, Profile) -> () } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore unavailable, progress will not be saved:", result)
	end
end

local function jobId(): string
	-- JobId is empty in Studio; give each Studio session a unique id anyway.
	if game.JobId ~= "" then
		return game.JobId
	end
	return "studio-" .. tostring(math.floor(os.clock() * 1000)) .. "-" .. tostring(math.random(1, 1e6))
end
local JOB_ID = jobId()

local function retry(attempts: number, fn: () -> ()): (boolean, any)
	local lastError
	for attempt = 1, attempts do
		local ok, err = pcall(fn)
		if ok then
			return true, nil
		end
		lastError = err
		warn(string.format("[PlayerData] attempt %d/%d failed: %s", attempt, attempts, tostring(lastError)))
		if attempt < attempts then
			task.wait(math.min(2 ^ attempt, 16))
		end
	end
	return false, lastError
end

local function newSeed(player: Player): number
	return (player.UserId * 7919 + math.random(1, 1e6)) % 2147483647
end

local function load(player: Player): Session?
	local key = "player_" .. player.UserId
	local fallback = ProfileSchema.default(newSeed(player))

	if not store or RunService:IsStudio() and player.UserId <= 0 then
		-- Test players in Studio (negative ids) never touch real data.
		return { player = player, key = key, profile = fallback, canSave = false, saving = false, released = false }
	end
	local dataStore = store :: DataStore

	for attempt = 1, GameConfig.LoadRetries do
		local lockedElsewhere = false
		local captured: any = nil
		local ok, err = retry(3, function()
			lockedElsewhere = false
			dataStore:UpdateAsync(key, function(record: any)
				record = type(record) == "table" and record or {}
				local lock = record.lock
				if
					type(lock) == "table"
					and lock.jobId ~= JOB_ID
					and type(lock.time) == "number"
					and os.time() - lock.time < GameConfig.SessionLockTimeout
				then
					lockedElsewhere = true
					return nil -- abort write, keep the other server's lock
				end
				record.lock = { jobId = JOB_ID, time = os.time() }
				captured = record
				return record
			end)
		end)

		if not ok then
			if not player.Parent then
				return nil
			end
			-- DataStore down or not enabled (Studio without API access). Play on a temporary
			-- profile that is never written, so the stored data stays untouched.
			warn("[PlayerData] could not load", player.Name, "- using a temporary profile:", err)
			return { player = player, key = key, profile = fallback, canSave = false, saving = false, released = false }
		end

		if not lockedElsewhere then
			-- Even if the player already left, return the session: onPlayerAdded releases the lock we
			-- just took instead of leaving it to expire (which would block a quick rejoin).
			local profile = ProfileSchema.reconcile(captured and captured.data, newSeed(player))
			return { player = player, key = key, profile = profile, canSave = true, saving = false, released = false }
		end

		if not player.Parent then
			return nil
		end
		-- Another server still holds the session (usually it is finishing its save). Wait and retry.
		task.wait(attempt * 3)
	end

	if player.Parent then
		player:Kick("No pudimos cargar tus datos de forma segura. Vuelve a entrar en unos segundos.")
	end
	return nil
end

local function save(session: Session, release: boolean): boolean
	if not session.canSave or not store then
		return false
	end
	for _, callback in beforeSaveCallbacks do
		local ok, err = pcall(callback, session.player, session.profile)
		if not ok then
			warn("[PlayerData] beforeSave callback failed:", err)
		end
	end
	local dataStore = store :: DataStore
	local profile = session.profile
	local ok, err = retry(3, function()
		dataStore:UpdateAsync(session.key, function(record: any)
			if not release and session.released then
				-- An autosave that reaches the store after the final save must not re-take the
				-- lock (the player would be locked out of other servers until it expires).
				return nil
			end
			record = type(record) == "table" and record or {}
			local lock = record.lock
			if type(lock) == "table" and lock.jobId ~= JOB_ID then
				-- We lost the session (it was taken over); never overwrite the newer owner.
				return nil
			end
			record.data = profile
			record.lock = if release then nil else { jobId = JOB_ID, time = os.time() }
			return record
		end)
	end)
	if not ok then
		warn("[PlayerData] save failed for", session.player.Name, err)
	end
	return ok
end

function PlayerDataService.get(player: Player): Profile?
	local session = sessions[player]
	return session and session.profile
end

function PlayerDataService.isPersistent(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.canSave
end

function PlayerDataService.onLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, session in sessions do
		task.spawn(callback, player, session.profile)
	end
end

-- Lets other services write runtime state (e.g. plot excavation) into the profile before saving.
function PlayerDataService.beforeSave(callback: (Player, Profile) -> ())
	table.insert(beforeSaveCallbacks, callback)
end

local function onPlayerAdded(player: Player)
	-- PlayerAdded and the initial GetPlayers() loop can both see the same player.
	if sessions[player] or loading[player] then
		return
	end
	loading[player] = true
	local session = load(player)
	loading[player] = nil
	if not session then
		return
	end
	if not player.Parent then
		-- Left while loading: release the lock we just took.
		save(session, true)
		return
	end
	sessions[player] = session
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, session.profile)
	end
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session or session.released then
		return
	end
	session.released = true
	save(session, true)
	sessions[player] = nil
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveSeconds)
			for _, session in sessions do
				if not session.released and not session.saving then
					session.saving = true
					task.spawn(function()
						save(session, false)
						session.saving = false
					end)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				onPlayerRemoving(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService

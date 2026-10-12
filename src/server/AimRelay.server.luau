-- Relays each player's dive aim pose to everyone else.
-- Validates types, distance and rate so a client can't spam or send garbage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MAX_EVENTS_PER_SECOND = 30
local MAX_AIM_DISTANCE = 1500

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemote(className: string, name: string)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local aimState = getOrCreateRemote("RemoteEvent", "AimState")
local aimUpdate = getOrCreateRemote("UnreliableRemoteEvent", "AimUpdate")

-- Token bucket per player per remote
local buckets = {}

local function allow(player: Player, key: string): boolean
	local now = os.clock()
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { tokens = MAX_EVENTS_PER_SECOND, last = now }
		playerBuckets[key] = bucket
	end
	bucket.tokens = math.min(MAX_EVENTS_PER_SECOND, bucket.tokens + (now - bucket.last) * MAX_EVENTS_PER_SECOND)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function isValidAimPoint(player: Player, point: any): boolean
	if typeof(point) ~= "Vector3" then
		return false
	end
	if point.X ~= point.X or point.Y ~= point.Y or point.Z ~= point.Z then
		return false -- NaN
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (point - root.Position).Magnitude <= MAX_AIM_DISTANCE
end

local function relay(remote, sender: Player, ...)
	for _, other in Players:GetPlayers() do
		if other ~= sender then
			remote:FireClient(other, sender, ...)
		end
	end
end

aimState.OnServerEvent:Connect(function(player, active, aimPoint)
	if typeof(active) ~= "boolean" or not allow(player, "state") then
		return
	end
	if aimPoint ~= nil and not isValidAimPoint(player, aimPoint) then
		aimPoint = nil
	end
	relay(aimState, player, active, aimPoint)
end)

aimUpdate.OnServerEvent:Connect(function(player, aimPoint)
	if not allow(player, "aim") or not isValidAimPoint(player, aimPoint) then
		return
	end
	relay(aimUpdate, player, aimPoint)
end)

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

-- Shares arm-aim poses between clients.
-- Body orientation replicates for free through physics, but IK only runs locally,
-- so each client sends its aim point while diving and poses everyone else's arms.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AimPose = require(script.Parent.AimPose)

local SEND_INTERVAL = 1 / 20
local STALE_AFTER = 1 -- seconds without updates before a remote pose is released

local AimReplicator = {}

local localPlayer = Players.LocalPlayer
local stateRemote: RemoteEvent? = nil
local aimRemote: UnreliableRemoteEvent? = nil

local localActive = false
local localAimPoint: Vector3? = nil
local sendTimer = 0

-- [Player] = { character, pose, active, lastUpdate }
local remoteEntries = {}

local function releaseEntry(player: Player)
	local entry = remoteEntries[player]
	if entry then
		entry.pose:Destroy()
		remoteEntries[player] = nil
	end
end

local function getEntry(player: Player)
	local character = player.Character
	local entry = remoteEntries[player]
	if entry and entry.character ~= character then
		releaseEntry(player)
		entry = nil
	end
	if not entry and character and character:FindFirstChildOfClass("Humanoid") then
		entry = {
			character = character,
			pose = AimPose.new(character),
			active = false,
			lastUpdate = os.clock(),
		}
		remoteEntries[player] = entry
	end
	return entry
end

local function onRemoteState(player: Player, active: boolean, aimPoint: Vector3?)
	if player == localPlayer then
		return
	end
	local entry = getEntry(player)
	if not entry then
		return
	end
	entry.active = active
	entry.lastUpdate = os.clock()
	if aimPoint then
		entry.pose:SetAimPoint(aimPoint)
	end
	entry.pose:SetActive(active)
end

local function onRemoteAim(player: Player, aimPoint: Vector3)
	if player == localPlayer then
		return
	end
	local entry = getEntry(player)
	if not entry or not entry.active then
		return
	end
	entry.lastUpdate = os.clock()
	entry.pose:SetAimPoint(aimPoint)
end

local function onHeartbeat(dt: number)
	if localActive and localAimPoint and aimRemote then
		sendTimer += dt
		if sendTimer >= SEND_INTERVAL then
			sendTimer = 0
			aimRemote:FireServer(localAimPoint)
		end
	end

	local now = os.clock()
	for _, entry in remoteEntries do
		if entry.active and now - entry.lastUpdate > STALE_AFTER then
			entry.active = false
			entry.pose:SetActive(false)
		end
	end
end

-- Called by the local dive controller when the aim pose turns on/off
function AimReplicator.SetLocalState(active: boolean, aimPoint: Vector3?)
	if aimPoint then
		localAimPoint = aimPoint
	end
	if active == localActive then
		return
	end
	localActive = active
	sendTimer = 0
	if stateRemote then
		stateRemote:FireServer(active, localAimPoint)
	end
end

function AimReplicator.SetLocalAimPoint(aimPoint: Vector3)
	localAimPoint = aimPoint
end

function AimReplicator.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	stateRemote = remotes:WaitForChild("AimState")
	aimRemote = remotes:WaitForChild("AimUpdate")

	stateRemote.OnClientEvent:Connect(onRemoteState)
	aimRemote.OnClientEvent:Connect(onRemoteAim)
	Players.PlayerRemoving:Connect(releaseEntry)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return AimReplicator

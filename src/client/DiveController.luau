-- The Max Payne shootdodge (no bullet time).
--
--   Idle --[dive key]--> Diving --[hit ground]--> Prone --[get-up key / timer]--> Recovering --> Idle
--
-- Diving: the humanoid is platform-stood, the body is launched along the move
-- direction with reduced gravity, and an AlignOrientation lays it horizontal:
-- head leading the dive, chest turned toward the crosshair, arms aimed by IK.
-- Prone: you land, roll onto your back and spin so your feet point at where
-- you're aiming, still able to shoot until you get up.
--
-- The client owns its character's physics, so all of this replicates to other
-- players automatically. Only the arm IK needs AimReplicator.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.MovementConfig)
local CameraController = require(script.Parent.CameraController)
local AimPose = require(script.Parent.AimPose)
local AimReplicator = require(script.Parent.AimReplicator)

local DiveConfig = Config.Dive
local ProneConfig = Config.Prone

local DIVE_ACTION = "Shootdodge"
local GET_UP_ACTION = "ShootdodgeGetUp"

local player = Players.LocalPlayer

local DiveController = {}

local state = "Idle" -- "Idle" | "Diving" | "Prone" | "Recovering"
local stateTime = 0
local cooldownEnds = 0

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local alignOrientation: AlignOrientation? = nil
local antiGravity: VectorForce? = nil
local aimPose = nil
local controls = nil

local diveDirection = Vector3.zAxis -- horizontal unit vector the body travels along
local proneHeadDirection = Vector3.zAxis
local proneRoll = 0 -- 0 = lying on your back, ±pi = face down

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true

--------------------------------------------------------------------------------
-- Math helpers
--------------------------------------------------------------------------------

local function flatten(vector: Vector3): Vector3?
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	return flat.Unit
end

local function headingOf(direction: Vector3): number
	return math.atan2(direction.X, direction.Z)
end

local function directionFromHeading(heading: number): Vector3
	return Vector3.new(math.sin(heading), 0, math.cos(heading))
end

local function wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

-- CFrame for a body lying horizontally: head pointing along `headDirection`,
-- chest facing `chestDirection` (both unit length and perpendicular).
local function lyingCFrame(position: Vector3, headDirection: Vector3, chestDirection: Vector3): CFrame
	return CFrame.fromMatrix(position, chestDirection:Cross(headDirection), headDirection)
end

-- Which way the chest faces mid-dive. Diving sideways, the chest turns toward the
-- aim; diving forward it faces the ground (superman); diving backward it faces the sky.
local function diveChestDirection(headDirection: Vector3, aimFlat: Vector3): Vector3
	local along = aimFlat:Dot(headDirection)
	return ((aimFlat - headDirection * along) - Vector3.yAxis * along).Unit
end

--------------------------------------------------------------------------------
-- Character helpers
--------------------------------------------------------------------------------

local function groundBelow(distance: number): RaycastResult?
	groundParams.FilterDescendantsInstances = { character }
	return workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), groundParams)
end

local function setAnimationsEnabled(enabled: boolean)
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("BaseScript") then
		animate.Enabled = enabled
	end
	if not enabled then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop(0.1)
			end
		end
	end
end

local function setControlsEnabled(enabled: boolean)
	if not controls then
		return
	end
	if enabled then
		controls:Enable()
	else
		controls:Disable()
	end
end

local function enterState(newState: string)
	state = newState
	stateTime = 0
end

local function updateAim()
	local aimPoint = CameraController.GetAimPoint()
	aimPose:SetAimPoint(aimPoint)
	AimReplicator.SetLocalAimPoint(aimPoint)
end

--------------------------------------------------------------------------------
-- State transitions
--------------------------------------------------------------------------------

local function resetToIdle()
	ContextActionService:UnbindAction(GET_UP_ACTION)
	if aimPose then
		aimPose:SetActive(false)
	end
	AimReplicator.SetLocalState(false)
	if alignOrientation then
		alignOrientation.Enabled = false
	end
	if antiGravity then
		antiGravity.Enabled = false
	end
	setControlsEnabled(true)
	CameraController.SetCharacterFacing(true)
	enterState("Idle")
end

local function canDive(): boolean
	if state ~= "Idle" or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if os.clock() < cooldownEnds then
		return false
	end
	local humanoidState = humanoid:GetState()
	if
		humanoidState == Enum.HumanoidStateType.Seated
		or humanoidState == Enum.HumanoidStateType.Swimming
		or humanoidState == Enum.HumanoidStateType.Climbing
		or humanoidState == Enum.HumanoidStateType.Dead
	then
		return false
	end
	if not DiveConfig.AllowAirDive and humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end
	return true
end

local function startDive()
	if not canDive() then
		return
	end

	local aimFlat = flatten(CameraController.GetLookVector()) or Vector3.zAxis
	-- Read the move direction before controls are disabled (that zeroes it)
	local direction = flatten(humanoid.MoveDirection)
	if not direction then
		direction = if DiveConfig.DefaultDirection == "Backward" then -aimFlat else aimFlat
	end
	diveDirection = direction

	setControlsEnabled(false)
	CameraController.SetCharacterFacing(false)
	setAnimationsEnabled(false)
	humanoid.PlatformStand = true

	root.AssemblyLinearVelocity = direction * DiveConfig.HorizontalSpeed
		+ Vector3.new(0, DiveConfig.LaunchUpSpeed, 0)
	root.AssemblyAngularVelocity = Vector3.zero

	antiGravity.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * (1 - DiveConfig.FloatGravity), 0)
	antiGravity.Enabled = true

	alignOrientation.CFrame = lyingCFrame(root.Position, direction, diveChestDirection(direction, aimFlat))
	alignOrientation.Enabled = true

	updateAim()
	aimPose:SetActive(true)
	AimReplicator.SetLocalState(true, CameraController.GetAimPoint())
	CameraController.Kick(Config.Camera.DiveFovKick)

	enterState("Diving")
end

local function getUp()
	if state ~= "Prone" then
		return
	end
	ContextActionService:UnbindAction(GET_UP_ACTION)
	alignOrientation.Enabled = false
	aimPose:SetActive(false)
	AimReplicator.SetLocalState(false)

	-- Stand the character upright on whatever is underneath it
	local position = root.Position
	local ground = groundBelow(4)
	local hipHeight = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local standY = (if ground then ground.Position.Y else position.Y) + hipHeight + root.Size.Y / 2

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.new(position.X, standY, position.Z) * CFrame.Angles(0, CameraController.GetYaw(), 0)

	humanoid.PlatformStand = false
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	setAnimationsEnabled(true)
	CameraController.SetCharacterFacing(true)

	enterState("Recovering")
end

local function land(aimFlat: Vector3)
	antiGravity.Enabled = false
	cooldownEnds = os.clock() + DiveConfig.Cooldown

	-- Carry the mid-air pose into the prone state so the roll starts from where we are
	proneHeadDirection = diveDirection
	local side = proneHeadDirection:Cross(Vector3.yAxis)
	local chest = diveChestDirection(diveDirection, aimFlat)
	proneRoll = math.atan2(chest:Dot(side), chest.Y)

	CameraController.Shake(Config.Camera.LandShake)

	ContextActionService:BindActionAtPriority(GET_UP_ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			getUp()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value + 1, table.unpack(ProneConfig.GetUpKeys))
	ContextActionService:SetTitle(GET_UP_ACTION, "Get Up")

	enterState("Prone")
end

--------------------------------------------------------------------------------
-- Per-frame update
--------------------------------------------------------------------------------

local function onHeartbeat(dt: number)
	if not root or not root.Parent or not humanoid or humanoid.Health <= 0 then
		return
	end
	stateTime += dt

	if state == "Idle" then
		return
	end

	if state == "Recovering" then
		if stateTime >= ProneConfig.GetUpRecovery then
			setControlsEnabled(true)
			enterState("Idle")
		end
		return
	end

	local aimFlat = flatten(CameraController.GetLookVector()) or diveDirection
	updateAim()

	if state == "Diving" then
		if stateTime >= DiveConfig.FloatTime then
			antiGravity.Enabled = false
		end

		alignOrientation.CFrame =
			lyingCFrame(root.Position, diveDirection, diveChestDirection(diveDirection, aimFlat))

		local velocity = root.AssemblyLinearVelocity
		local touchedDown = stateTime >= DiveConfig.MinAirTime
			and velocity.Y <= 0
			and groundBelow(DiveConfig.LandProbe) ~= nil
		local wedged = stateTime >= DiveConfig.MaxAirTime and velocity.Magnitude < 2
		if touchedDown or wedged then
			land(aimFlat)
		end
	elseif state == "Prone" then
		-- Spin on the ground so the feet point at the aim (limited turn speed)
		local heading = headingOf(proneHeadDirection)
		local turn = wrapAngle(headingOf(-aimFlat) - heading)
		local maxTurn = ProneConfig.TurnSpeed * dt
		proneHeadDirection = directionFromHeading(heading + math.clamp(turn, -maxTurn, maxTurn))

		-- Roll onto your back
		local maxRoll = ProneConfig.RollSpeed * dt
		proneRoll = wrapAngle(proneRoll)
		proneRoll = if math.abs(proneRoll) <= maxRoll then 0 else proneRoll - math.sign(proneRoll) * maxRoll

		local side = proneHeadDirection:Cross(Vector3.yAxis)
		local chest = Vector3.yAxis * math.cos(proneRoll) + side * math.sin(proneRoll)
		alignOrientation.CFrame = lyingCFrame(root.Position, proneHeadDirection, chest)

		if ProneConfig.AutoGetUpTime and stateTime >= ProneConfig.AutoGetUpTime then
			getUp()
		end
	end
end

--------------------------------------------------------------------------------
-- Character lifecycle
--------------------------------------------------------------------------------

local function cleanupCharacter()
	resetToIdle()
	if aimPose then
		aimPose:Destroy()
		aimPose = nil
	end
	character, humanoid, root = nil, nil, nil
	alignOrientation, antiGravity = nil, nil
end

local function onCharacterAdded(newCharacter: Model)
	cleanupCharacter()

	local newHumanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	local newRoot = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	if newHumanoid.RigType == Enum.HumanoidRigType.R15 then
		newCharacter:WaitForChild("RightHand", 5)
		newCharacter:WaitForChild("LeftHand", 5)
	end
	if player.Character ~= newCharacter then
		return -- respawned again while we were waiting
	end

	character, humanoid, root = newCharacter, newHumanoid, newRoot

	local attachment = Instance.new("Attachment")
	attachment.Name = "DiveAttachment"
	attachment.Parent = newRoot

	local align = Instance.new("AlignOrientation")
	align.Name = "DivePose"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = math.huge
	align.Responsiveness = DiveConfig.PoseResponsiveness
	align.Enabled = false
	align.Parent = newRoot
	alignOrientation = align

	local float = Instance.new("VectorForce")
	float.Name = "DiveFloat"
	float.Attachment0 = attachment
	float.RelativeTo = Enum.ActuatorRelativeTo.World
	float.ApplyAtCenterOfMass = true
	float.Enabled = false
	float.Parent = newRoot
	antiGravity = float

	aimPose = AimPose.new(newCharacter)

	newHumanoid.Died:Connect(function()
		if humanoid == newHumanoid then
			resetToIdle()
		end
	end)
end

function DiveController.GetState(): string
	return state
end

function DiveController.Start()
	local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	controls = playerModule:GetControls()

	ContextActionService:BindAction(DIVE_ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			startDive()
		end
		return Enum.ContextActionResult.Sink
	end, true, table.unpack(DiveConfig.Keys))
	ContextActionService:SetTitle(DIVE_ACTION, "Dive")

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	RunService.Heartbeat:Connect(onHeartbeat)
end

return DiveController

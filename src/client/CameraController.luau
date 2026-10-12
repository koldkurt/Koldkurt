-- Over-the-shoulder third-person camera.
-- Owns look input (mouse / right stick), keeps the character facing where the
-- camera looks, and exposes the aim ray other systems (dive, weapons) use.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.MovementConfig).Camera

local AIM_DISTANCE = 1000
local GAMEPAD_DEADZONE = 0.15

local player = Players.LocalPlayer
local gameSettings = UserSettings():GetService("UserGameSettings")

local CameraController = {}

local yaw = 0
local pitch = 0
local shoulderSide = 1 -- 1 = right shoulder, -1 = left shoulder
local currentSide = 1
local focus: Vector3? = nil
local fovOffset = 0
local shakeAmount = 0
local facingEnabled = true

local collisionParams = RaycastParams.new()
collisionParams.FilterType = Enum.RaycastFilterType.Exclude
collisionParams.RespectCanCollide = true

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function readGamepadLook(): Vector2
	if not UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
		return Vector2.zero
	end
	for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local stick = Vector2.new(input.Position.X, input.Position.Y)
			return if stick.Magnitude > GAMEPAD_DEADZONE then stick else Vector2.zero
		end
	end
	return Vector2.zero
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	local mouseDelta = UserInputService:GetMouseDelta()
	local mouseScale = Config.MouseSensitivity * gameSettings.MouseSensitivity
	local stick = readGamepadLook()
	yaw -= mouseDelta.X * mouseScale + stick.X * Config.GamepadSensitivity * dt
	pitch = math.clamp(
		pitch - mouseDelta.Y * mouseScale + stick.Y * Config.GamepadSensitivity * dt,
		Config.MinPitch,
		Config.MaxPitch
	)

	local root = getRoot()
	if not root then
		return
	end

	-- Shooter-style strafing: the body always faces the camera while upright
	if facingEnabled then
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
	end

	local targetFocus = root.Position + Vector3.new(0, Config.FocusHeight, 0)
	if focus == nil or (focus - targetFocus).Magnitude > 50 then
		focus = targetFocus
	else
		focus = focus:Lerp(targetFocus, 1 - math.exp(-Config.FollowSharpness * dt))
	end

	currentSide += (shoulderSide - currentSide) * (1 - math.exp(-Config.ShoulderSwapSpeed * dt))

	local rotation = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	local offset = rotation:VectorToWorldSpace(
		Vector3.new(Config.Offset.X * currentSide, Config.Offset.Y, Config.Offset.Z)
	)

	-- Pull the camera in if a wall is between it and the character
	collisionParams.FilterDescendantsInstances = { root.Parent }
	local hit = workspace:Spherecast(focus, Config.CollisionRadius, offset, collisionParams)
	if hit then
		offset = offset.Unit * hit.Distance
	end

	local shake = Vector3.zero
	if shakeAmount > 0.001 then
		shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shakeAmount
		shakeAmount *= math.exp(-10 * dt)
	end
	fovOffset *= math.exp(-6 * dt)

	camera.FieldOfView = Config.FieldOfView + fovOffset
	camera.CFrame = CFrame.new(focus + offset + shake) * rotation
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")
	humanoid.AutoRotate = false

	local look = root.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	pitch = 0
	focus = nil
	facingEnabled = true
end

function CameraController.GetYaw(): number
	return yaw
end

function CameraController.GetLookVector(): Vector3
	return CFrame.fromEulerAnglesYXZ(pitch, yaw, 0).LookVector
end

-- World point under the crosshair
function CameraController.GetAimPoint(): Vector3
	local cameraCFrame = workspace.CurrentCamera.CFrame
	local origin = cameraCFrame.Position
	local direction = cameraCFrame.LookVector * AIM_DISTANCE
	aimParams.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(origin, direction, aimParams)
	return if hit then hit.Position else origin + direction
end

-- When false, the camera stops rotating the character (the dive owns orientation)
function CameraController.SetCharacterFacing(enabled: boolean)
	facingEnabled = enabled
end

function CameraController.Kick(fov: number)
	fovOffset = math.max(fovOffset, fov)
end

function CameraController.Shake(amount: number)
	shakeAmount = math.max(shakeAmount, amount)
end

function CameraController.Start()
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	ContextActionService:BindAction("ShoulderSwap", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			shoulderSide = -shoulderSide
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(Config.ShoulderSwapKeys))

	RunService:BindToRenderStep("ShoulderCamera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController

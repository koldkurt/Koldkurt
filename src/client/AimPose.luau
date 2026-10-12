-- Points a character's arms at a world position using IKControl (dual-pistol style).
-- Used for the local player and for other players (driven by AimReplicator).
-- Requires an R15 rig; on anything else it quietly does nothing.

local TweenService = game:GetService("TweenService")

local ARMS = {
	{ chainRoot = "RightUpperArm", endEffector = "RightHand" },
	{ chainRoot = "LeftUpperArm", endEffector = "LeftHand" },
}

local BLEND_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local AimPose = {}
AimPose.__index = AimPose

function AimPose.new(character: Model)
	local self = setmetatable({
		_controls = {},
		_target = nil,
		_active = false,
	}, AimPose)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return self
	end

	-- A world-space attachment the arms reach toward
	local target = Instance.new("Attachment")
	target.Name = "AimPoseTarget"
	target.Parent = workspace.Terrain
	self._target = target

	for _, arm in ARMS do
		local chainRoot = character:FindFirstChild(arm.chainRoot)
		local endEffector = character:FindFirstChild(arm.endEffector)
		if chainRoot and endEffector then
			local ik = Instance.new("IKControl")
			ik.Name = "AimPose_" .. arm.endEffector
			ik.Type = Enum.IKControlType.Position
			ik.ChainRoot = chainRoot
			ik.EndEffector = endEffector
			ik.Target = target
			ik.SmoothTime = 0.05
			ik.Weight = 0
			ik.Parent = humanoid
			table.insert(self._controls, ik)
		end
	end

	return self
end

function AimPose:SetActive(active: boolean)
	if self._active == active then
		return
	end
	self._active = active
	for _, ik in self._controls do
		TweenService:Create(ik, BLEND_INFO, { Weight = if active then 1 else 0 }):Play()
	end
end

function AimPose:SetAimPoint(point: Vector3)
	if self._target then
		self._target.WorldPosition = point
	end
end

function AimPose:Destroy()
	for _, ik in self._controls do
		ik:Destroy()
	end
	table.clear(self._controls)
	if self._target then
		self._target:Destroy()
		self._target = nil
	end
end

return AimPose

-- All movement + camera tuning in one place.
-- Tweak these while playtesting; nothing here requires touching controller logic.

return {
	Dive = {
		-- Inputs that start a shootdodge
		Keys = { Enum.KeyCode.Q, Enum.KeyCode.ButtonX },

		HorizontalSpeed = 40, -- studs/s along the dive direction
		LaunchUpSpeed = 18, -- studs/s upward pop at take-off
		FloatGravity = 0.35, -- fraction of normal gravity during the float window (lower = floatier)
		FloatTime = 0.8, -- seconds of reduced gravity before full gravity returns
		MinAirTime = 0.2, -- ignore ground contact for this long after take-off
		MaxAirTime = 2.5, -- if still "diving" after this long and barely moving, force a landing (wedged on geometry)
		LandProbe = 1.6, -- studs below the root that count as touching the ground
		AllowAirDive = true, -- can you start a dive while already airborne?
		DefaultDirection = "Forward", -- direction when no movement keys are held: "Forward" or "Backward"
		Cooldown = 2.0, -- seconds after landing before you can dive again
		PoseResponsiveness = 30, -- how quickly the body snaps into the horizontal pose
	},

	Prone = {
		-- Inputs that stand you back up after landing
		GetUpKeys = { Enum.KeyCode.Space, Enum.KeyCode.Q, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonX },
		AutoGetUpTime = 3.0, -- stand up automatically after this long (set to nil to stay down until a key is pressed)
		TurnSpeed = math.rad(220), -- max spin speed (rad/s) while lying on the ground
		RollSpeed = math.rad(360), -- how fast you roll onto your back after landing (rad/s)
		GetUpRecovery = 0.35, -- seconds you can't move while standing back up
	},

	Camera = {
		Offset = Vector3.new(2.25, 1.75, 9), -- right, up, back from the focus point
		FocusHeight = 1.5, -- focus point height above the HumanoidRootPart
		FollowSharpness = 25, -- higher = camera follows the character more tightly
		MouseSensitivity = 0.0025, -- radians per pixel (scaled by the player's Roblox sensitivity setting)
		GamepadSensitivity = math.rad(240), -- radians/s at full right-stick deflection
		MinPitch = math.rad(-70),
		MaxPitch = math.rad(70),
		FieldOfView = 70,
		CollisionRadius = 0.4, -- keeps the camera from clipping into walls
		ShoulderSwapKeys = { Enum.KeyCode.V, Enum.KeyCode.ButtonR3 },
		ShoulderSwapSpeed = 10,
		DiveFovKick = 10, -- extra FOV punched in at take-off
		LandShake = 0.35, -- camera shake strength on landing
	},
}

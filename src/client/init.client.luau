-- Client entry point. Boots controllers in dependency order.

local CameraController = require(script.CameraController)
local AimReplicator = require(script.AimReplicator)
local DiveController = require(script.DiveController)
local Crosshair = require(script.Crosshair)

CameraController.Start()
Crosshair.Start()
AimReplicator.Start()
DiveController.Start()

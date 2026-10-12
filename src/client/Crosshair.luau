-- Minimal center-screen dot so you can see where the aim ray points.

local Players = game:GetService("Players")

local Crosshair = {}

function Crosshair.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Crosshair"
	gui.IgnoreGuiInset = true -- match the true viewport center the aim ray uses
	gui.ResetOnSpawn = false

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(5, 5)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BorderSizePixel = 0
	dot.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = dot

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return Crosshair

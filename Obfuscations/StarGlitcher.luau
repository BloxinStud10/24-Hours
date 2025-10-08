local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.ScreenInsets = 0

local TextLabel = Instance.new("TextLabel")
TextLabel.Size = UDim2.new(0.75, 0, 0.75, 0)
TextLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
TextLabel.Text = "This link has been changed, please use a new loadstring.\n24HRS Discord: https://discord.gg/bjTxKxjJVc"
TextLabel.TextColor3 = Color3.new(1, 1, 1)
TextLabel.TextScaled = true
TextLabel.AnchorPoint = Vector2.new(0.5, 0.5)
TextLabel.Font = "Code"
TextLabel.BackgroundTransparency = 1
TextLabel.Parent = ScreenGui

setclipboard("https://discord.gg/bjTxKxjJVc")
--Akira690, stealing wasnt an option.

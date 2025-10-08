local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.ScreenInsets = 0

local ImageLabel = Instance.new("ImageLabel")
ImageLabel.Size = UDim2.new(1, 0, 1, 0)
ImageLabel.Image = "rbxassetid://"..Image
ImageLabel.ScaleType = Enum.ScaleType.Fit
ImageLabel.BackgroundColor3 = Color3.new(0, 0, 0)
ImageLabel.Parent = ScreenGui

local TextLabel = Instance.new("TextLabel")
TextLabel.Size = UDim2.new(1, 0, 0.25, 0)
TextLabel.Text = "Holy skid!! if you are Akira690 reading this, fuck off"
TextLabel.TextColor3 = Color3.new(1, 1, 1)
TextLabel.TextScaled = true
TextLabel.Font = "Code"
TextLabel.BackgroundTransparency = 1
TextLabel.Parent = ScreenGui

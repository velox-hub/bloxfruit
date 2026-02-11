-- ==============================================================================
-- [ VELOX LITE - ESSENTIALS ONLY ]
-- Features: 1-4 (Toggle), Z-F, M1 (Tap), Dodge.
-- Removed: Jump, Soru, Haki, Bloat.
-- ==============================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- CONFIG
local Theme = {
    Bg = Color3.fromRGB(20, 20, 25),
    Accent = Color3.fromRGB(0, 255, 180),
    Text = Color3.fromRGB(240, 240, 240)
}

local WeaponData = {
    [1] = {tooltip = "Melee"}, [2] = {tooltip = "Blox Fruit"},
    [3] = {tooltip = "Sword"}, [4] = {tooltip = "Gun"}
}

-- ==============================================================================
-- [1] UTILITIES
-- ==============================================================================

local function FireUI(btn)
    if not btn then return end
    for _, c in pairs(getconnections(btn.Activated)) do c:Fire() end
    for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
    for _, c in pairs(getconnections(btn.InputBegan)) do 
        c:Fire({UserInputType=Enum.UserInputType.MouseButton1, UserInputState=Enum.UserInputState.Begin})
        task.wait()
        c:Fire({UserInputType=Enum.UserInputType.MouseButton1, UserInputState=Enum.UserInputState.End})
    end
end

local function MakeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = guiObject.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    guiObject.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ==============================================================================
-- [2] CORE LOGIC
-- ==============================================================================

-- 1-4 TOGGLE
local function ToggleEquip(slot)
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid"); if not hum then return end
    local target = WeaponData[slot].tooltip
    
    local current = char:FindFirstChildOfClass("Tool")
    if current and current.ToolTip == target then
        hum:UnequipTools()
    else
        for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
            if t:IsA("Tool") and t.ToolTip == target then hum:EquipTool(t); break end
        end
    end
end

-- SKILLS (Z-F)
local function TriggerSkill(key)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Skills = PGui and PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if Skills then
        for _, f in pairs(Skills:GetChildren()) do
            if f:IsA("Frame") and f.Visible and f:FindFirstChild(key) then
                FireUI(f[key]:FindFirstChild("Mobile") or f[key])
                return
            end
        end
    end
end

-- DODGE (Context Button)
local function TriggerDodge()
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Ctx = PGui and PGui:FindFirstChild("MobileContextButtons") and PGui.MobileContextButtons:FindFirstChild("ContextButtonFrame")
    if Ctx then
        for _, f in pairs(Ctx:GetChildren()) do
            if f.Name:find("BoundAction") and f.Name:find("Dodge") then
                FireUI(f:FindFirstChild("Button"))
                return
            end
        end
    end
end

-- M1 (Invisible Tap - ID 5)
local function TapM1()
    local v = Camera.ViewportSize
    VirtualInputManager:SendTouchEvent(5, 0, v.X/2, v.Y/2)
    task.wait(0.01)
    VirtualInputManager:SendTouchEvent(5, 2, v.X/2, v.Y/2)
end

-- ==============================================================================
-- [3] UI BUILDER
-- ==============================================================================

if CoreGui:FindFirstChild("VeloxLite") then CoreGui.VeloxLite:Destroy() end
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxLite"; ScreenGui.Parent = CoreGui

local function CreateBtn(text, func, size, color, pos)
    local btn = Instance.new("TextButton")
    btn.Size = size
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.2
    btn.Text = text
    btn.TextColor3 = Theme.Text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = ScreenGui
    
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = btn
    local stroke = Instance.new("UIStroke"); stroke.Color = Theme.Accent; stroke.Thickness = 1.5; stroke.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        btn.BackgroundColor3 = Theme.Accent; btn.TextColor3 = Color3.new(0,0,0); func()
        task.delay(0.1, function() btn.BackgroundColor3 = color; btn.TextColor3 = Theme.Text end)
    end)
    MakeDraggable(btn)
end

-- ==============================================================================
-- [4] LAYOUT
-- ==============================================================================

-- Weapons
CreateBtn("1", function() ToggleEquip(1) end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.65,0,0.45,0))
CreateBtn("2", function() ToggleEquip(2) end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.73,0,0.45,0))
CreateBtn("3", function() ToggleEquip(3) end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.81,0,0.45,0))
CreateBtn("4", function() ToggleEquip(4) end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.89,0,0.45,0))

-- Skills
CreateBtn("Z", function() TriggerSkill("Z") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.65,0,0.55,0))
CreateBtn("X", function() TriggerSkill("X") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.73,0,0.55,0))
CreateBtn("C", function() TriggerSkill("C") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.81,0,0.55,0))
CreateBtn("V", function() TriggerSkill("V") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.69,0,0.65,0))
CreateBtn("F", function() TriggerSkill("F") end, UDim2.new(0,45,0,45), Theme.Bg, UDim2.new(0.77,0,0.65,0))

-- Actions
CreateBtn("M1", TapM1, UDim2.new(0,60,0,60), Color3.fromRGB(200, 50, 50), UDim2.new(0.9,0,0.25,0))
CreateBtn("Dodge", TriggerDodge, UDim2.new(0,50,0,50), Theme.Bg, UDim2.new(0.89,0,0.55,0))

print("Velox Lite: Essential Loaded")

-- ==============================================================================
-- [ VELOX HYBRID EDITION ]
-- Jump & Dodge: V1.6 Method (UI Path Firing)
-- 1234, Z-F, M1: V2.3 Method (Toggle & Invisible Tap)
-- ==============================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- CONFIGURATION UI
local Theme = {
    Bg      = Color3.fromRGB(18, 18, 22),
    Sidebar = Color3.fromRGB(26, 26, 32),
    Accent  = Color3.fromRGB(0, 255, 170), -- Cyber Green
    Text    = Color3.fromRGB(245, 245, 245),
    Red     = Color3.fromRGB(255, 65, 65),
    Blue    = Color3.fromRGB(0, 150, 255),
    Stroke  = Color3.fromRGB(60, 60, 70),
}

-- VARIABLES
local ActiveVirtualKeys = {} 
local IsLayoutLocked = false

-- DATA SENJATA
local WeaponData = {
    [1] = {type = "Melee", tooltip = "Melee"},
    [2] = {type = "Fruit", tooltip = "Blox Fruit"},
    [3] = {type = "Sword", tooltip = "Sword"},
    [4] = {type = "Gun",   tooltip = "Gun"}
}

-- ==============================================================================
-- [1] UTILITY FUNCTIONS
-- ==============================================================================

local function createCorner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p end
local function createStroke(p, c) local s = Instance.new("UIStroke"); s.Color = c or Theme.Stroke; s.Thickness = 1.5; s.ApplyStrokeMode = "Border"; s.Parent = p; return s end

-- FUNGSI V1.6 (Untuk Jump & Dodge)
local function FireUIElementV1(btn)
    if not btn then return end
    for _, conn in pairs(getconnections(btn.Activated)) do conn:Fire() end
    for _, conn in pairs(getconnections(btn.MouseButton1Click)) do conn:Fire() end
    for _, conn in pairs(getconnections(btn.InputBegan)) do 
        conn:Fire({UserInputType = Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.Begin})
        task.wait()
        conn:Fire({UserInputType = Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.End})
    end
end

-- FUNGSI SILENT SKILL (Untuk Z-F)
local function FireSilentSkill(btn)
    if not btn then return end
    for _, c in pairs(getconnections(btn.Activated)) do c:Fire() end
    for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
end

local function MakeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not IsLayoutLocked then 
                dragging = true; dragStart = input.Position; startPos = guiObject.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
            end
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

-- [A] TOGGLE EQUIP (V2.3 Method)
local function EquipToggle(slotIdx)
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid"); if not hum then return end
    local info = WeaponData[slotIdx]
    
    local current = char:FindFirstChildOfClass("Tool")
    if current and current.ToolTip == info.tooltip then
        hum:UnequipTools()
    else
        local found = nil
        for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
            if t:IsA("Tool") and t.ToolTip == info.tooltip then found = t; break end
        end
        if found then hum:EquipTool(found) end
    end
end

-- [B] SKILLS Z-F (V2.3 Silent Method)
local function UseSkill(key)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Frame = PGui and PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if Frame then
        for _, tool in pairs(Frame:GetChildren()) do
            if tool:IsA("Frame") and tool.Visible then
                local kFrame = tool:FindFirstChild(key)
                if kFrame then FireSilentSkill(kFrame:FindFirstChild("Mobile") or kFrame) return end
            end
        end
    end
end

-- [C] JUMP (V1.6 Method - Path UI)
local function TriggerJump()
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local TouchGui = PGui and PGui:FindFirstChild("TouchGui")
    local JumpBtn = TouchGui and TouchGui:FindFirstChild("TouchControlFrame") and TouchGui.TouchControlFrame:FindFirstChild("JumpButton")
    if JumpBtn then
        FireUIElementV1(JumpBtn)
    end
end

-- [D] DODGE (V1.6 Method - Context Button)
local function TriggerDodge()
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local CtxFrame = PGui and PGui:FindFirstChild("MobileContextButtons") and PGui.MobileContextButtons:FindFirstChild("ContextButtonFrame")
    if CtxFrame then
        for _, frame in pairs(CtxFrame:GetChildren()) do
            if frame.Name:find("BoundAction") and frame.Name:find("Dodge") then
                FireUIElementV1(frame:FindFirstChild("Button"))
                return
            end
        end
    end
end

-- [E] M1 (V2.3 Invisible Tap Center)
local function TapM1()
    local viewport = Camera.ViewportSize
    local x, y = viewport.X / 2, viewport.Y / 2
    VirtualInputManager:SendTouchEvent(5, 0, x, y) -- ID 5 agar tidak ganggu Joystick
    task.wait(0.01)
    VirtualInputManager:SendTouchEvent(5, 2, x, y)
end

-- ==============================================================================
-- [3] UI CONSTRUCTION
-- ==============================================================================

if CoreGui:FindFirstChild("VeloxUI") then CoreGui.VeloxUI:Destroy() end
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxUI"; ScreenGui.Parent = CoreGui; ScreenGui.ResetOnSpawn = false

local function AddBtn(id, text, callback, size, color)
    local btn = Instance.new("TextButton")
    btn.Size = size or UDim2.new(0, 50, 0, 50)
    btn.BackgroundColor3 = color or Color3.fromRGB(0, 0, 0)
    btn.BackgroundTransparency = 0.2
    btn.Text = text
    btn.TextColor3 = Theme.Accent
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.Parent = ScreenGui
    createCorner(btn, 12); createStroke(btn, Theme.Accent)
    btn.MouseButton1Click:Connect(function()
        btn.BackgroundColor3 = Theme.Accent; btn.TextColor3 = Theme.Bg; callback()
        task.delay(0.1, function() btn.BackgroundColor3 = color or Color3.fromRGB(0,0,0); btn.TextColor3 = Theme.Accent end)
    end)
    MakeDraggable(btn); ActiveVirtualKeys[id] = {Button = btn}
    return btn
end

-- ==============================================================================
-- [4] FINAL LAYOUT
-- ==============================================================================

-- Weapons (1-4 Toggle)
AddBtn("1", "1", function() EquipToggle(1) end).Position = UDim2.new(0.6, 0, 0.45, 0)
AddBtn("2", "2", function() EquipToggle(2) end).Position = UDim2.new(0.7, 0, 0.45, 0)
AddBtn("3", "3", function() EquipToggle(3) end).Position = UDim2.new(0.8, 0, 0.45, 0)
AddBtn("4", "4", function() EquipToggle(4) end).Position = UDim2.new(0.9, 0, 0.45, 0)

-- Skills (Z-F Silent)
AddBtn("Z", "Z", function() UseSkill("Z") end).Position = UDim2.new(0.6, 0, 0.55, 0)
AddBtn("X", "X", function() UseSkill("X") end).Position = UDim2.new(0.7, 0, 0.55, 0)
AddBtn("C", "C", function() UseSkill("C") end).Position = UDim2.new(0.8, 0, 0.55, 0)
AddBtn("V", "V", function() UseSkill("V") end).Position = UDim2.new(0.65, 0, 0.65, 0)
AddBtn("F", "F", function() UseSkill("F") end).Position = UDim2.new(0.75, 0, 0.65, 0)

-- M1 Invisible Tap
local m1 = AddBtn("M1", "M1", TapM1, UDim2.new(0, 60, 0, 60), Theme.Red)
m1.Position = UDim2.new(0.9, 0, 0.25, 0)

-- Dodge & Jump (V1.6 Method)
AddBtn("Dodge", "DG", TriggerDodge).Position = UDim2.new(0.85, 0, 0.65, 0)
local jmp = AddBtn("Jump", "JP", TriggerJump, UDim2.new(0, 60, 0, 60), Theme.Blue)
jmp.Position = UDim2.new(0.9, 0, 0.7, 0)

print("Velox Hybrid Loaded: Stable Dodge & Jump")

-- ==============================================================================
-- [ VELOX V2.5 - DODGE & JUMP RECOVERY ]
-- Fix: Dodge & Jump kembali menggunakan TriggerContext & UI Path (Metode Awal)
-- Keep: 1-4, Z-F, dan M1 yang sudah stabil.
-- ==============================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- UI CONFIGURATION
local Theme = {
    Bg      = Color3.fromRGB(20, 20, 25),
    Sidebar = Color3.fromRGB(30, 30, 35),
    Accent  = Color3.fromRGB(0, 255, 180),
    Text    = Color3.fromRGB(240, 240, 240),
    Red     = Color3.fromRGB(255, 80, 80),
    Blue    = Color3.fromRGB(50, 150, 255),
    Stroke  = Color3.fromRGB(60, 60, 70)
}

-- VARIABLES
local ActiveVirtualKeys = {} 
local ScreenGui = nil

-- DATA SENJATA
local WeaponData = {
    [1] = {type = "Melee", tooltip = "Melee"},
    [2] = {type = "Fruit", tooltip = "Blox Fruit"},
    [3] = {type = "Sword", tooltip = "Sword"},
    [4] = {type = "Gun",   tooltip = "Gun"}
}

-- ==============================================================================
-- [1] UTILITY: FIRE UI (METODE AWAL)
-- ==============================================================================

local function FireUI(btn)
    if not btn then return end
    
    -- Memicu semua koneksi yang mungkin ada pada tombol UI mobile
    for _, c in pairs(getconnections(btn.Activated)) do c:Fire() end
    for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
    
    -- Simulasi input began/end untuk tombol yang butuh pressure (seperti Jump)
    for _, c in pairs(getconnections(btn.InputBegan)) do 
        c:Fire({UserInputType=Enum.UserInputType.Touch, UserInputState=Enum.UserInputState.Begin})
    end
    task.wait(0.05)
    for _, c in pairs(getconnections(btn.InputEnded)) do 
        c:Fire({UserInputType=Enum.UserInputType.Touch, UserInputState=Enum.UserInputState.End})
    end
end

-- ==============================================================================
-- [2] CORE LOGIC
-- ==============================================================================

-- [A] EQUIP TOGGLE (STABIL)
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

-- [B] SKILLS Z-F (STABIL)
local function UseSkill(key)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Frame = PGui and PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if Frame then
        for _, tool in pairs(Frame:GetChildren()) do
            if tool:IsA("Frame") and tool.Visible then
                local kFrame = tool:FindFirstChild(key)
                if kFrame then FireUI(kFrame:FindFirstChild("Mobile") or kFrame) return end
            end
        end
    end
end

-- [C] DODGE (METODE AWAL)
local function TriggerDodge()
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local CtxFrame = PGui and PGui:FindFirstChild("MobileContextButtons") and PGui.MobileContextButtons:FindFirstChild("ContextButtonFrame")
    if CtxFrame then
        for _, frame in pairs(CtxFrame:GetChildren()) do
            if frame.Name:find("BoundAction") and frame.Name:find("Dodge") then
                FireUI(frame:FindFirstChild("Button"))
                return
            end
        end
    end
end

-- [D] JUMP (METODE AWAL - UI PATH)
local function TriggerJumpUI()
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local TouchGui = PGui and PGui:FindFirstChild("TouchGui")
    local JumpBtn = TouchGui and TouchGui:FindFirstChild("TouchControlFrame") and TouchGui.TouchControlFrame:FindFirstChild("JumpButton")
    
    if JumpBtn then
        FireUI(JumpBtn)
    end
end

-- [E] M1 (INVISIBLE TAP STABIL)
local function TapM1()
    local viewport = Camera.ViewportSize
    local x, y = viewport.X / 2, viewport.Y / 2
    VirtualInputManager:SendTouchEvent(11, 0, x, y)
    task.wait(0.02)
    VirtualInputManager:SendTouchEvent(11, 2, x, y)
end

-- ==============================================================================
-- [3] UI CONSTRUCTION
-- ==============================================================================

local function createCorner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p end
local function createStroke(p, c) local s = Instance.new("UIStroke"); s.Color = c or Theme.Stroke; s.Thickness = 1.5; s.ApplyStrokeMode = "Border"; s.Parent = p end

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

if CoreGui:FindFirstChild("VeloxUI") then CoreGui.VeloxUI:Destroy() end
ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxUI"; ScreenGui.Parent = CoreGui; ScreenGui.ResetOnSpawn = false

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
    MakeDraggable(btn)
    return btn
end

-- ==============================================================================
-- [4] FINAL LAYOUT SETUP
-- ==============================================================================

-- Weapons
AddBtn("1", "1", function() EquipToggle(1) end).Position = UDim2.new(0.6, 0, 0.45, 0)
AddBtn("2", "2", function() EquipToggle(2) end).Position = UDim2.new(0.7, 0, 0.45, 0)
AddBtn("3", "3", function() EquipToggle(3) end).Position = UDim2.new(0.8, 0, 0.45, 0)
AddBtn("4", "4", function() EquipToggle(4) end).Position = UDim2.new(0.9, 0, 0.45, 0)

-- Skills
AddBtn("Z", "Z", function() UseSkill("Z") end).Position = UDim2.new(0.6, 0, 0.55, 0)
AddBtn("X", "X", function() UseSkill("X") end).Position = UDim2.new(0.7, 0, 0.55, 0)
AddBtn("C", "C", function() UseSkill("C") end).Position = UDim2.new(0.8, 0, 0.55, 0)
AddBtn("V", "V", function() UseSkill("V") end).Position = UDim2.new(0.65, 0, 0.65, 0)
AddBtn("F", "F", function() UseSkill("F") end).Position = UDim2.new(0.75, 0, 0.65, 0)

-- M1 (Top Thumb)
AddBtn("M1", "M1", TapM1, UDim2.new(0, 60, 0, 60), Theme.Red).Position = UDim2.new(0.9, 0, 0.25, 0)

-- Dodge & Jump (Metode UI Awal)
AddBtn("Dodge", "DG", TriggerDodge).Position = UDim2.new(0.85, 0, 0.65, 0)
AddBtn("Jump", "JP", TriggerJumpUI, UDim2.new(0, 60, 0, 60), Theme.Blue).Position = UDim2.new(0.9, 0, 0.7, 0)

print("Velox v2.5 Loaded: Dodge & Jump UI Fixed")

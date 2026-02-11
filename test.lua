-- ==============================================================================
-- [ VELOX V2.3 - MULTI-TOUCH FIX ]
-- Fix M1: Uses Virtual Touch Event (ID 5) at Center Screen (No Visuals, No Interrupt)
-- Fix Jump: Clicks exact UI Coordinates of JumpButton (Touch ID 6)
-- Fix Equip: Toggle Logic (1-4)
-- ==============================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local IsLayoutLocked = false

-- DATA SENJATA
local WeaponData = {
    [1] = {type = "Melee", tooltip = "Melee"},
    [2] = {type = "Fruit", tooltip = "Blox Fruit"},
    [3] = {type = "Sword", tooltip = "Sword"},
    [4] = {type = "Gun",   tooltip = "Gun"}
}

-- ==============================================================================
-- [1] UTILITY: VIRTUAL TOUCH (THE FIX)
-- ==============================================================================

-- Fungsi ini mensimulasikan sentuhan jari pada koordinat X, Y
-- touchID: Angka unik untuk membedakan jari (Joystick biasanya ID 0 atau 1)
-- Kita pakai ID 5 dan 6 agar tidak bentrok.
local function SimulateTouch(touchID, x, y)
    -- State: 0 = Begin (Tekan), 2 = End (Lepas)
    VirtualInputManager:SendTouchEvent(touchID, 0, x, y)
    task.wait(0.05)
    VirtualInputManager:SendTouchEvent(touchID, 2, x, y)
end

local function FireUI(btn)
    if not btn then return end
    for _, c in pairs(getconnections(btn.Activated)) do c:Fire() end
    for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
end

-- ==============================================================================
-- [2] CORE LOGIC
-- ==============================================================================

-- [A] M1 TAP CENTER (INVISIBLE TOUCH)
local function TapCenterScreen()
    local viewport = Camera.ViewportSize
    local x, y = viewport.X / 2, viewport.Y / 2
    
    -- Gunakan Touch ID 5 (Jari ke-5)
    -- Ini tidak akan mengganggu Joystick (Jari ke-1)
    SimulateTouch(5, x, y)
end

-- [B] JUMP VIA UI COORDINATES
local function TriggerJumpUI()
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PGui then return end
    
    local TouchGui = PGui:FindFirstChild("TouchGui")
    if TouchGui then
        local TouchControl = TouchGui:FindFirstChild("TouchControlFrame")
        if TouchControl then
            local JumpBtn = TouchControl:FindFirstChild("JumpButton")
            if JumpBtn and JumpBtn.Visible then
                -- Ambil Posisi Tombol di Layar
                local absPos = JumpBtn.AbsolutePosition
                local absSize = JumpBtn.AbsoluteSize
                
                -- Hitung titik tengah tombol
                local centerX = absPos.X + (absSize.X / 2)
                local centerY = absPos.Y + (absSize.Y / 2)
                
                -- Sentuh koordinat tombol tersebut dengan Touch ID 6
                SimulateTouch(6, centerX, centerY)
                return
            end
        end
    end
    
    -- Fallback jika UI tidak ketemu (misal main di PC mode tapi pakai script HP)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.Jump = true
    end
end

-- [C] EQUIP WEAPON (TOGGLE)
local function EquipWeapon(slotIdx)
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid"); if not hum then return end
    local targetInfo = WeaponData[slotIdx]; if not targetInfo then return end

    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool and currentTool.ToolTip == targetInfo.tooltip then
        hum:UnequipTools()
    else
        local foundTool = nil
        for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
            if t:IsA("Tool") and t.ToolTip == targetInfo.tooltip then foundTool = t; break end
        end
        if foundTool then hum:EquipTool(foundTool)
        else
            for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
                if t:IsA("Tool") and (t.Name == targetInfo.type or t.Name:find(targetInfo.type)) then hum:EquipTool(t); break end
            end
        end
    end
end

-- [D] SKILL & CONTEXT TRIGGERS
local function TriggerMainSkill(key)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local SkillsFrame = PGui and PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if SkillsFrame then
        for _, toolFrame in pairs(SkillsFrame:GetChildren()) do
            if toolFrame:IsA("Frame") and toolFrame.Visible then
                local keyFrame = toolFrame:FindFirstChild(key)
                if keyFrame then
                    FireUI(keyFrame:FindFirstChild("Mobile") or keyFrame)
                    return
                end
            end
        end
    end
end

local function TriggerContext(keyword)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local CtxFrame = PGui and PGui:FindFirstChild("MobileContextButtons") and PGui.MobileContextButtons:FindFirstChild("ContextButtonFrame")
    if CtxFrame then
        for _, frame in pairs(CtxFrame:GetChildren()) do
            if frame.Name:find("BoundAction") and frame.Name:find(keyword) then
                FireUI(frame:FindFirstChild("Button"))
                return
            end
        end
    end
end

-- ==============================================================================
-- [3] UI SYSTEM
-- ==============================================================================

local function createCorner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p end
local function createStroke(p, c) local s = Instance.new("UIStroke"); s.Color = c or Theme.Stroke; s.Thickness = 1.5; s.ApplyStrokeMode = "Border"; s.Parent = p end

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

if CoreGui:FindFirstChild("VeloxUI") then CoreGui.VeloxUI:Destroy() end
ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxUI"; ScreenGui.Parent = CoreGui; ScreenGui.ResetOnSpawn = false

-- TOGGLE BTN
local ToggleBtn = Instance.new("TextButton"); ToggleBtn.Size = UDim2.new(0, 45, 0, 45); ToggleBtn.Position = UDim2.new(0.02, 0, 0.3, 0); ToggleBtn.BackgroundColor3 = Theme.Sidebar; ToggleBtn.Text = "V"; ToggleBtn.TextColor3 = Theme.Accent; ToggleBtn.Parent = ScreenGui; createCorner(ToggleBtn, 12); createStroke(ToggleBtn, Theme.Accent)
local Vis = true
ToggleBtn.MouseButton1Click:Connect(function() Vis = not Vis; for _, v in pairs(ActiveVirtualKeys) do v.Button.Visible = Vis end end)
MakeDraggable(ToggleBtn)

local function AddBtn(id, text, callback, size, color)
    if ActiveVirtualKeys[id] then ActiveVirtualKeys[id].Button:Destroy() end
    local btn = Instance.new("TextButton")
    btn.Size = size or UDim2.new(0, 50, 0, 50)
    btn.Position = UDim2.new(0.5, 0, 0.5, 0)
    btn.BackgroundColor3 = color or Color3.fromRGB(0, 0, 0)
    btn.BackgroundTransparency = 0.2
    btn.Text = text
    btn.TextColor3 = Theme.Accent
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = ScreenGui
    createCorner(btn, 10); createStroke(btn, Theme.Accent)
    
    btn.MouseButton1Click:Connect(function()
        btn.BackgroundColor3 = Theme.Accent; btn.TextColor3 = Theme.Bg; callback()
        task.delay(0.1, function() btn.BackgroundColor3 = color or Color3.fromRGB(0,0,0); btn.TextColor3 = Theme.Accent end)
    end)
    
    MakeDraggable(btn)
    ActiveVirtualKeys[id] = {Button = btn}
    return btn
end

-- ==============================================================================
-- [4] BUTTON LAYOUT
-- ==============================================================================

-- [ROW 1] Weapons
AddBtn("1", "1", function() EquipWeapon(1) end).Position = UDim2.new(0.65, 0, 0.45, 0)
AddBtn("2", "2", function() EquipWeapon(2) end).Position = UDim2.new(0.75, 0, 0.45, 0)
AddBtn("3", "3", function() EquipWeapon(3) end).Position = UDim2.new(0.85, 0, 0.45, 0)
AddBtn("4", "4", function() EquipWeapon(4) end).Position = UDim2.new(0.95, 0, 0.45, 0)

-- [ROW 2] Skills
AddBtn("Z", "Z", function() TriggerMainSkill("Z") end).Position = UDim2.new(0.65, 0, 0.55, 0)
AddBtn("X", "X", function() TriggerMainSkill("X") end).Position = UDim2.new(0.75, 0, 0.55, 0)
AddBtn("C", "C", function() TriggerMainSkill("C") end).Position = UDim2.new(0.85, 0, 0.55, 0)
AddBtn("V", "V", function() TriggerMainSkill("V") end).Position = UDim2.new(0.70, 0, 0.65, 0)
AddBtn("F", "F", function() TriggerMainSkill("F") end).Position = UDim2.new(0.80, 0, 0.65, 0)

-- [ROW 3] Context
AddBtn("Ken", "KEN", function() TriggerContext("Ken") end).Position = UDim2.new(0.60, 0, 0.35, 0)
AddBtn("Race", "RACE", function() TriggerContext("RaceAbility") end).Position = UDim2.new(0.70, 0, 0.35, 0)
AddBtn("Dodge", "DODGE", function() TriggerContext("Dodge") end).Position = UDim2.new(0.80, 0, 0.35, 0)

-- [ROW 4] Actions
local bJump = AddBtn("Jump", "JUMP", TriggerJumpUI, UDim2.new(0, 60, 0, 60), Theme.Blue)
bJump.Position = UDim2.new(0.90, 0, 0.65, 0)

local bTap = AddBtn("Tap", "TAP", TapCenterScreen, UDim2.new(0, 60, 0, 60), Theme.Red)
bTap.Position = UDim2.new(0.90, 0, 0.25, 0)

print("Velox v2.3 Loaded: Multi-Touch Enabled")

-- ==============================================================================
-- [ VELOX V1.6 - FULL MOBILE CONTEXT & TOUCH GUI SUPPORT ]
-- Added: Ken, Race V3/V4, Soru, Jump, Weapon 1-4, M1 Remote
-- ==============================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

-- CONFIGURATION UI
local Theme = {
    Bg      = Color3.fromRGB(18, 18, 22),
    Sidebar = Color3.fromRGB(26, 26, 32),
    Element = Color3.fromRGB(35, 35, 42),
    Accent  = Color3.fromRGB(0, 255, 170), -- Cyber Green
    Text    = Color3.fromRGB(245, 245, 245),
    SubText = Color3.fromRGB(160, 160, 160),
    Red     = Color3.fromRGB(255, 65, 65),
    Green   = Color3.fromRGB(45, 225, 110),
    Blue    = Color3.fromRGB(0, 150, 255),
    Stroke  = Color3.fromRGB(60, 60, 70),
}

-- VARIABLES
local ActiveVirtualKeys = {} 
local ScreenGui = nil
local IsLayoutLocked = false
local M1Loop = nil 

-- DATA SENJATA
local WeaponData = {
    {name = "Melee", slot = 1, tooltip = "Melee"},
    {name = "Fruit", slot = 2, tooltip = "Blox Fruit"},
    {name = "Sword", slot = 3, tooltip = "Sword"},
    {name = "Gun",   slot = 4, tooltip = "Gun"}
}

-- ==============================================================================
-- [1] UTILITY FUNCTIONS (Firing Signals)
-- ==============================================================================

local function createCorner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p end
local function createStroke(p, c) local s = Instance.new("UIStroke"); s.Color = c or Theme.Stroke; s.Thickness = 1.5; s.ApplyStrokeMode = "Border"; s.Parent = p; return s end

-- FUNGSI SAKTI: Klik Tombol UI Tanpa Menyentuh Layar
local function FireUIElement(btn)
    if not btn then return end
    
    -- Metode 1: Activated (Paling umum untuk Context Button)
    for _, conn in pairs(getconnections(btn.Activated)) do conn:Fire() end
    
    -- Metode 2: MouseButton1Click (Umum untuk GUI lama)
    for _, conn in pairs(getconnections(btn.MouseButton1Click)) do conn:Fire() end
    
    -- Metode 3: InputBegan (Fallback untuk TouchGui)
    for _, conn in pairs(getconnections(btn.InputBegan)) do 
        conn:Fire({UserInputType = Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.Begin})
        task.wait()
        conn:Fire({UserInputType = Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.End})
    end
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
-- [2] LOGIKA INTI (CORE LOGIC)
-- ==============================================================================

-- [A] TRIGGER SKILL UTAMA (Z, X, C, V, F)
local function TriggerMainSkill(key)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PGui then return end
    local SkillsFrame = PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if SkillsFrame then
        for _, toolFrame in pairs(SkillsFrame:GetChildren()) do
            if toolFrame:IsA("Frame") and toolFrame.Visible then
                local keyFrame = toolFrame:FindFirstChild(key)
                if keyFrame then
                    local btn = keyFrame:FindFirstChild("Mobile") or keyFrame
                    FireUIElement(btn)
                    return true
                end
            end
        end
    end
end

-- [B] TRIGGER CONTEXT BUTTON (Ken, Race, Soru)
local function TriggerContext(actionName)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PGui then return end
    
    -- Path: MobileContextButtons -> ContextButtonFrame
    local ContextFrame = PGui:FindFirstChild("MobileContextButtons") and PGui.MobileContextButtons:FindFirstChild("ContextButtonFrame")
    
    if ContextFrame then
        -- Mencari child yang namanya mengandung keyword (misal "Ken", "Soru", "Race")
        for _, frame in pairs(ContextFrame:GetChildren()) do
            if frame.Name:find("BoundAction") and frame.Name:find(actionName) then
                local btn = frame:FindFirstChild("Button")
                if btn then
                    FireUIElement(btn)
                    return
                end
            end
        end
    end
end

-- [C] TRIGGER JUMP (TouchGui)
local function TriggerJump()
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PGui then return end
    
    -- Path: TouchGui -> TouchControlFrame -> JumpButton
    local TouchFrame = PGui:FindFirstChild("TouchGui") and PGui.TouchGui:FindFirstChild("TouchControlFrame")
    if TouchFrame then
        local btn = TouchFrame:FindFirstChild("JumpButton")
        if btn then
            FireUIElement(btn)
        else
            -- Fallback jika tombol UI tidak ketemu, pakai Humanoid
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid.Jump = true
            end
        end
    end
end

-- [D] EQUIP SENJATA (1-4)
local function EquipWeapon(slotIdx)
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid"); if not hum then return end
    local targetTip = WeaponData[slotIdx].tooltip
    
    for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
        if t:IsA("Tool") and t.ToolTip == targetTip then hum:EquipTool(t); return end
    end
    -- Fallback index
    local hotbar = LocalPlayer.Backpack:GetChildren()
    if hotbar[slotIdx] then hum:EquipTool(hotbar[slotIdx]) end
end

-- [E] ATTACK M1 (Remote Event)
local function DoAttackM1()
    local char = LocalPlayer.Character; if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    
    if tool and (tool.ToolTip == "Melee" or tool.ToolTip == "Sword") then
        local net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
        local remote = net and net:FindFirstChild("RE/RegisterAttack")
        if remote then remote:FireServer(0.4) end
    elseif tool then
        tool:Activate() -- Gun / Fruit
    else
        -- Combat
        local net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
        local remote = net and net:FindFirstChild("RE/RegisterAttack")
        if remote then remote:FireServer(0.4) end
    end
end

-- ==============================================================================
-- [3] UI MANAGER
-- ==============================================================================

if CoreGui:FindFirstChild("VeloxUI") then CoreGui.VeloxUI:Destroy() end
ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxUI"; ScreenGui.Parent = CoreGui; ScreenGui.ResetOnSpawn = false

-- TOGGLE BTN
local ToggleBtn = Instance.new("TextButton"); ToggleBtn.Size = UDim2.new(0, 45, 0, 45); ToggleBtn.Position = UDim2.new(0.02, 0, 0.3, 0); ToggleBtn.BackgroundColor3 = Theme.Sidebar; ToggleBtn.Text = "V"; ToggleBtn.TextColor3 = Theme.Accent; ToggleBtn.Parent = ScreenGui; createCorner(ToggleBtn, 12); createStroke(ToggleBtn, Theme.Accent)
local Vis = true
ToggleBtn.MouseButton1Click:Connect(function() Vis = not Vis; for _, v in pairs(ActiveVirtualKeys) do v.Button.Visible = Vis end end)
MakeDraggable(ToggleBtn)

-- FUNGSI ADD BUTTON
local function AddBtn(id, text, callback, isHold, size, color)
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
    createCorner(btn, 10)
    createStroke(btn, Theme.Accent)
    
    if isHold then
        btn.InputBegan:Connect(function(i) 
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                btn.BackgroundColor3 = Theme.Green; btn.TextColor3 = Theme.Bg
                if M1Loop then M1Loop:Disconnect() end
                M1Loop = RunService.Heartbeat:Connect(callback)
            end
        end)
        btn.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                btn.BackgroundColor3 = color or Color3.fromRGB(0,0,0); btn.TextColor3 = Theme.Accent
                if M1Loop then M1Loop:Disconnect(); M1Loop = nil end
            end
        end)
    else
        btn.MouseButton1Click:Connect(function()
            btn.BackgroundColor3 = Theme.Green; btn.TextColor3 = Theme.Bg; callback()
            task.delay(0.1, function() btn.BackgroundColor3 = color or Color3.fromRGB(0,0,0); btn.TextColor3 = Theme.Accent end)
        end)
    end
    MakeDraggable(btn)
    ActiveVirtualKeys[id] = {Button = btn}
    return btn
end

-- ==============================================================================
-- [4] SETUP BUTTON LAYOUT
-- ==============================================================================

-- WEAPONS (1-4)
AddBtn("1", "1", function() EquipWeapon(1) end).Position = UDim2.new(0.65, 0, 0.45, 0)
AddBtn("2", "2", function() EquipWeapon(2) end).Position = UDim2.new(0.75, 0, 0.45, 0)
AddBtn("3", "3", function() EquipWeapon(3) end).Position = UDim2.new(0.85, 0, 0.45, 0)
AddBtn("4", "4", function() EquipWeapon(4) end).Position = UDim2.new(0.95, 0, 0.45, 0)

-- SKILLS (Z-F)
AddBtn("Z", "Z", function() TriggerMainSkill("Z") end).Position = UDim2.new(0.65, 0, 0.55, 0)
AddBtn("X", "X", function() TriggerMainSkill("X") end).Position = UDim2.new(0.75, 0, 0.55, 0)
AddBtn("C", "C", function() TriggerMainSkill("C") end).Position = UDim2.new(0.85, 0, 0.55, 0)
AddBtn("V", "V", function() TriggerMainSkill("V") end).Position = UDim2.new(0.70, 0, 0.65, 0)
AddBtn("F", "F", function() TriggerMainSkill("F") end).Position = UDim2.new(0.80, 0, 0.65, 0)

-- ATTACK (M1 - HOLD)
local bM1 = AddBtn("M1", "ATK", DoAttackM1, true, UDim2.new(0, 65, 0, 65), Theme.Red)
bM1.Position = UDim2.new(0.90, 0, 0.25, 0)
bM1.BackgroundTransparency = 0.3

-- CONTEXT BUTTONS (NEW!)
-- "Buso" (Haki) -> Menggunakan Remote Langsung
AddBtn("Buso", "HAKI", function() ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso") end).Position = UDim2.new(0.60, 0, 0.35, 0)

-- "Ken" (Observation) -> Menggunakan Path MobileContextButtons
AddBtn("Ken", "KEN", function() TriggerContext("Ken") end).Position = UDim2.new(0.70, 0, 0.35, 0)

-- "Race" (V3/V4) -> Menggunakan Path MobileContextButtons
AddBtn("Race", "RACE", function() TriggerContext("RaceAbility") end).Position = UDim2.new(0.80, 0, 0.35, 0)

-- "Soru" (Flash Step) -> Menggunakan Path MobileContextButtons
AddBtn("Soru", "SORU", function() TriggerContext("Soru") end).Position = UDim2.new(0.50, 0, 0.65, 0)

-- "Jump" (Skyjump) -> Menggunakan Path TouchGui
local bJump = AddBtn("Jump", "JUMP", TriggerJump, false, UDim2.new(0, 60, 0, 60), Theme.Blue)
bJump.Position = UDim2.new(0.90, 0, 0.70, 0) -- Dekat area jempol kanan bawah standar

print("Velox v1.6 Loaded: Full Context & Touch Support")

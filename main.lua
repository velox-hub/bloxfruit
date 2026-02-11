-- ==============================================================================
-- [ VELOX LITE V5 - ADVANCED COMBO EDITOR ]
-- Ported Logic from Velox V135
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
    Element = Color3.fromRGB(35, 35, 45),
    Accent = Color3.fromRGB(255, 180, 0),
    Text = Color3.fromRGB(245, 245, 245),
    Red = Color3.fromRGB(255, 65, 65),
    Green = Color3.fromRGB(45, 225, 110)
}

local WeaponData = {
    {name = "Melee", slot = 1, keys = {"Z", "X", "C"}, color = Color3.fromRGB(255, 140, 0)},
    {name = "Fruit", slot = 2, keys = {"Z", "X", "C", "V", "F"}, color = Color3.fromRGB(170, 50, 255)},
    {name = "Sword", slot = 3, keys = {"Z", "X"}, color = Color3.fromRGB(0, 160, 255)},
    {name = "Gun",   slot = 4, keys = {"Z", "X"}, color = Color3.fromRGB(255, 220, 0)}
}

local ComboSteps = {} 
local isRunning = false

-- CLEANUP
if CoreGui:FindFirstChild("VeloxLiteV5") then CoreGui.VeloxLiteV5:Destroy() end
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxLiteV5"; ScreenGui.Parent = CoreGui

-- ==============================================================================
-- [1] CORE LOGIC
-- ==============================================================================

local function PressKey(k)
    VirtualInputManager:SendKeyEvent(true, k, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, k, false, game)
end

local function EquipSlot(slot)
    local key = slot == 1 and Enum.KeyCode.One or slot == 2 and Enum.KeyCode.Two or slot == 3 and Enum.KeyCode.Three or Enum.KeyCode.Four
    PressKey(key)
    task.wait(0.1)
end

local function TriggerSkill(keyName)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    local Skills = PGui and PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if Skills then
        for _, f in pairs(Skills:GetChildren()) do
            if f:IsA("Frame") and f.Visible and f.Name == keyName then
                local btn = f:FindFirstChild("Mobile") or f:FindFirstChild("Button") or f
                for _, c in pairs(getconnections(btn.Activated)) do c:Fire() end
                return
            end
        end
    end
end

local function ExecuteCombo()
    if isRunning or #ComboSteps == 0 then return end
    isRunning = true
    
    task.spawn(function()
        for _, step in ipairs(ComboSteps) do
            if not isRunning then break end
            
            -- Step 1: Equip Weapon
            EquipSlot(step.slot)
            
            -- Step 2: Delay sebelum skill
            if step.wait > 0 then task.wait(step.wait) end
            
            -- Step 3: Trigger Skill
            TriggerSkill(step.key)
            
            -- Step 4: Animasi cooldown (fixed short wait)
            task.wait(0.2)
        end
        isRunning = false
    end)
end

-- ==============================================================================
-- [2] UI UTILS (Sesuai V135)
-- ==============================================================================

local function createCorner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p
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
-- [3] EDITOR UI
-- ==============================================================================

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 250, 0, 350)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Theme.Bg
MainFrame.Parent = ScreenGui
MainFrame.Visible = false
createCorner(MainFrame, 10)
MakeDraggable(MainFrame)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Text = "COMBO EDITOR"
Title.TextColor3 = Theme.Accent
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.BackgroundTransparency = 1
Title.Parent = MainFrame

local StepScroll = Instance.new("ScrollingFrame")
StepScroll.Size = UDim2.new(1, -20, 1, -100)
StepScroll.Position = UDim2.new(0, 10, 0, 45)
StepScroll.BackgroundTransparency = 1
StepScroll.ScrollBarThickness = 2
StepScroll.Parent = MainFrame
local ListLayout = Instance.new("UIListLayout")
ListLayout.Parent = StepScroll; ListLayout.Padding = UDim.new(0, 5)

-- Fungsi Refresh UI (Logika Porting dari V135)
local function RefreshEditor()
    for _, v in pairs(StepScroll:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
    
    for i, step in ipairs(ComboSteps) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -5, 0, 60)
        card.BackgroundColor3 = Theme.Element
        card.Parent = StepScroll
        createCorner(card, 6)
        
        -- Pilih Senjata (Cycle)
        local weaponBtn = Instance.new("TextButton")
        weaponBtn.Size = UDim2.new(0.4, 0, 0, 25)
        weaponBtn.Position = UDim2.new(0.05, 0, 0.1, 0)
        weaponBtn.Text = WeaponData[step.slot].name
        weaponBtn.TextColor3 = WeaponData[step.slot].color
        weaponBtn.Font = Enum.Font.GothamBold
        weaponBtn.BackgroundTransparency = 1
        weaponBtn.Parent = card
        weaponBtn.MouseButton1Click:Connect(function()
            step.slot = (step.slot % 4) + 1
            step.key = WeaponData[step.slot].keys[1]
            RefreshEditor()
        end)
        
        -- Pilih Key (Cycle)
        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0.2, 0, 0, 25)
        keyBtn.Position = UDim2.new(0.5, 0, 0.1, 0)
        keyBtn.Text = "["..step.key.."]"
        keyBtn.TextColor3 = Theme.Text
        keyBtn.Font = Enum.Font.GothamBold
        keyBtn.BackgroundTransparency = 1
        keyBtn.Parent = card
        keyBtn.MouseButton1Click:Connect(function()
            local keys = WeaponData[step.slot].keys
            local currentIdx = table.find(keys, step.key) or 1
            step.key = keys[(currentIdx % #keys) + 1]
            RefreshEditor()
        end)

        -- Delete Step
        local del = Instance.new("TextButton")
        del.Size = UDim2.new(0, 25, 0, 25)
        del.Position = UDim2.new(1, -30, 0, 5)
        del.Text = "X"; del.TextColor3 = Theme.Red
        del.BackgroundTransparency = 1; del.Parent = card
        del.MouseButton1Click:Connect(function() table.remove(ComboSteps, i); RefreshEditor() end)

        -- Wait Slider (Mini Version)
        local slideBg = Instance.new("Frame")
        slideBg.Size = UDim2.new(0.8, 0, 0, 4)
        slideBg.Position = UDim2.new(0.1, 0, 0.8, 0)
        slideBg.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
        slideBg.Parent = card
        createCorner(slideBg, 2)

        local knob = Instance.new("TextButton")
        knob.Size = UDim2.new(0, 10, 0, 10)
        knob.Position = UDim2.new(step.wait/2, -5, 0.5, -5)
        knob.Text = ""; knob.BackgroundColor3 = Theme.Accent
        knob.Parent = slideBg
        createCorner(knob, 5)

        local waitLabel = Instance.new("TextLabel")
        waitLabel.Size = UDim2.new(0.3, 0, 0, 15)
        waitLabel.Position = UDim2.new(0.7, 0, 0.45, 0)
        waitLabel.Text = "Wait: "..step.wait.."s"
        waitLabel.TextColor3 = Theme.Accent; waitLabel.TextSize = 9
        waitLabel.BackgroundTransparency = 1; waitLabel.Parent = card

        -- Slider Logic
        local dragging = false
        knob.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
        UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local pos = math.clamp((input.Position.X - slideBg.AbsolutePosition.X) / slideBg.AbsoluteSize.X, 0, 1)
                knob.Position = UDim2.new(pos, -5, 0.5, -5)
                step.wait = math.floor(pos * 20) / 10 -- Max 2.0s
                waitLabel.Text = "Wait: "..step.wait.."s"
            end
        end)
    end
    StepScroll.CanvasSize = UDim2.new(0, 0, 0, #ComboSteps * 65)
end

-- Footer Buttons
local AddBtn = Instance.new("TextButton")
AddBtn.Size = UDim2.new(1, -20, 0, 35)
AddBtn.Position = UDim2.new(0, 10, 1, -45)
AddBtn.BackgroundColor3 = Theme.Green
AddBtn.Text = "+ ADD ACTION"
AddBtn.TextColor3 = Theme.Bg
AddBtn.Font = Enum.Font.GothamBold
AddBtn.Parent = MainFrame
createCorner(AddBtn, 6)
AddBtn.MouseButton1Click:Connect(function()
    table.insert(ComboSteps, {slot = 1, key = "Z", wait = 0.3})
    RefreshEditor()
end)

-- ==============================================================================
-- [4] FLOATING CONTROLS
-- ==============================================================================

local function CreateFloatingBtn(text, pos, color, func)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 80, 0, 35)
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.Text = text; btn.TextColor3 = Theme.Bg
    btn.Font = Enum.Font.GothamBold
    btn.Parent = ScreenGui
    createCorner(btn, 6)
    MakeDraggable(btn)
    btn.MouseButton1Click:Connect(func)
    return btn
end

local EditToggle = CreateFloatingBtn("EDITOR", UDim2.new(0.02, 0, 0.4, 0), Theme.Accent, function()
    MainFrame.Visible = not MainFrame.Visible
end)

local RunBtn = CreateFloatingBtn("RUN COMBO", UDim2.new(0.02, 0, 0.46, 0), Theme.Green, function()
    if isRunning then 
        isRunning = false 
    else 
        ExecuteCombo() 
    end
end)

print("Velox Lite V5: Advanced Editor Loaded")

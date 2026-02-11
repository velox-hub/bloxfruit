-- ==============================================================================
-- [ VELOX V1.4 - DIRECT UI & REMOTE EDITION ]
-- Silent Execution (No Mouse Interference)
-- ==============================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local FileName = "Velox_Config.json"

-- CONFIGURATION
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
    Popup   = Color3.fromRGB(25, 25, 30)
}

-- GLOBAL VARIABLES
local JOYSTICK_SIZE = 140
local KNOB_SIZE = 60
local DEADZONE = 0.15 

local isRunning = false 
local IsLayoutLocked = false 
local GlobalTransparency = 0 
local IsJoystickEnabled = false 
local JoyConnection = nil 

local Combos = {} 
local CurrentComboIndex = 0 
local ActiveVirtualKeys = {} 
local CurrentConfigName = nil 
local Keybinds = {} 
local VirtualKeySelectors = {}

-- SYSTEM VARS
local SkillMode = "INSTANT" 
local CurrentSmartKeyData = nil 
local SelectedComboID = nil 

-- UI VARIABLES
local ResizerList = {}
local CurrentSelectedElement = nil
local ScreenGui = nil

local ResizerUpdateFunc, UpdateTransparencyFunc, RefreshEditorUI, RefreshControlUI, CreateComboButtonFunc

local WeaponData = {
    {name = "Melee", slot = 1, color = Color3.fromRGB(255, 140, 0), tooltip = "Melee", keys = {"Z", "X", "C"}},
    {name = "Fruit", slot = 2, color = Color3.fromRGB(170, 50, 255), tooltip = "Blox Fruit", keys = {"Z", "X", "C", "V", "F"}},
    {name = "Sword", slot = 3, color = Color3.fromRGB(0, 160, 255), tooltip = "Sword", keys = {"Z", "X"}},
    {name = "Gun",   slot = 4, color = Color3.fromRGB(255, 220, 0),   tooltip = "Gun", keys = {"Z", "X"}}
}

-- ==============================================================================
-- [2] UTILITY & FIRE FUNCTIONS (INTI DARI PERUBAHAN)
-- ==============================================================================

local function createCorner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p end
local function createStroke(p, c) local s = Instance.new("UIStroke"); s.Color = c or Theme.Stroke; s.Thickness = 1.5; s.ApplyStrokeMode = "Border"; s.Parent = p; return s end

-- FUNGSI SAKTI: Klik Tombol UI tanpa Mouse
local function FireButton(button)
    if not button then return false end
    
    -- Cara 1: Menggunakan VirtualInputManager (Khusus Mobile Button) jika ada
    -- Cara 2: Menggunakan getconnections (Metode Exploit Standar)
    local connections = getconnections(button.MouseButton1Click)
    if #connections > 0 then
        for _, conn in pairs(connections) do 
            conn:Fire() 
        end
        return true
    end
    
    connections = getconnections(button.Activated)
    if #connections > 0 then
        for _, conn in pairs(connections) do 
            conn:Fire() 
        end
        return true
    end

    -- Cara 3: InputBegan (Fallback)
    for _, conn in pairs(getconnections(button.InputBegan)) do
        conn:Fire({UserInputType = Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.Begin})
    end
    return true
end

-- MENCARI TOMBOL SKILL DI UI
local function FindSkillButton(key)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PGui then return nil end
    
    -- Cek Folder Skills Utama
    local SkillsFrame = PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if SkillsFrame then
        for _, toolFrame in pairs(SkillsFrame:GetChildren()) do
            if toolFrame:IsA("Frame") and toolFrame.Visible then
                -- Kita mencari tombol Z, X, C, V, F di dalam frame senjata yang aktif
                local keyFrame = toolFrame:FindFirstChild(key)
                if keyFrame then
                    -- Cek tombol 'Mobile' di dalamnya (sesuai path user)
                    -- game.Players.LocalPlayer.PlayerGui.Main.Skills.Saber.Z.Mobile
                    local btn = keyFrame:FindFirstChild("Mobile") or keyFrame -- Fallback ke frame itu sendiri jika Mobile button ga ada
                    if btn and btn:IsA("GuiButton") then
                        return btn
                    end
                end
            end
        end
    end
    
    -- Cek Context Buttons (Race Skill, Soru, dll)
    -- game.Players.LocalPlayer.PlayerGui.MobileContextButtons.ContextButtonFrame.BoundActionSoru.Button
    local ContextFrame = PGui:FindFirstChild("MobileContextButtons") and PGui.MobileContextButtons:FindFirstChild("ContextButtonFrame")
    if ContextFrame then
        for _, boundAction in pairs(ContextFrame:GetChildren()) do
            if boundAction.Name:find("BoundAction") and boundAction:FindFirstChild("Button") then
                -- Logika mapping khusus
                if key == "Flash Step" and boundAction.Name:find("Soru") then return boundAction.Button end
                if key == "Race Skill" and boundAction.Name:find("RaceAbility") then return boundAction.Button end
                if key == "Ken" and boundAction.Name:find("Ken") then return boundAction.Button end
            end
        end
    end
    
    return nil
end

-- EKSEKUSI SKILL (UI -> REMOTE)
local function TriggerAction(key)
    -- 1. Coba Cari Tombol UI dan Klik
    local btn = FindSkillButton(key)
    if btn then
        FireButton(btn)
        return -- Sukses via UI
    end

    -- 2. Handling Khusus (Remote Direct) jika UI tidak ketemu
    if key == "M1" then
        -- Auto Click / Attack
        -- Gunakan Remote Attack yang diberikan user
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then
            if tool.ToolTip == "Melee" or tool.ToolTip == "Sword" then
                -- 0.4 untuk Melee/Sword biasanya aman
                ReplicatedStorage.Modules.Net["RE/RegisterAttack"]:FireServer(0.4)
            elseif tool.ToolTip == "Gun" then
                -- Gun butuh aiming, ini agak tricky kalau tanpa mouse.
                -- Kita skip aim dan hanya fire validator
                -- ReplicatedStorage.Remotes.Validator2:FireServer(math.random(1000000), 9) -- Warning: Risky
            else
                 -- Fallback: Activate Tool (Paling aman untuk M1)
                 tool:Activate()
            end
        end
    elseif key == "Buso" then
        ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso")
    elseif key == "Geppo" or key == "Jump" then
         -- Double Jump Remote
        ReplicatedStorage.Remotes.CommE:FireServer("DoubleJump", false)
    elseif key == "Dodge" then
         -- Dash Remote
         ReplicatedStorage.Remotes.CommE:FireServer("Dodge", 30, true, 1) -- Args mungkin berubah, hati-hati
    end
end

-- EQUIP WEAPON (Direct Humanoid)
local function equipWeapon(slotIdx)
    if not slotIdx then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end

    local targetTip = WeaponData[slotIdx].tooltip
    local current = char:FindFirstChildOfClass("Tool")
    if current and current.ToolTip == targetTip then return end

    local foundTool = nil
    for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
        if t:IsA("Tool") and t.ToolTip == targetTip then
            foundTool = t
            break
        end
    end

    if foundTool then
        hum:EquipTool(foundTool) -- SILENT EQUIP
    end
end

-- ==============================================================================
-- [3] CORE LOGIC & MANAGERS
-- ==============================================================================

-- [SAMA SEPERTI SEBELUMNYA TAPI MENGGUNAKAN TriggerAction BUKAN pressKey]
local function executeComboSequence(idx)
    if not Combos[idx] then return end
    if isRunning then return end

    isRunning = true
    local data = Combos[idx]
    local btn = data.Button
    
    -- Visual Indicator
    btn.Text = "STOP"
    btn.BackgroundColor3 = Theme.Red
    
    task.spawn(function()
        for i, step in ipairs(data.Steps) do
            if not isRunning then break end
            
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then isRunning = false; break end
            
            -- Equip Weapon
            if step.Slot then equipWeapon(step.Slot); task.wait(0.15) end
            
            -- Delay Step
            if step.Delay and step.Delay > 0 then task.wait(step.Delay) end
            
            -- EXECUTE SKILL
            TriggerAction(step.Key)
            
            -- Hold logic (untuk UI agak susah disimulasi hold, jadi kita spam delay)
            if step.IsHold then
                task.wait(step.HoldTime or 0.1)
                -- Release logic biasanya tidak perlu untuk Click event, kecuali toolnya charged
            else
                task.wait(0.2) 
            end
        end
        
        isRunning = false
        if btn then btn.Text = data.Name; btn.BackgroundColor3 = (SelectedComboID == idx) and Theme.Green or Theme.Sidebar end
    end)
end

-- ==============================================================================
-- [4] INPUT HANDLERS (UPDATED)
-- ==============================================================================
local SmartTouchObject = nil 

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if UserInputService:GetFocusedTextBox() then return end

    -- PC Keybinds
    if input.UserInputType == Enum.UserInputType.Keyboard and not gameProcessed then
        for action, bindKey in pairs(Keybinds) do
            if input.KeyCode == bindKey then
                if string.sub(action, 1, 1) == "C" then 
                    local id = tonumber(string.sub(action, 2))
                    if Combos[id] then
                        if SkillMode == "INSTANT" then executeComboSequence(id)
                        else SelectedComboID = id; end
                    end
                elseif ActiveVirtualKeys[action] then 
                    local vData = ActiveVirtualKeys[action]
                    local isWeaponKey = table.find({"1","2","3","4"}, vData.Key.Name)
                    
                    if SkillMode == "INSTANT" or isWeaponKey then
                        if vData.Slot then equipWeapon(vData.Slot) end
                        TriggerAction(vData.Key.Name) -- GANTI VIM DENGAN TRIGGER ACTION
                    else 
                        CurrentSmartKeyData = vData
                    end
                end
            end
        end
    end
    
    -- SMART TOUCH LOGIC (Klik Layar)
    if not gameProcessed and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
        
        -- Smart Skill Logic
        if SkillMode == "SMART" and CurrentSmartKeyData ~= nil then
            SmartTouchObject = input 
            task.spawn(function()
                if CurrentSmartKeyData.Slot then equipWeapon(CurrentSmartKeyData.Slot); task.wait(0.05) end
                TriggerAction(CurrentSmartKeyData.Key.Name) -- GANTI VIM
            end)
        end
        
        -- Smart Combo Logic
        if SelectedComboID ~= nil and not isRunning then
            executeComboSequence(SelectedComboID)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input == SmartTouchObject and SkillMode == "SMART" and CurrentSmartKeyData ~= nil then
        -- Reset visual state
        if ActiveVirtualKeys[CurrentSmartKeyData.ID] then
            local btn = ActiveVirtualKeys[CurrentSmartKeyData.ID].Button
            btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
            btn.TextColor3 = Theme.Accent
        end
        CurrentSmartKeyData = nil
        SmartTouchObject = nil
    end
end)

-- ==============================================================================
-- [5] UI CONSTRUCTION (SAMA SEPERTI SEBELUMNYA)
-- ==============================================================================
-- ... (Kode UI tetap sama karena sudah bagus, saya hanya menyertakan bagian yang perlu load)

local function MakeDraggable(guiObject, clickCallback)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not IsLayoutLocked then 
                dragging = true
                dragStart = input.Position
                startPos = guiObject.Position
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
    guiObject.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if clickCallback and (IsLayoutLocked or (not dragging or (input.Position - dragStart).Magnitude < 15)) then clickCallback() end
            dragging = false
        end
    end)
end

-- SETUP UI CONTAINER
if CoreGui:FindFirstChild("VeloxUI") then CoreGui.VeloxUI:Destroy() end
ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxUI"; ScreenGui.Parent = CoreGui; ScreenGui.ResetOnSpawn = false

-- (Bagian UI Construction dipersingkat agar muat, gunakan UI yang sama dari script sebelumnya)
-- TOGGLE & WINDOW
local ToggleBtn = Instance.new("TextButton"); ToggleBtn.Size = UDim2.new(0, 45, 0, 45); ToggleBtn.Position = UDim2.new(0.02, 0, 0.3, 0); ToggleBtn.BackgroundColor3 = Theme.Sidebar; ToggleBtn.Text = "V"; ToggleBtn.TextColor3 = Theme.Accent; ToggleBtn.Parent = ScreenGui; createCorner(ToggleBtn, 12); createStroke(ToggleBtn, Theme.Accent); MakeDraggable(ToggleBtn, function() end)

-- FUNGSI MANAGER (ADD/REMOVE BUTTONS)
local function toggleVirtualKey(keyName, slotIdx, customName)
    local id = customName or keyName
    if ActiveVirtualKeys[id] then 
        ActiveVirtualKeys[id].Button:Destroy(); ActiveVirtualKeys[id]=nil
    else
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 50, 0, 50); btn.Position = UDim2.new(0.5, 0, 0.5, 0); btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0); btn.Text = id; btn.TextColor3 = Theme.Accent; btn.Parent = ScreenGui; createCorner(btn, 12); createStroke(btn, Theme.Accent)
        
        local vData = {ID=id, Key={Name=keyName}, Slot=slotIdx, Button=btn} -- Key skrg hanya perlu Name untuk TriggerAction
        
        btn.MouseButton1Click:Connect(function()
             -- LOGIKA KLIK TOMBOL VIRTUAL
             if SkillMode == "INSTANT" then
                 if vData.Slot then equipWeapon(vData.Slot) end
                 TriggerAction(keyName) -- Direct UI Trigger
             else
                 -- Smart Logic
                 if CurrentSmartKeyData and CurrentSmartKeyData.ID == id then
                    CurrentSmartKeyData = nil; btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
                 else
                    CurrentSmartKeyData = vData; btn.BackgroundColor3 = Theme.Green
                 end
             end
        end)
        MakeDraggable(btn, nil)
        ActiveVirtualKeys[id] = vData
    end
end

-- ==============================================================================
-- [6] INISIALISASI SEDERHANA (Agar Script Langsung Jalan)
-- ==============================================================================

-- Load Default 4 Weapon Keys
toggleVirtualKey("Z", 1, "Z")
toggleVirtualKey("X", 1, "X")
toggleVirtualKey("C", 1, "C")

-- Tambahkan Tombol Khusus berdasarkan request Remote Anda
-- Anda bisa menambahkan tombol custom seperti ini:
local function AddCustomButton(name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 50, 0, 50); btn.Position = UDim2.new(0.5, 60, 0.5, 0); btn.BackgroundColor3 = Theme.Sidebar; btn.Text = name; btn.TextColor3 = Theme.Text; btn.Parent = ScreenGui; createCorner(btn, 12); createStroke(btn, Theme.Blue)
    btn.MouseButton1Click:Connect(callback)
    MakeDraggable(btn, nil)
end

AddCustomButton("HAKI", function() TriggerAction("Buso") end)
AddCustomButton("M1", function() TriggerAction("M1") end)

print("Velox Silent UI Loaded")

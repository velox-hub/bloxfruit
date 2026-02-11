-- ==============================================================================
-- [ VELOX V1.5 - WEAPON & REMOTE M1 FIXED ]
-- Fix: 1-4 Equip, M1 Silent Remote Attack
-- ==============================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local FileName = "Velox_Config.json"

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
    Popup   = Color3.fromRGB(25, 25, 30)
}

-- VARIABLES
local ActiveVirtualKeys = {} 
local ScreenGui = nil
local IsLayoutLocked = false
local M1Loop = nil -- Untuk Auto Click saat ditahan

-- DATA SENJATA (Blox Fruit Standard)
local WeaponData = {
    {name = "Melee", slot = 1, tooltip = "Melee"},
    {name = "Fruit", slot = 2, tooltip = "Blox Fruit"},
    {name = "Sword", slot = 3, tooltip = "Sword"},
    {name = "Gun",   slot = 4, tooltip = "Gun"}
}

-- ==============================================================================
-- [1] UTILITY FUNCTIONS
-- ==============================================================================

local function createCorner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p end
local function createStroke(p, c) local s = Instance.new("UIStroke"); s.Color = c or Theme.Stroke; s.Thickness = 1.5; s.ApplyStrokeMode = "Border"; s.Parent = p; return s end

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

-- ==============================================================================
-- [2] LOGIKA INTI (CORE LOGIC)
-- ==============================================================================

-- FUNGSI: MENCARI TOMBOL SKILL DI LAYAR (UI CLICK)
local function TriggerUISkill(key)
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PGui then return end

    -- Cari di folder Main Skills (Z, X, C, V, F)
    local SkillsFrame = PGui:FindFirstChild("Main") and PGui.Main:FindFirstChild("Skills")
    if SkillsFrame then
        for _, toolFrame in pairs(SkillsFrame:GetChildren()) do
            if toolFrame:IsA("Frame") and toolFrame.Visible then
                local keyFrame = toolFrame:FindFirstChild(key)
                if keyFrame then
                    -- Prioritas: Tombol Mobile > Frame itu sendiri
                    local btn = keyFrame:FindFirstChild("Mobile") or keyFrame
                    if btn then
                        -- Firing Signal (Klik tanpa mouse)
                        for _, conn in pairs(getconnections(btn.MouseButton1Click)) do conn:Fire() end
                        for _, conn in pairs(getconnections(btn.Activated)) do conn:Fire() end
                        for _, conn in pairs(getconnections(btn.InputBegan)) do 
                            conn:Fire({UserInputType = Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.Begin})
                        end
                        return true
                    end
                end
            end
        end
    end
end

-- FUNGSI: EQUIP SENJATA (1-4)
local function EquipWeapon(slotIdx)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end

    -- Ambil Tooltip target (Melee/Fruit/Sword/Gun)
    local targetTip = WeaponData[slotIdx].tooltip
    
    -- Cek backpack
    for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do
        if t:IsA("Tool") and t.ToolTip == targetTip then
            hum:EquipTool(t) -- Paksa Equip
            return
        end
    end
    
    -- Jika di backpack gak ketemu (mungkin karena nama beda/inventory penuh), coba cari berdasarkan urutan
    -- Fallback simple
    local hotbar = LocalPlayer.Backpack:GetChildren()
    if hotbar[slotIdx] then
        hum:EquipTool(hotbar[slotIdx])
    end
end

-- FUNGSI: SERANGAN M1 (REMOTE EVENT)
local function DoAttackM1()
    local char = LocalPlayer.Character
    if not char then return end
    
    local tool = char:FindFirstChildOfClass("Tool")
    
    if tool then
        -- Cek Tipe Senjata
        if tool.ToolTip == "Melee" or tool.ToolTip == "Sword" then
            -- MENGGUNAKAN REMOTE REGISTER ATTACK (Silent)
            local net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
            local remote = net and net:FindFirstChild("RE/RegisterAttack")
            if remote then
                remote:FireServer(0.4) -- Cooldown standar 0.4s
            end
        elseif tool.ToolTip == "Gun" then
            -- Gun agak susah remote tanpa aim, jadi kita pakai Activate()
            tool:Activate() 
        else
            -- Blox Fruit M1 (biasanya Tap)
            tool:Activate()
            -- Coba remote attack juga siapa tau work (misal Light Fruit spear)
            local net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
            local remote = net and net:FindFirstChild("RE/RegisterAttack")
            if remote then remote:FireServer(0.4) end
        end
    else
        -- Jika tidak pegang tool (Combat kosong), tetap kirim remote attack
        local net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
        local remote = net and net:FindFirstChild("RE/RegisterAttack")
        if remote then remote:FireServer(0.4) end
    end
end

-- FUNGSI: TOMBOL KHUSUS (HAKI, FLASH STEP, DLL)
local function TriggerSpecial(key)
    if key == "Buso" then
        ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso")
    elseif key == "Geppo" then
        ReplicatedStorage.Remotes.CommE:FireServer("DoubleJump", false)
    elseif key == "Soru" then
        -- Soru butuh posisi mouse, agak rumit, kita pakai UI Button-nya saja
        local PGui = LocalPlayer:FindFirstChild("PlayerGui")
        local ContextFrame = PGui and PGui:FindFirstChild("MobileContextButtons") and PGui.MobileContextButtons:FindFirstChild("ContextButtonFrame")
        if ContextFrame then
            for _, frame in pairs(ContextFrame:GetChildren()) do
                if frame.Name:find("Soru") and frame:FindFirstChild("Button") then
                    for _, conn in pairs(getconnections(frame.Button.Activated)) do conn:Fire() end
                    return
                end
            end
        end
    end
end

-- ==============================================================================
-- [3] UI CONSTRUCTION & BUTTON MANAGER
-- ==============================================================================

if CoreGui:FindFirstChild("VeloxUI") then CoreGui.VeloxUI:Destroy() end
ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "VeloxUI"; ScreenGui.Parent = CoreGui; ScreenGui.ResetOnSpawn = false

-- TOGGLE BUTTON
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 45, 0, 45); ToggleBtn.Position = UDim2.new(0.02, 0, 0.3, 0); ToggleBtn.BackgroundColor3 = Theme.Sidebar; ToggleBtn.Text = "V"; ToggleBtn.TextColor3 = Theme.Accent; ToggleBtn.Parent = ScreenGui
createCorner(ToggleBtn, 12); createStroke(ToggleBtn, Theme.Accent)
local WindowVisible = true
ToggleBtn.MouseButton1Click:Connect(function() 
    WindowVisible = not WindowVisible
    for _, v in pairs(ActiveVirtualKeys) do v.Button.Visible = WindowVisible end
end)
MakeDraggable(ToggleBtn, nil)

-- FUNGSI PEMBUAT TOMBOL VIRTUAL
local function AddVirtualButton(id, customText, callback, isHold)
    if ActiveVirtualKeys[id] then ActiveVirtualKeys[id].Button:Destroy() end
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 50, 0, 50)
    btn.Position = UDim2.new(0.5, 0, 0.5, 0) -- Default tengah
    btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    btn.BackgroundTransparency = 0.2
    btn.Text = customText or id
    btn.TextColor3 = Theme.Accent
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 18
    btn.Parent = ScreenGui
    createCorner(btn, 12)
    createStroke(btn, Theme.Accent)
    
    -- LOGIKA KLIK / TAHAN
    if isHold then
        -- Khusus M1: Auto Spam saat ditahan
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                btn.BackgroundColor3 = Theme.Green
                btn.TextColor3 = Theme.Bg
                -- Mulai Loop Attack
                if M1Loop then M1Loop:Disconnect() end
                M1Loop = RunService.Heartbeat:Connect(function()
                    callback() -- Jalankan fungsi M1
                end)
            end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
                btn.TextColor3 = Theme.Accent
                if M1Loop then M1Loop:Disconnect(); M1Loop = nil end
            end
        end)
    else
        -- Tombol Biasa (Sekali Klik)
        btn.MouseButton1Click:Connect(function()
            btn.BackgroundColor3 = Theme.Green
            btn.TextColor3 = Theme.Bg
            callback()
            task.delay(0.1, function()
                btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
                btn.TextColor3 = Theme.Accent
            end)
        end)
    end
    
    MakeDraggable(btn, nil)
    ActiveVirtualKeys[id] = {Button = btn}
    return btn
end

-- ==============================================================================
-- [4] SETUP TOMBOL (DEFAULT)
-- ==============================================================================

-- 1. TOMBOL EQUIP (1, 2, 3, 4)
AddVirtualButton("1", "1", function() EquipWeapon(1) end, false).Position = UDim2.new(0.75, 0, 0.5, -60)
AddVirtualButton("2", "2", function() EquipWeapon(2) end, false).Position = UDim2.new(0.85, 0, 0.5, -60)
AddVirtualButton("3", "3", function() EquipWeapon(3) end, false).Position = UDim2.new(0.75, 0, 0.5, 0)
AddVirtualButton("4", "4", function() EquipWeapon(4) end, false).Position = UDim2.new(0.85, 0, 0.5, 0)

-- 2. TOMBOL SKILL (Z, X, C, V, F)
AddVirtualButton("Z", "Z", function() TriggerUISkill("Z") end, false).Position = UDim2.new(0.75, 0, 0.65, 0)
AddVirtualButton("X", "X", function() TriggerUISkill("X") end, false).Position = UDim2.new(0.85, 0, 0.65, 0)
AddVirtualButton("C", "C", function() TriggerUISkill("C") end, false).Position = UDim2.new(0.95, 0, 0.65, 0)
AddVirtualButton("V", "V", function() TriggerUISkill("V") end, false).Position = UDim2.new(0.80, 0, 0.75, 0)
AddVirtualButton("F", "F", function() TriggerUISkill("F") end, false).Position = UDim2.new(0.90, 0, 0.75, 0)

-- 3. TOMBOL M1 (ATTACK) - SPECIAL REMOTE
-- Parameter terakhir 'true' artinya Mode Tahan (Hold) aktif
local btnM1 = AddVirtualButton("M1", "ATK", function() DoAttackM1() end, true)
btnM1.Position = UDim2.new(0.85, 0, 0.4, 0) -- Posisi agak di atas
btnM1.Size = UDim2.new(0, 70, 0, 70) -- Lebih besar
btnM1.BackgroundColor3 = Theme.Red
btnM1.BackgroundTransparency = 0.3

-- 4. TOMBOL TAMBAHAN (HAKI)
AddVirtualButton("Buso", "HAKI", function() TriggerSpecial("Buso") end, false).Position = UDim2.new(0.65, 0, 0.5, 0)

print("Velox v1.5 Loaded - Weapon & Remote M1 Ready")

-- Notifikasi Sederhana
local StarterGui = game:GetService("StarterGui")
StarterGui:SetCore("SendNotification", {
    Title = "Velox Updated";
    Text = "1-4 (Equip) & M1 (Remote) Added!";
    Duration = 5;
})

--[[
    VELOX V1: TRUE LOGIC (CORRECTED)
    Logika:
    1. Unequip senjata lama (Parent to Backpack) + Remote False.
    2. Equip senjata baru (Parent to Character) + Remote True.
    3. Skill: UI Fire Instant.
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

if CoreGui:FindFirstChild("VeloxV1") then
    CoreGui.VeloxV1:Destroy()
end

-- GUI SETUP
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VeloxV1"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 280, 0, 150)
MainFrame.Position = UDim2.new(0.5, -140, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(255, 255, 255)

-- CONTAINER
local SlotC = Instance.new("Frame"); SlotC.Size=UDim2.new(0.9,0,0.35,0); SlotC.Position=UDim2.new(0.05,0,0.2,0); SlotC.BackgroundTransparency=1; SlotC.Parent=MainFrame
local SkillC = Instance.new("Frame"); SkillC.Size=UDim2.new(0.9,0,0.35,0); SkillC.Position=UDim2.new(0.05,0,0.6,0); SkillC.BackgroundTransparency=1; SkillC.Parent=MainFrame
local G1 = Instance.new("UIGridLayout"); G1.CellSize=UDim2.new(0.22,0,1,0); G1.Parent=SlotC
local G2 = Instance.new("UIGridLayout"); G2.CellSize=UDim2.new(0.18,0,1,0); G2.Parent=SkillC

-- ==============================================================================
-- [LOGIKA V1 YANG BENAR]
-- ==============================================================================

local function SwitchSlot(targetType)
    local Char = LP.Character
    local Backpack = LP.Backpack
    
    -- 1. BERSIHKAN TANGAN (Unequip Current)
    for _, tool in pairs(Char:GetChildren()) do
        if tool:IsA("Tool") then
            -- Jika kita sudah pegang senjata yg benar, cukup refresh remote
            if tool.ToolTip == targetType then
                local re = tool:FindFirstChild("RemoteEvent")
                if re then re:FireServer(true) end
                return 
            end
            
            -- Jika senjata lain: Matikan Remote & Masukkan ke Tas
            local re = tool:FindFirstChild("RemoteEvent")
            if re then re:FireServer(false) end
            
            tool.Parent = Backpack -- INI ADALAH CARA 'UNEQUIP' MANUAL YG BENAR
        end
    end

    -- 2. AMBIL DARI TAS (Equip New)
    for _, tool in pairs(Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.ToolTip == targetType then
            
            tool.Parent = Char -- INI ADALAH CARA 'EQUIP' MANUAL YG BENAR
            
            -- Nyalakan Remote
            local re = tool:FindFirstChild("RemoteEvent")
            if re then re:FireServer(true) end
            
            return
        end
    end
end

-- LOGIKA SKILL (UI BUTTON FIRE - PALING STABIL)
local function UseSkill(key)
    local Main = PlayerGui:FindFirstChild("Main")
    local Skills = Main and Main:FindFirstChild("Skills")
    if Skills then
        for _, w in pairs(Skills:GetChildren()) do
            if w:IsA("Frame") and w.Visible then
                local b = w:FindFirstChild(key) and w[key]:FindFirstChild("Mobile")
                if b then
                    for _, c in pairs(getconnections(b.Activated)) do c:Fire() end
                    for _, c in pairs(getconnections(b.MouseButton1Click)) do c:Fire() end
                    return
                end
            end
        end
    end
end

-- ==============================================================================
-- [TOMBOL]
-- ==============================================================================

local function MakeBtn(text, color, parent, cb)
    local b = Instance.new("TextButton")
    b.Text = text
    b.BackgroundColor3 = Color3.fromRGB(30,30,35)
    b.TextColor3 = color
    b.Font = Enum.Font.GothamBold
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    
    b.MouseButton1Down:Connect(function()
        cb()
        b.BackgroundColor3 = color; b.TextColor3 = Color3.fromRGB(10,10,10)
        task.wait(0.05)
        b.BackgroundColor3 = Color3.fromRGB(30,30,35); b.TextColor3 = color
    end)
end

-- 1-4
MakeBtn("1", Color3.fromRGB(255, 200, 0), SlotC, function() SwitchSlot("Melee") end)
MakeBtn("2", Color3.fromRGB(255, 200, 0), SlotC, function() SwitchSlot("Blox Fruit") end)
MakeBtn("3", Color3.fromRGB(255, 200, 0), SlotC, function() SwitchSlot("Sword") end)
MakeBtn("4", Color3.fromRGB(255, 200, 0), SlotC, function() SwitchSlot("Gun") end)

-- Z-F
local k = {"Z","X","C","V","F"}
for _, key in ipairs(k) do
    MakeBtn(key, Color3.fromRGB(0, 200, 255), SkillC, function() UseSkill(key) end)
end

-- Close
local C = Instance.new("TextButton"); C.Text="X"; C.Parent=MainFrame; C.Size=UDim2.new(0,20,0,20); C.Position=UDim2.new(1,-25,0,0); C.BackgroundTransparency=1; C.TextColor3=Color3.new(1,0,0)
C.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

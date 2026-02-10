--[[
    VELOX DIAGNOSTIC TOOL (TESTER)
    Oleh: Gemini Assistant
    Fungsi: Mengecek apakah Script Hybrid bekerja di HP kamu.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- 1. BERSIHKAN UI LAMA
if CoreGui:FindFirstChild("VeloxTester") then
    CoreGui.VeloxTester:Destroy()
end

-- 2. GUI SETUP
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VeloxTester"
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 350, 0, 250)
MainFrame.Position = UDim2.new(0.5, -175, 0.5, -125)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(255, 180, 0)

-- JUDUL
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "VELOX HYBRID TESTER"
Title.TextColor3 = Color3.fromRGB(255, 180, 0)
Title.Font = Enum.Font.GothamBlack
Title.BackgroundTransparency = 1
Title.Parent = MainFrame

-- LOG WINDOW (TEMPAT HASIL TEST)
local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Size = UDim2.new(0.9, 0, 0.5, 0)
LogScroll.Position = UDim2.new(0.05, 0, 0.15, 0)
LogScroll.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
LogScroll.Parent = MainFrame
local UIList = Instance.new("UIListLayout")
UIList.Parent = LogScroll
UIList.SortOrder = Enum.SortOrder.LayoutOrder

-- FUNGSI LOGGING
local function AddLog(text, type)
    local color = Color3.fromRGB(255, 255, 255)
    if type == "success" then color = Color3.fromRGB(50, 255, 100) end
    if type == "error" then color = Color3.fromRGB(255, 80, 80) end
    if type == "warn" then color = Color3.fromRGB(255, 200, 50) end

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 20)
    Label.BackgroundTransparency = 1
    Label.Text = "["..os.date("%X").."] " .. text
    Label.TextColor3 = color
    Label.Font = Enum.Font.Code
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = LogScroll
    
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y)
    LogScroll.CanvasPosition = Vector2.new(0, 9999) -- Auto scroll ke bawah
end

-- CONTAINER TOMBOL
local BtnContainer = Instance.new("Frame")
BtnContainer.Size = UDim2.new(0.9, 0, 0.3, 0)
BtnContainer.Position = UDim2.new(0.05, 0, 0.68, 0)
BtnContainer.BackgroundTransparency = 1
BtnContainer.Parent = MainFrame
local Grid = Instance.new("UIGridLayout")
Grid.CellSize = UDim2.new(0.48, 0, 0.45, 0)
Grid.Parent = BtnContainer

-- ==============================================================================
-- LOGIKA TESTER
-- ==============================================================================

local function MakeBtn(text, callback)
    local btn = Instance.new("TextButton")
    btn.Text = text
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.Parent = BtnContainer
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
end

-- 1. TEST M1 (REMOTE)
MakeBtn("TEST M1 (REMOTE)", function()
    local s, e = pcall(function()
        local remote = ReplicatedStorage.Modules.Net:FindFirstChild("RE/RegisterAttack")
        if remote then
            local args = { [1] = 0.4000000059604645 }
            remote:FireServer(unpack(args))
            AddLog("M1 Sent: Success", "success")
        else
            AddLog("M1 Remote Missing!", "error")
        end
    end)
    if not s then AddLog("M1 Error: "..e, "error") end
end)

-- 2. TEST EQUIP (REMOTE)
MakeBtn("TEST EQUIP (ANY)", function()
    local s, e = pcall(function()
        -- Cari senjata apapun di backpack untuk dites
        local backpack = LP.Backpack
        local tool = backpack:FindFirstChildOfClass("Tool")
        
        if tool then
            LP.Character.Humanoid:EquipTool(tool)
            local remote = tool:FindFirstChild("EquipEvent")
            if remote then
                remote:FireServer(true)
                AddLog("Equip: " .. tool.Name, "success")
            else
                AddLog("Remote Equip Missing pada "..tool.Name, "warn")
            end
        else
            AddLog("Tidak ada senjata di Backpack!", "warn")
        end
    end)
    if not s then AddLog("Equip Error: "..e, "error") end
end)

-- 3. TEST SKILL Z (UI FIRE)
MakeBtn("TEST SKILL Z (UI)", function()
    local s, e = pcall(function()
        local Main = PlayerGui:FindFirstChild("Main")
        local Skills = Main and Main:FindFirstChild("Skills")
        local Found = false
        
        if Skills then
            for _, f in pairs(Skills:GetChildren()) do
                if f:IsA("Frame") and f.Visible then
                    AddLog("Senjata Aktif: "..f.Name, "warn")
                    local Z = f:FindFirstChild("Z")
                    local Mobile = Z and Z:FindFirstChild("Mobile")
                    
                    if Mobile then
                        -- Coba Fire
                        local cons = getconnections(Mobile.Activated)
                        if #cons == 0 then cons = getconnections(Mobile.MouseButton1Click) end
                        
                        for _, c in pairs(cons) do c:Fire() end
                        AddLog("Tombol Z Ditekan (Virtual)", "success")
                        Found = true
                    else
                        AddLog("Tombol Z Mobile tidak ketemu!", "error")
                    end
                end
            end
        end
        
        if not Found then AddLog("Tidak ada senjata yg dipegang/Visible", "error") end
    end)
    if not s then AddLog("Skill Error: "..e, "error") end
end)

-- 4. TEST JUMP (UI FIRE)
MakeBtn("TEST JUMP (UI)", function()
    local s, e = pcall(function()
        local JumpBtn = PlayerGui.TouchGui.TouchControlFrame.JumpButton
        if JumpBtn then
            local cons = getconnections(JumpBtn.Activated)
            if #cons == 0 then cons = getconnections(JumpBtn.MouseButton1Click) end
            
            for _, c in pairs(cons) do c:Fire() end
            AddLog("Jump Button Ditekan", "success")
        else
            AddLog("Tombol Jump Roblox Missing!", "error")
        end
    end)
    if not s then AddLog("Jump Error: "..e, "error") end
end)

-- TUTUP
local Close = Instance.new("TextButton")
Close.Text = "X"
Close.Size = UDim2.new(0, 30, 0, 30)
Close.Position = UDim2.new(1, -35, 0, 5)
Close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
Close.Parent = MainFrame
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 6)
Close.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

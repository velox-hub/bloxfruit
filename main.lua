-- [[ SKILL UI INSPECTOR TOOL ]]
-- Script ini untuk mendeteksi perubahan properti UI saat Cooldown

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- 1. BERSIHKAN UI LAMA
if CoreGui:FindFirstChild("SkillInspectorUI") then
    CoreGui.SkillInspectorUI:Destroy()
end

-- 2. BUAT UI INSPECTOR
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SkillInspectorUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 350)
MainFrame.Position = UDim2.new(0.5, -150, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true -- Agar tidak tembus klik
MainFrame.Parent = ScreenGui

-- JUDUL & DRAG BAR
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
TopBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Text = "SKILL UI INSPECTOR"
Title.Size = UDim2.new(1, -30, 1, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 200, 0)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "X"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Parent = TopBar
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- INPUT KEY (Z, X, C...)
local InputBox = Instance.new("TextBox")
InputBox.PlaceholderText = "Input Key (Z, X, etc)"
InputBox.Text = "Z"
InputBox.Size = UDim2.new(0.8, 0, 0, 35)
InputBox.Position = UDim2.new(0.1, 0, 0.12, 0)
InputBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
InputBox.TextColor3 = Color3.new(1,1,1)
InputBox.Font = Enum.Font.Gotham
InputBox.TextSize = 14
InputBox.Parent = MainFrame

-- TOMBOL SCAN
local ScanBtn = Instance.new("TextButton")
ScanBtn.Text = "1. SCAN READY STATE"
ScanBtn.Size = UDim2.new(0.8, 0, 0, 40)
ScanBtn.Position = UDim2.new(0.1, 0, 0.25, 0)
ScanBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255) -- Cyan
ScanBtn.TextColor3 = Color3.new(1,1,1)
ScanBtn.Font = Enum.Font.GothamBold
ScanBtn.TextSize = 12
ScanBtn.Parent = MainFrame
local UICorner = Instance.new("UICorner"); UICorner.Parent = ScanBtn

-- LOG OUTPUT (SCROLLING FRAME)
local LogFrame = Instance.new("ScrollingFrame")
LogFrame.Size = UDim2.new(0.9, 0, 0.45, 0)
LogFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
LogFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
LogFrame.Parent = MainFrame
LogFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogFrame.ScrollBarThickness = 4

local UIList = Instance.new("UIListLayout")
UIList.Parent = LogFrame
UIList.Padding = UDim.new(0, 5)

-- STATUS TEXT
local StatusLbl = Instance.new("TextLabel")
StatusLbl.Text = "Status: Idle"
StatusLbl.Size = UDim2.new(1, 0, 0, 20)
StatusLbl.Position = UDim2.new(0, 0, 0.9, 0)
StatusLbl.BackgroundTransparency = 1
StatusLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLbl.TextSize = 11
StatusLbl.Parent = MainFrame

-- 3. LOGIC DRAGGABLE (BISA DIGESER)
local dragging, dragInput, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
TopBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- 4. FUNGSI PENCARI TOMBOL (Sama seperti script utama Anda)
local function FindButton(key)
    local Skills = PlayerGui:FindFirstChild("Main") and PlayerGui.Main:FindFirstChild("Skills")
    if Skills then
        for _, f in pairs(Skills:GetChildren()) do
            if f:IsA("Frame") and f.Visible and f:FindFirstChild(key) then
                local mobileBtn = f[key]:FindFirstChild("Mobile")
                if mobileBtn then return mobileBtn end
            end
        end
    end
    return nil
end

-- 5. FUNGSI MEMBACA PROPERTI
local function GetButtonState(btn)
    local state = {}
    
    -- Properti Utama
    state.Color = btn.BackgroundColor3
    state.Transparency = btn.BackgroundTransparency
    state.Size = btn.Size
    state.Visible = btn.Visible
    
    -- Cek Anak-anaknya (Overlay, Timer, Cooldown Frame)
    state.Children = {}
    for _, child in pairs(btn:GetChildren()) do
        if child:IsA("GuiObject") then
            state.Children[child.Name] = {
                Visible = child.Visible,
                Transparency = child.BackgroundTransparency,
                Color = child.BackgroundColor3
            }
        end
    end
    
    return state
end

local function AddLog(text, color)
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.TextColor3 = color or Color3.new(1,1,1)
    lbl.Size = UDim2.new(1, -10, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 11
    lbl.Parent = LogFrame
end

-- 6. LOGIKA UTAMA (SCAN & COMPARE)
local ReadyState = nil
local CurrentStep = 1 -- 1: Scan Ready, 2: Scan Cooldown, 3: Reset

ScanBtn.MouseButton1Click:Connect(function()
    local keyName = InputBox.Text
    local targetBtn = FindButton(keyName)
    
    if not targetBtn then
        StatusLbl.Text = "Error: Tombol " .. keyName .. " tidak ditemukan!"
        StatusLbl.TextColor3 = Color3.fromRGB(255, 50, 50)
        return
    end
    
    if CurrentStep == 1 then
        -- TAHAP 1: SIMPAN DATA READY
        ReadyState = GetButtonState(targetBtn)
        
        -- Bersihkan Log Lama
        for _, c in pairs(LogFrame:GetChildren()) do 
            if c:IsA("TextLabel") then c:Destroy() end 
        end
        
        AddLog(">> [READY] State Captured!", Color3.fromRGB(0, 255, 255))
        AddLog("Warna Awal: " .. tostring(ReadyState.Color), Color3.fromRGB(200, 200, 200))
        
        ScanBtn.Text = "2. PAKAI SKILL -> KLIK SAAT CD"
        ScanBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 0) -- Orange
        CurrentStep = 2
        
    elseif CurrentStep == 2 then
        -- TAHAP 2: BANDINGKAN DENGAN SAAT INI (COOLDOWN)
        local CooldownState = GetButtonState(targetBtn)
        local FoundDifference = false
        
        AddLog("--------------------------------", Color3.new(1,1,1))
        AddLog(">> HASIL PERBANDINGAN:", Color3.fromRGB(255, 255, 0))
        
        -- 1. Cek Perubahan Warna
        if ReadyState.Color ~= CooldownState.Color then
            AddLog("[!] WARNA BERUBAH!", Color3.fromRGB(255, 100, 100))
            AddLog("    Dari: " .. tostring(ReadyState.Color), Color3.fromRGB(200,200,200))
            AddLog("    Jadi: " .. tostring(CooldownState.Color), Color3.fromRGB(200,200,200))
            FoundDifference = true
        else
            AddLog("[-] Warna TIDAK berubah.", Color3.fromRGB(100, 255, 100))
        end
        
        -- 2. Cek Transparansi
        if math.abs(ReadyState.Transparency - CooldownState.Transparency) > 0.01 then
            AddLog("[!] TRANSPARANSI BERUBAH!", Color3.fromRGB(255, 100, 100))
            AddLog("    Dari: " .. ReadyState.Transparency .. " Jadi: " .. CooldownState.Transparency)
            FoundDifference = true
        end

        -- 3. Cek Anak Baru / Overlay (Cooldown Frame)
        for name, data in pairs(CooldownState.Children) do
            local oldData = ReadyState.Children[name]
            
            if not oldData then
                AddLog("[+] OBJECT BARU MUNCUL: " .. name, Color3.fromRGB(255, 100, 100))
                FoundDifference = true
            elseif not oldData.Visible and data.Visible then
                AddLog("[!] OBJECT JADI VISIBLE: " .. name, Color3.fromRGB(255, 100, 100))
                FoundDifference = true
            end
        end
        
        if not FoundDifference then
            AddLog("TIDAK ADA PERUBAHAN VISUAL TERDETEKSI", Color3.fromRGB(150, 150, 150))
        end
        
        ScanBtn.Text = "RESET (ULANGI)"
        ScanBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        CurrentStep = 3
        
    elseif CurrentStep == 3 then
        -- RESET
        ReadyState = nil
        ScanBtn.Text = "1. SCAN READY STATE"
        ScanBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        for _, c in pairs(LogFrame:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
        CurrentStep = 1
    end
end)

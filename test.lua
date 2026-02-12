-- [[ UI INSPECTOR: JUMP BUTTON ANALYZER ]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- 1. SETUP UI (DRAGGABLE)
if CoreGui:FindFirstChild("JumpInspector") then CoreGui.JumpInspector:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JumpInspector"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 250, 0, 280)
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0) -- Posisi awal di kiri
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderColor3 = Color3.fromRGB(0, 255, 255) -- Cyan Border
MainFrame.BorderSizePixel = 2
MainFrame.Parent = ScreenGui

-- Header (Drag Area)
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 30)
Header.BackgroundColor3 = Color3.fromRGB(0, 150, 150)
Header.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "JUMP BTN INSPECTOR (DRAG)"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.Parent = Header

-- Input Nama Tombol
local NameInput = Instance.new("TextBox")
NameInput.Size = UDim2.new(0.9, 0, 0, 30)
NameInput.Position = UDim2.new(0.05, 0, 0.15, 0)
NameInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
NameInput.Text = "Jump" -- Default search text
NameInput.PlaceholderText = "Search Name (e.g. Jump)"
NameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
NameInput.Parent = MainFrame

-- Info Label
local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(0.9, 0, 0.7, 0)
InfoLabel.Position = UDim2.new(0.05, 0, 0.28, 0)
InfoLabel.BackgroundTransparency = 1
InfoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.TextYAlignment = Enum.TextYAlignment.Top
InfoLabel.Font = Enum.Font.Code
InfoLabel.TextSize = 11
InfoLabel.TextWrapped = true
InfoLabel.Text = "Searching..."
InfoLabel.Parent = MainFrame

-- [[ LOGIKA DRAGGABLE ]]
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- [[ FUNGSI PENCARI ]]
-- Mencari tombol secara rekursif di PlayerGui
local function FindObjectByName(parent, name)
    for _, child in pairs(parent:GetChildren()) do
        if child:IsA("GuiObject") and (string.find(child.Name:lower(), name:lower())) then
            -- Prioritaskan yang visible
            if child.Visible then return child end
        end
        -- Cari di anak-anaknya (Recursive)
        local found = FindObjectByName(child, name)
        if found then return found end
    end
    return nil
end

-- [[ LOOP MONITORING ]]
local function FormatColor(c3)
    return string.format("%d, %d, %d", math.floor(c3.R*255), math.floor(c3.G*255), math.floor(c3.B*255))
end

RunService.RenderStepped:Connect(function()
    local searchKey = NameInput.Text
    local PGui = LocalPlayer:FindFirstChild("PlayerGui")
    
    if not PGui then return end
    
    -- Coba cari di TouchGui dulu (Default Roblox)
    local target = nil
    local touchGui = PGui:FindFirstChild("TouchGui")
    if touchGui then
        target = FindObjectByName(touchGui, searchKey)
    end
    
    -- Jika tidak ketemu, cari di seluruh PlayerGui
    if not target then
        target = FindObjectByName(PGui, searchKey)
    end
    
    if target then
        local info = "FOUND: " .. target.Name .. "\n"
        info = info .. "Path: " .. target.Parent.Name .. "." .. target.Name .. "\n\n"
        
        info = info .. "[VARIABLES]\n"
        
        -- Cek Warna (Ini yang paling sering berubah saat ditekan)
        if target:IsA("ImageButton") or target:IsA("ImageLabel") then
            info = info .. "ImgColor: " .. FormatColor(target.ImageColor3) .. "\n"
            info = info .. "ImgTrans: " .. string.format("%.2f", target.ImageTransparency) .. "\n"
        end
        
        info = info .. "BgColor: " .. FormatColor(target.BackgroundColor3) .. "\n"
        info = info .. "BgTrans: " .. string.format("%.2f", target.BackgroundTransparency) .. "\n"
        
        -- Cek Posisi & Ukuran (Penting untuk VIM click)
        info = info .. "AbsPos: " .. tostring(target.AbsolutePosition) .. "\n"
        info = info .. "AbsSize: " .. tostring(target.AbsoluteSize) .. "\n"
        
        -- Cek State
        info = info .. "Active: " .. tostring(target.Active) .. "\n"
        if target:IsA("GuiButton") then
            -- Cek apakah sedang ditekan secara visual (Style)
            info = info .. "Style: " .. tostring(target.Style) .. "\n"
        end
        
        InfoLabel.Text = info
        InfoLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- Hijau = Ketemu
    else
        InfoLabel.Text = "Searching for '"..searchKey.."'...\n\nNot Found.\nTry names like:\n- Jump\n- JumpButton\n- MobileJump\n- ActionButton"
        InfoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

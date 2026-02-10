--[[
    VELOX SAFE AUTO TAP (NO STUCK)
    Fitur:
    - Mengetuk area "Jempol Kanan" (Combat Zone).
    - Metode: Force Release -> Tap -> Release.
    - Menggunakan Jari ID 9 (Aman dari Analog).
]]

local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera

if CoreGui:FindFirstChild("VeloxTap") then
    CoreGui.VeloxTap:Destroy()
end

-- GUI SETUP
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VeloxTap"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 160, 0, 60)
MainFrame.Position = UDim2.new(0.5, -80, 0.15, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local Stroke = Instance.new("UIStroke"); Stroke.Color=Color3.fromRGB(255, 0, 0); Stroke.Parent=MainFrame

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, 0, 1, 0)
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.Text = "AUTO ATTACK: OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.TextSize = 14
ToggleBtn.Parent = MainFrame

-- ==============================================================================
-- [LOGIKA ANTI-STUCK]
-- ==============================================================================

local IsAttacking = false

task.spawn(function()
    while true do
        if IsAttacking then
            -- 1. TENTUKAN POSISI AMAN (JEMPOL KANAN)
            -- Kita ambil 80% ke kanan, 60% ke bawah. Area kosong buat combat.
            local X = Camera.ViewportSize.X * 0.8
            local Y = Camera.ViewportSize.Y * 0.6
            
            pcall(function()
                -- STEP A: PAKSA LEPAS DULU (Reset State)
                -- Ini kunci agar tidak "nyangkut" atau "diam"
                VirtualInputManager:SendTouchEvent(9, 1, X, Y) 
                
                RunService.RenderStepped:Wait() -- Tunggu 1 frame
                
                -- STEP B: TEKAN (TouchStart)
                VirtualInputManager:SendTouchEvent(9, 0, X, Y)
                
                RunService.RenderStepped:Wait() -- Tunggu 1 frame
                
                -- STEP C: LEPAS (TouchEnd)
                VirtualInputManager:SendTouchEvent(9, 1, X, Y)
            end)
        end
        
        -- COOLDOWN AMAN (Agar animasi attack sempat jalan)
        -- Jangan ubah jadi 0, nanti game tidak sempat render animasi pukulan
        task.wait(0.15) 
    end
end)

-- Event Toggle
ToggleBtn.MouseButton1Click:Connect(function()
    IsAttacking = not IsAttacking
    
    if IsAttacking then
        ToggleBtn.Text = "AUTO ATTACK: ON"
        Stroke.Color = Color3.fromRGB(0, 255, 0)
        ToggleBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
    else
        ToggleBtn.Text = "AUTO ATTACK: OFF"
        Stroke.Color = Color3.fromRGB(255, 0, 0)
        ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        
        -- Safety: Paksa lepas saat dimatikan
        pcall(function()
            local X = Camera.ViewportSize.X * 0.8
            local Y = Camera.ViewportSize.Y * 0.6
            VirtualInputManager:SendTouchEvent(9, 1, X, Y)
        end)
    end
end)

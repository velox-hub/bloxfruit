--[[
    VELOX GHOST TOUCH (AUTO CLICKER)
    Fitur:
    - Mengetuk tengah layar (Center).
    - Menggunakan Touch ID 10 (Tidak mengganggu Analog/Jari kamu).
    - UI Toggle On/Off.
]]

local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera

-- 1. BERSIHKAN UI LAMA
if CoreGui:FindFirstChild("GhostClicker") then
    CoreGui.GhostClicker:Destroy()
end

-- 2. SETUP UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GhostClicker"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 150, 0, 50)
MainFrame.Position = UDim2.new(0.5, -75, 0.15, 0) -- Di atas tengah
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.Active = true
MainFrame.Draggable = true -- Bisa digeser
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(255, 0, 0)

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, 0, 1, 0)
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.Text = "AUTO TAP: OFF 🔴"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 14
ToggleBtn.Parent = MainFrame

-- ==============================================================================
-- [LOGIKA GHOST TOUCH]
-- ==============================================================================

local IsAutoClicking = false

-- Fungsi Tap Tengah Layar
local function DoGhostTap()
    -- Ambil koordinat tengah layar persis
    local CenterX = Camera.ViewportSize.X / 2
    local CenterY = Camera.ViewportSize.Y / 2
    
    -- KOREKSI POSISI (Opsional):
    -- Sedikit digeser ke kanan (+50) agar tidak kena chat box atau kepala karakter
    -- Jika ingin pas tengah, hapus +50 nya.
    local SafeX = CenterX + 50 
    local SafeY = CenterY
    
    -- ID 10 = Jari Hantu (Agar tidak bentrok dengan Analog ID 0)
    -- 0 = TouchStart (Tekan)
    VirtualInputManager:SendTouchEvent(10, 0, SafeX, SafeY)
    
    -- Tidak perlu wait lama, langsung lepas biar cepat (Fast Attack)
    -- 1 = TouchEnd (Lepas)
    VirtualInputManager:SendTouchEvent(10, 1, SafeX, SafeY)
end

-- Loop Eksekusi
task.spawn(function()
    while true do
        if IsAutoClicking then
            DoGhostTap()
        end
        -- Kecepatan Tap (0.1 = Sangat Cepat, tapi aman)
        -- Jangan set 0 agar HP tidak panas/crash
        task.wait(0.1) 
    end
end)

-- Event Tombol
ToggleBtn.MouseButton1Click:Connect(function()
    IsAutoClicking = not IsAutoClicking
    
    if IsAutoClicking then
        ToggleBtn.Text = "AUTO TAP: ON 🟢"
        MainFrame.BackgroundColor3 = Color3.fromRGB(0, 100, 0) -- Hijau
        MainFrame.UIStroke.Color = Color3.fromRGB(0, 255, 0)
    else
        ToggleBtn.Text = "AUTO TAP: OFF 🔴"
        MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20) -- Hitam
        MainFrame.UIStroke.Color = Color3.fromRGB(255, 0, 0)
    end
end)

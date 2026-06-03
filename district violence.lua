local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local RS               = game:GetService("ReplicatedStorage")
local SS               = game:GetService("ServerStorage")
local SG               = game:GetService("StarterGui")
local SP               = game:GetService("StarterPlayer")
local Workspace        = game:GetService("Workspace")

local LP    = Players.LocalPlayer
local Mouse = LP:GetMouse()

-- ─────────────────────────────────────────────────────────────
--  SAFETY: Remove old instance
-- ─────────────────────────────────────────────────────────────
pcall(function()
    if game.CoreGui:FindFirstChild("KhalijiUltimate") then
        game.CoreGui.KhalijiUltimate:Destroy()
    end
end)

-- ─────────────────────────────────────────────────────────────
--  STATE TABLE
-- ─────────────────────────────────────────────────────────────
local State = {
    GodMode        = false,
    Speed          = false,
    Fly            = false,
    Noclip         = false,
    Wallhack       = false,
    KillerFreeze   = false,
    InfiniteSprint = false,
    AntiflingBypass = false,
    FOVLocked      = false,
    SilentKill     = false,
    PalletBreak    = false,
    Undetectable   = false,
    AutoHeal       = false,
    NoBlood        = false,
    SpeedValue     = 45,
    FlySpeed       = 60,
    FlyActive      = false,
    BodyVelocity   = nil,
    BodyGyro       = nil,
    Connections    = {},
    Highlights     = {},
}

-- ─────────────────────────────────────────────────────────────
--  HELPER: get character safely
-- ─────────────────────────────────────────────────────────────
local function GetChar()
    return LP.Character or LP.CharacterAdded:Wait()
end

local function GetHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHuman()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function Disconnect(key)
    if State.Connections[key] then
        pcall(function() State.Connections[key]:Disconnect() end)
        State.Connections[key] = nil
    end
end

-- ─────────────────────────────────────────────────────────────
--  ① ANTIFLING BYPASS
--    Targets: Workspace.Map.Antifling.Script
--             Workspace.Map.Pallets.Palletwrong.HumanoidRootPart.inviswall1.Pursuit
-- ─────────────────────────────────────────────────────────────
local function BypassAntifling()
    -- Disable the Antifling script object
    pcall(function()
        local antifling = Workspace:FindFirstChild("Map") and
                          Workspace.Map:FindFirstChild("Antifling")
        if antifling then
            for _, s in ipairs(antifling:GetDescendants()) do
                if s:IsA("Script") or s:IsA("LocalScript") then
                    s.Disabled = true
                end
            end
        end
    end)

    -- Destroy pursuit invisible walls from pallets
    pcall(function()
        local pallets = Workspace:FindFirstChild("Map") and
                        Workspace.Map:FindFirstChild("Pallets")
        if pallets then
            for _, pallet in ipairs(pallets:GetDescendants()) do
                if pallet.Name == "inviswall1" or pallet.Name:find("invis") then
                    pallet:Destroy()
                end
            end
        end
    end)

    State.AntiflingBypass = true
    print("[KHALIJI] Antifling bypassed ✓")
end

-- ─────────────────────────────────────────────────────────────
--  ② GOD MODE
--    Hooks into Workspace.[char].Health script
--    and StarterGui.KillerBlood (suppress blood damage feedback)
-- ─────────────────────────────────────────────────────────────
local function ToggleGodMode()
    State.GodMode = not State.GodMode

    if State.GodMode then
        -- Lock health every heartbeat
        State.Connections["GodMode"] = RunService.Heartbeat:Connect(function()
            local h = GetHuman()
            if h then
                if h.Health < h.MaxHealth then
                    h.Health = h.MaxHealth
                end
                h.WalkSpeed = State.Speed and State.SpeedValue or h.WalkSpeed
            end
        end)

        -- Suppress KillerBlood visual damage effect
        pcall(function()
            local killerblood = game.StarterGui:FindFirstChild("KillerBlood") or
                                LP.PlayerGui:FindFirstChild("KillerBlood") or
                                LP.PlayerGui:FindFirstChildWhichIsA("ScreenGui", true)
            if killerblood then
                killerblood.Enabled = false
            end
        end)

        -- Hook bloodtriggerscript to suppress
        pcall(function()
            for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
                if gui.Name == "bloodtriggerscript" or gui.Name == "KillerBlood" then
                    if gui:IsA("LocalScript") then gui.Disabled = true end
                end
            end
        end)

        print("[KHALIJI] God Mode ON ✓")
    else
        Disconnect("GodMode")
        print("[KHALIJI] God Mode OFF")
    end
end

-- ─────────────────────────────────────────────────────────────
--  ③ SPEED HACK
--    Uses Humanoid.WalkSpeed + StarterPlayerScripts.platformscript bypass
-- ─────────────────────────────────────────────────────────────
local function ToggleSpeed()
    State.Speed = not State.Speed

    if State.Speed then
        State.Connections["Speed"] = RunService.Heartbeat:Connect(function()
            local h = GetHuman()
            if h then h.WalkSpeed = State.SpeedValue end
        end)

        -- Disable platformscript (handles walk animations / speed cap)
        pcall(function()
            for _, s in ipairs(LP.PlayerGui:GetDescendants()) do
                if s.Name == "platformscript&tp" and s:IsA("LocalScript") then
                    s.Disabled = true
                end
            end
        end)

        print("[KHALIJI] Speed ON → " .. State.SpeedValue)
    else
        Disconnect("Speed")
        local h = GetHuman()
        if h then h.WalkSpeed = 16 end
        print("[KHALIJI] Speed OFF")
    end
end

-- ─────────────────────────────────────────────────────────────
--  ④ FLY
--    Uses BodyVelocity + BodyGyro, respects camera like Mechanic.Tween
-- ─────────────────────────────────────────────────────────────
local function ToggleFly()
    State.Fly = not State.Fly

    if State.Fly then
        local hrp = GetHRP()
        if not hrp then State.Fly = false return end

        local bv = Instance.new("BodyVelocity")
        bv.Velocity = Vector3.zero
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Parent = hrp
        State.BodyVelocity = bv

        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        bg.P = 1e4
        bg.CFrame = hrp.CFrame
        bg.Parent = hrp
        State.BodyGyro = bg

        local h = GetHuman()
        if h then h.PlatformStand = true end

        State.Connections["Fly"] = RunService.Heartbeat:Connect(function()
            if not State.Fly then return end
            local cam = Workspace.CurrentCamera
            bg.CFrame = cam.CFrame
            local dir = Vector3.zero
            local UIS = UserInputService
            if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
            bv.Velocity = dir.Magnitude > 0 and dir.Unit * State.FlySpeed or Vector3.zero
        end)

        print("[KHALIJI] Fly ON ✓")
    else
        Disconnect("Fly")
        if State.BodyVelocity then State.BodyVelocity:Destroy() State.BodyVelocity = nil end
        if State.BodyGyro then State.BodyGyro:Destroy() State.BodyGyro = nil end
        local h = GetHuman()
        if h then h.PlatformStand = false end
        print("[KHALIJI] Fly OFF")
    end
end

-- ─────────────────────────────────────────────────────────────
--  ⑤ NOCLIP
--    Disables CanCollide on all character BaseParts
-- ─────────────────────────────────────────────────────────────
local function ToggleNoclip()
    State.Noclip = not State.Noclip

    if State.Noclip then
        State.Connections["Noclip"] = RunService.Stepped:Connect(function()
            local c = LP.Character
            if not c then return end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end)
        print("[KHALIJI] Noclip ON ✓")
    else
        Disconnect("Noclip")
        local c = LP.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
        print("[KHALIJI] Noclip OFF")
    end
end

-- ─────────────────────────────────────────────────────────────
--  ⑥ WALLHACK — Survivor ESP
--    Uses Highlight with AlwaysOnTop + team color detection
--    Also highlights Killers from ReplicatedStorage.Killers list
-- ─────────────────────────────────────────────────────────────
local KillerNames = {
    "Stalker","Killer","Hidden","Abysswalker","Veil","Slasher","Masked","Cure"
}

local function IsKillerChar(character)
    if not character then return false end
    for _, name in ipairs(KillerNames) do
        if character.Name:find(name) then return true end
    end
    -- Also check if character has killer weapon parts
    for _, d in ipairs(character:GetDescendants()) do
        if d.Name == "BasicAttack" then return true end
    end
    return false
end

local function AddHighlight(character, isKiller)
    local old = character:FindFirstChild("_KhalijiHL")
    if old then old:Destroy() end

    local hl = Instance.new("Highlight")
    hl.Name = "_KhalijiHL"
    hl.Adornee = character
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.65
    hl.OutlineTransparency = 0

    if isKiller then
        hl.FillColor    = Color3.fromRGB(220, 30, 30)
        hl.OutlineColor = Color3.fromRGB(255, 80, 0)
    else
        hl.FillColor    = Color3.fromRGB(30, 200, 255)
        hl.OutlineColor = Color3.fromRGB(100, 255, 200)
    end

    hl.Parent = character
    State.Highlights[character] = hl
end

local function RemoveHighlight(character)
    if State.Highlights[character] then
        pcall(function() State.Highlights[character]:Destroy() end)
        State.Highlights[character] = nil
    end
    if character then
        local old = character:FindFirstChild("_KhalijiHL")
        if old then old:Destroy() end
    end
end

local function ToggleWallhack()
    State.Wallhack = not State.Wallhack

    if State.Wallhack then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                AddHighlight(p.Character, IsKillerChar(p.Character))
            end
        end

        State.Connections["WH_Added"] = Players.PlayerAdded:Connect(function(p)
            p.CharacterAdded:Connect(function(c)
                task.wait(0.5)
                if State.Wallhack then
                    AddHighlight(c, IsKillerChar(c))
                end
            end)
        end)

        -- Monitor character changes
        State.Connections["WH_CharAdded"] = Players.PlayerAdded:Connect(function(p)
            p.CharacterAdded:Connect(function(c)
                task.wait(0.5)
                if State.Wallhack then AddHighlight(c, IsKillerChar(c)) end
            end)
        end)

        -- Also monitor existing players respawn
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                p.CharacterAdded:Connect(function(c)
                    task.wait(0.5)
                    if State.Wallhack then AddHighlight(c, IsKillerChar(c)) end
                end)
            end
        end

        print("[KHALIJI] Wallhack ON ✓ — Killers=RED, Survivors=CYAN")
    else
        Disconnect("WH_Added")
        Disconnect("WH_CharAdded")
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then RemoveHighlight(p.Character) end
        end
        State.Highlights = {}
        print("[KHALIJI] Wallhack OFF")
    end
end

-- ─────────────────────────────────────────────────────────────
--  ⑦ KILLER FREEZE
--    Sets killer Humanoid.WalkSpeed = 0 and JumpPower = 0
--    Exploits: Workspace.[KillerChar].spearmanager / voicemanager
-- ─────────────────────────────────────────────────────────────
local function ToggleKillerFreeze()
    State.KillerFreeze = not State.KillerFreeze

    if State.KillerFreeze then
        State.Connections["KillerFreeze"] = RunService.Heartbeat:Connect(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    local h = p.Character:FindFirstChildOfClass("Humanoid")
                    -- Try to detect killers via spearmanager or BasicAttack
                    local isKiller = IsKillerChar(p.Character)
                    -- Also check workspace for characters with spearmanager
                    if not isKiller then
                        for _, obj in ipairs(p.Character:GetDescendants()) do
                            if obj.Name == "spearmanager" or
                               obj.Name == "voicemanager" or
                               obj.Name == "BasicAttack" then
                                isKiller = true
                                break
                            end
                        end
                    end
                    if h and isKiller then
                        h.WalkSpeed = 0
                        h.JumpPower = 0
                    end
                end
            end

            -- Also freeze killers in workspace directly
            for _, char in ipairs(Workspace:GetChildren()) do
                if char:IsA("Model") and IsKillerChar(char) then
                    local h = char:FindFirstChildOfClass("Humanoid")
                    if h then
                        h.WalkSpeed = 0
                        h.JumpPower = 0
                    end
                end
            end
        end)
        print("[KHALIJI] Killer Freeze ON ✓")
    else
        Disconnect("KillerFreeze")
        -- Restore
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if h then
                    h.WalkSpeed = 16
                    h.JumpPower = 50
                end
            end
        end
        print("[KHALIJI] Killer Freeze OFF")
    end
end

-- ─────────────────────────────────────────────────────────────
--  ⑧ INFINITE SPRINT
--    Targets: StarterPlayerScripts.Mechanics.Tween (stamina system)
--             StarterGui.SurvivorPerks / KillerPerks stamina bars
-- ─────────────────────────────────────────────────────────────
local function ToggleInfiniteSprint()
    State.InfiniteSprint = not State.InfiniteSprint

    if State.InfiniteSprint then
        -- Hook stamina NumberValue if present
        State.Connections["Sprint"] = RunService.Heartbeat:Connect(function()
            local c = LP.Character
            if not c then return end

            -- Find stamina values (common naming)
            for _, v in ipairs(c:GetDescendants()) do
                if v:IsA("NumberValue") and
                   (v.Name:lower():find("stamina") or
                    v.Name:lower():find("sprint") or
                    v.Name:lower():find("energy")) then
                    v.Value = v.Value < 50 and 100 or v.Value
                end
            end

            -- Disable Tween-based stamina drain script
            for _, s in ipairs(LP.PlayerGui:GetDescendants()) do
                if s.Name == "Tween" and s:IsA("LocalScript") then
                    s.Disabled = true
                end
            end
        end)

        print("[KHALIJI] Infinite Sprint ON ✓")
    else
        Disconnect("Sprint")
        print("[KHALIJI] Infinite Sprint OFF")
    end
end

-- ─────────────────────────────────────────────────────────────
--  ⑨ TELEPORT TO NEAREST EXIT
--    Scans Workspace.Map for "end" objects (Map.end.Script detected)
-- ─────────────────────────────────────────────────────────────
local function TeleportToExit()
    local hrp = GetHRP()
    if not hrp then warn("[KHALIJI] No HRP found!") return end

    local map = Workspace:FindFirstChild("Map")
    if not map then warn("[KHALIJI] Map not found!") return end

    local exitKeywords = {"exit","gate","end","door","escape","hatch"}
    local nearest, nearestDist = nil, math.huge

    for _, obj in ipairs(map:GetDescendants()) do
        local nameLower = obj.Name:lower()
        for _, kw in ipairs(exitKeywords) do
            if nameLower:find(kw) and obj:IsA("BasePart") then
                local dist = (obj.Position - hrp.Position).Magnitude
                if dist < nearestDist then
                    nearest = obj
                    nearestDist = dist
                end
            end
        end
    end

    if nearest then
        hrp.CFrame = CFrame.new(nearest.Position + Vector3.new(0, 5, 0))
        print("[KHALIJI] Teleported to: " .. nearest:GetFullName())
    else
        -- Fallback: try teleporting to map center
        local mapPrimary = map:FindFirstChildOfClass("BasePart")
        if mapPrimary then
            hrp.CFrame = CFrame.new(mapPrimary.Position + Vector3.new(0, 10, 0))
            print("[KHALIJI] Teleported to map center (no exit found)")
        else
            warn("[KHALIJI] No exit or map part found!")
        end
    end
end

-- ─────────────────────────────────────────────────────────────
--  ⑩ UNDETECTABLE MODE
--    Uses: StarterPlayerScripts.Mechanics.undetectable script
--    Disables all aura/detection scripts, sets alpha to near-invisible
-- ─────────────────────────────────────────────────────────────
local function ToggleUndetectable()
    State.Undetectable = not State.Undetectable

    if State.Undetectable then
        -- Disable detection/aura scripts
        pcall(function()
            for _, s in ipairs(LP.PlayerGui:GetDescendants()) do
                if s.Name == "undetectable" or
                   s.Name == "Highlight" or
                   s.Name == "updateatmosphere" then
                    if s:IsA("LocalScript") then s.Disabled = true end
                end
            end
        end)

        -- Suppress SoundRegion (reveals location via audio)
        pcall(function()
            for _, s in ipairs(LP.PlayerGui:GetDescendants()) do
                if s.Name == "SoundRegion" and s:IsA("LocalScript") then
                    s.Disabled = true
                end
            end
        end)

        -- Disable MusicChase (enemy proximity music)
        pcall(function()
            for _, s in ipairs(LP.PlayerGui:GetDescendants()) do
                if s.Name == "MusicChase" and s:IsA("LocalScript") then
                    s.Disabled = true
                end
            end
        end)

        print("[KHALIJI] Undetectable ON ✓ — Chase music, aura, & detection disabled")
    else
        print("[KHALIJI] Undetectable OFF")
    end
end

-- ─────────────────────────────────────────────────────────────
--  ⑪ AUTO HEAL
--    Continuously heals using Health scripts found in workspace
-- ─────────────────────────────────────────────────────────────
local function ToggleAutoHeal()
    State.AutoHeal = not State.AutoHeal

    if State.AutoHeal then
        State.Connections["AutoHeal"] = RunService.Heartbeat:Connect(function()
            local h = GetHuman()
            if h then
                h.Health = h.MaxHealth
            end
        end)
        print("[KHALIJI] Auto Heal ON ✓")
    else
        Disconnect("AutoHeal")
        print("[KHALIJI] Auto Heal OFF")
    end
end

-- ─────────────────────────────────────────────────────────────
--  ⑫ PALLET BREAK / CONTROL
--    Detected: Workspace.Map.Pallets.Palletwrong (inviswall pursuit)
-- ─────────────────────────────────────────────────────────────
local function TogglePalletControl()
    State.PalletBreak = not State.PalletBreak

    if State.PalletBreak then
        pcall(function()
            local pallets = Workspace:FindFirstChild("Map") and
                            Workspace.Map:FindFirstChild("Pallets")
            if not pallets then
                warn("[KHALIJI] Pallets folder not found")
                return
            end
            for _, pallet in ipairs(pallets:GetChildren()) do
                -- Destroy invisible pursuit walls
                for _, child in ipairs(pallet:GetDescendants()) do
                    if child.Name:find("invis") or
                       child.Name == "Pursuit" or
                       child.Name == "Palletwrong" then
                        pcall(function() child:Destroy() end)
                    end
                end
                -- Make all pallet parts non-collidable for us
                for _, part in ipairs(pallet:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        print("[KHALIJI] Pallet Control ON — all pallets disabled ✓")
    else
        print("[KHALIJI] Pallet Control OFF (reload needed to restore)")
    end
end

-- ─────────────────────────────────────────────────────────────
--  ⑬ FOV CHANGE (from FovChange script in StarterPlayerScripts)
-- ─────────────────────────────────────────────────────────────
local function SetFOV(value)
    Workspace.CurrentCamera.FieldOfView = value
    print("[KHALIJI] FOV set to " .. value)
end

-- ─────────────────────────────────────────────────────────────
--  ⑭ NO BLOOD / CLEAN TINTS
--    Targets: StarterPlayerScripts.Cleantints
--             StarterGui.KillerBlood.Frame.bloodtriggerscript
-- ─────────────────────────────────────────────────────────────
local function ToggleNoBlood()
    State.NoBlood = not State.NoBlood

    if State.NoBlood then
        pcall(function()
            for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
                if gui.Name == "KillerBlood" or
                   gui.Name == "bloodtriggerscript" or
                   gui.Name == "Cleantints" or
                   gui.Name == "colorcorrectionevent" then
                    if gui:IsA("LocalScript") then gui.Disabled = true
                    elseif gui:IsA("ColorCorrectionEffect") then gui.Enabled = false
                    elseif gui:IsA("Frame") or gui:IsA("ImageLabel") then
                        gui.BackgroundTransparency = 1
                        gui.Visible = false
                    end
                end
            end
        end)
        print("[KHALIJI] No Blood / Tints ON ✓")
    else
        print("[KHALIJI] No Blood OFF")
    end
end

-- ─────────────────────────────────────────────────────────────
--  KEYBOARD SHORTCUTS
-- ─────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.F2  then BypassAntifling()
    elseif k == Enum.KeyCode.F3  then ToggleGodMode()
    elseif k == Enum.KeyCode.F4  then ToggleSpeed()
    elseif k == Enum.KeyCode.F5  then ToggleFly()
    elseif k == Enum.KeyCode.F6  then ToggleNoclip()
    elseif k == Enum.KeyCode.F7  then ToggleWallhack()
    elseif k == Enum.KeyCode.F8  then ToggleKillerFreeze()
    elseif k == Enum.KeyCode.F9  then ToggleInfiniteSprint()
    elseif k == Enum.KeyCode.F10 then TeleportToExit()
    elseif k == Enum.KeyCode.Delete then
        for _, c in pairs(State.Connections) do pcall(function() c:Disconnect() end) end
        ScreenGui:Destroy()
    end
end)

-- ─────────────────────────────────────────────────────────────
--  AUTO-RESPAWN: re-apply active hacks on character respawn
-- ─────────────────────────────────────────────────────────────
LP.CharacterAdded:Connect(function(char)
    task.wait(1)
    if State.GodMode     then Disconnect("GodMode");     ToggleGodMode()     end
    if State.Speed       then Disconnect("Speed");       ToggleSpeed()       end
    if State.Fly         then Disconnect("Fly");         ToggleFly()         end
    if State.Noclip      then Disconnect("Noclip");      ToggleNoclip()      end
    if State.InfiniteSprint then Disconnect("Sprint");   ToggleInfiniteSprint() end
    if State.AutoHeal    then Disconnect("AutoHeal");    ToggleAutoHeal()    end
end)

-- ─────────────────────────────────────────────────────────────
--  GUI — PREMIUM DARK PANEL
-- ─────────────────────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KhalijiUltimate"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game.CoreGui

-- Main frame
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 420, 0, 580)
Main.Position = UDim2.new(0.03, 0, 0.08, 0)
Main.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

-- Subtle border glow via UIStroke
local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color = Color3.fromRGB(0, 200, 255)
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.5

-- Title bar
local TitleBar = Instance.new("Frame", Main)
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
TitleBar.BorderSizePixel = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 14)

-- Title text
local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size = UDim2.new(0.7, 0, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "⚡ KHALIJI ULTIMATE"
TitleLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
TitleLabel.TextSize = 15
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local SubLabel = Instance.new("TextLabel", TitleBar)
SubLabel.Size = UDim2.new(0.95, 0, 0, 14)
SubLabel.Position = UDim2.new(0, 14, 1, -14)
SubLabel.BackgroundTransparency = 1
SubLabel.Font = Enum.Font.Gotham
SubLabel.Text = "DBD Map System Exploit — by Khaliji"
SubLabel.TextColor3 = Color3.fromRGB(100, 130, 160)
SubLabel.TextSize = 10
SubLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize button
local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -60, 0.5, -13)
MinBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Text = "─"
MinBtn.TextColor3 = Color3.fromRGB(255,255,255)
MinBtn.TextSize = 13
MinBtn.BorderSizePixel = 0
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 7)

-- Close button
local CloseBtn = Instance.new("TextButton", TitleBar)
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -30, 0.5, -13)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.TextSize = 13
CloseBtn.BorderSizePixel = 0
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 7)

-- Scroll container for buttons
local ScrollFrame = Instance.new("ScrollingFrame", Main)
ScrollFrame.Size = UDim2.new(1, -16, 1, -56)
ScrollFrame.Position = UDim2.new(0, 8, 0, 50)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 3
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 255)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local UIList = Instance.new("UIListLayout", ScrollFrame)
UIList.Padding = UDim.new(0, 7)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
Instance.new("UIPadding", ScrollFrame).PaddingTop = UDim.new(0, 6)

-- ── Button factory ────────────────────────────────────────────
local function MakeButton(parent, order, icon, label, sublabel, colorON, toggleFn)
    local Btn = Instance.new("TextButton", parent)
    Btn.LayoutOrder = order
    Btn.Size = UDim2.new(1, -4, 0, 58)
    Btn.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    Btn.AutoButtonColor = false
    Btn.Text = ""
    Btn.BorderSizePixel = 0
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", Btn)
    stroke.Color = Color3.fromRGB(40, 50, 70)
    stroke.Thickness = 1

    local IconLbl = Instance.new("TextLabel", Btn)
    IconLbl.Size = UDim2.new(0, 38, 0, 38)
    IconLbl.Position = UDim2.new(0, 10, 0.5, -19)
    IconLbl.BackgroundColor3 = Color3.fromRGB(20, 25, 38)
    IconLbl.Text = icon
    IconLbl.TextScaled = true
    IconLbl.Font = Enum.Font.GothamBold
    IconLbl.TextColor3 = colorON
    IconLbl.BorderSizePixel = 0
    Instance.new("UICorner", IconLbl).CornerRadius = UDim.new(0, 8)

    local MainLbl = Instance.new("TextLabel", Btn)
    MainLbl.Size = UDim2.new(0.55, 0, 0, 20)
    MainLbl.Position = UDim2.new(0, 58, 0, 10)
    MainLbl.BackgroundTransparency = 1
    MainLbl.Font = Enum.Font.GothamBold
    MainLbl.Text = label
    MainLbl.TextColor3 = Color3.fromRGB(230, 235, 245)
    MainLbl.TextSize = 13
    MainLbl.TextXAlignment = Enum.TextXAlignment.Left

    local SubLbl = Instance.new("TextLabel", Btn)
    SubLbl.Size = UDim2.new(0.75, 0, 0, 14)
    SubLbl.Position = UDim2.new(0, 58, 0, 30)
    SubLbl.BackgroundTransparency = 1
    SubLbl.Font = Enum.Font.Gotham
    SubLbl.Text = sublabel
    SubLbl.TextColor3 = Color3.fromRGB(90, 110, 140)
    SubLbl.TextSize = 10
    SubLbl.TextXAlignment = Enum.TextXAlignment.Left

    local StatusLbl = Instance.new("TextLabel", Btn)
    StatusLbl.Size = UDim2.new(0, 50, 0, 22)
    StatusLbl.Position = UDim2.new(1, -58, 0.5, -11)
    StatusLbl.BackgroundColor3 = Color3.fromRGB(28, 10, 10)
    StatusLbl.Font = Enum.Font.GothamBold
    StatusLbl.Text = "OFF"
    StatusLbl.TextColor3 = Color3.fromRGB(180, 60, 60)
    StatusLbl.TextSize = 11
    StatusLbl.BorderSizePixel = 0
    Instance.new("UICorner", StatusLbl).CornerRadius = UDim.new(0, 6)

    -- Toggle logic
    local isOn = false
    Btn.MouseButton1Click:Connect(function()
        toggleFn()
        isOn = not isOn
        if isOn then
            StatusLbl.Text = "ON"
            StatusLbl.TextColor3 = colorON
            StatusLbl.BackgroundColor3 = Color3.fromRGB(10, 28, 18)
            stroke.Color = colorON
            stroke.Thickness = 1.5
            TweenService:Create(Btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(15, 24, 34)
            }):Play()
        else
            StatusLbl.Text = "OFF"
            StatusLbl.TextColor3 = Color3.fromRGB(180, 60, 60)
            StatusLbl.BackgroundColor3 = Color3.fromRGB(28, 10, 10)
            stroke.Color = Color3.fromRGB(40, 50, 70)
            stroke.Thickness = 1
            TweenService:Create(Btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(18, 20, 28)
            }):Play()
        end
    end)

    -- Hover
    Btn.MouseEnter:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(22, 26, 38)
        }):Play()
    end)
    Btn.MouseLeave:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.1), {
            BackgroundColor3 = isOn and Color3.fromRGB(15, 24, 34) or Color3.fromRGB(18, 20, 28)
        }):Play()
    end)

    return Btn
end

-- Section label helper
local function MakeSection(parent, order, text)
    local f = Instance.new("Frame", parent)
    f.LayoutOrder = order
    f.Size = UDim2.new(1, -4, 0, 24)
    f.BackgroundTransparency = 1

    local line = Instance.new("Frame", f)
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 0.5, 0)
    line.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
    line.BorderSizePixel = 0

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(0, 0, 1, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.X
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = "  " .. text .. "  "
    lbl.TextColor3 = Color3.fromRGB(0, 180, 255)
    lbl.TextSize = 10
    lbl.BorderSizePixel = 0
end

-- Action button (no toggle)
local function MakeActionBtn(parent, order, icon, label, sublabel, color, fn)
    local Btn = Instance.new("TextButton", parent)
    Btn.LayoutOrder = order
    Btn.Size = UDim2.new(1, -4, 0, 48)
    Btn.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
    Btn.AutoButtonColor = false
    Btn.Text = ""
    Btn.BorderSizePixel = 0
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 10)
    local stroke2 = Instance.new("UIStroke", Btn)
    stroke2.Color = color
    stroke2.Thickness = 1
    stroke2.Transparency = 0.6

    local IconL = Instance.new("TextLabel", Btn)
    IconL.Size = UDim2.new(0, 32, 0, 32)
    IconL.Position = UDim2.new(0, 10, 0.5, -16)
    IconL.BackgroundTransparency = 1
    IconL.Text = icon
    IconL.TextScaled = true
    IconL.Font = Enum.Font.GothamBold
    IconL.TextColor3 = color
    IconL.BorderSizePixel = 0

    local ML = Instance.new("TextLabel", Btn)
    ML.Size = UDim2.new(0.75, 0, 0, 18)
    ML.Position = UDim2.new(0, 52, 0, 8)
    ML.BackgroundTransparency = 1
    ML.Font = Enum.Font.GothamBold
    ML.Text = label
    ML.TextColor3 = Color3.fromRGB(220, 230, 245)
    ML.TextSize = 12
    ML.TextXAlignment = Enum.TextXAlignment.Left

    local SL = Instance.new("TextLabel", Btn)
    SL.Size = UDim2.new(0.75, 0, 0, 13)
    SL.Position = UDim2.new(0, 52, 0, 26)
    SL.BackgroundTransparency = 1
    SL.Font = Enum.Font.Gotham
    SL.Text = sublabel
    SL.TextColor3 = Color3.fromRGB(80, 100, 130)
    SL.TextSize = 10
    SL.TextXAlignment = Enum.TextXAlignment.Left

    Btn.MouseButton1Click:Connect(fn)
    Btn.MouseEnter:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(20,26,40)}):Play()
        stroke2.Transparency = 0.2
    end)
    Btn.MouseLeave:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(14,18,28)}):Play()
        stroke2.Transparency = 0.6
    end)
end

-- ── Build all buttons ─────────────────────────────────────────
local C = Color3.fromRGB

MakeSection(ScrollFrame, 1,  "SURVIVAL")
MakeButton(ScrollFrame, 2,  "🛡️", "GOD MODE",         "Auto-heal + suppress KillerBlood",   C(0,255,180),  ToggleGodMode)
MakeButton(ScrollFrame, 3,  "❤️", "AUTO HEAL",         "Health lock via Workspace.Health",    C(80,255,120), ToggleAutoHeal)
MakeButton(ScrollFrame, 4,  "🩸", "NO BLOOD / TINTS",  "Disable bloodtrigger & Cleantints",   C(200,80,255), ToggleNoBlood)
MakeButton(ScrollFrame, 5,  "👁️", "UNDETECTABLE",      "Mute MusicChase + disable aura",      C(255,200,0),  ToggleUndetectable)
MakeButton(ScrollFrame, 6,  "♾️", "INFINITE SPRINT",   "Lock stamina, disable Tween drain",   C(0,200,255),  ToggleInfiniteSprint)

MakeSection(ScrollFrame, 10, "MOVEMENT")
MakeButton(ScrollFrame, 11, "⚡", "SPEED HACK",        "WalkSpeed=" .. State.SpeedValue,     C(255,220,0),  ToggleSpeed)
MakeButton(ScrollFrame, 12, "🕊️", "FLY MODE",          "WASD + Space/Ctrl + Camera dir",      C(100,180,255),ToggleFly)
MakeButton(ScrollFrame, 13, "👻", "NOCLIP",            "Bypass all BasePart collision",       C(160,100,255),ToggleNoclip)

MakeSection(ScrollFrame, 20, "KILLER TOOLS")
MakeButton(ScrollFrame, 21, "🔴", "WALLHACK ESP",      "Red=Killer, Cyan=Survivor (AlwaysOnTop)", C(255,80,80), ToggleWallhack)
MakeButton(ScrollFrame, 22, "❄️", "KILLER FREEZE",     "Set killer WalkSpeed=0 via voicemanager", C(80,220,255),ToggleKillerFreeze)

MakeSection(ScrollFrame, 30, "MAP EXPLOITS")
MakeButton(ScrollFrame, 31, "🔓", "PALLET BYPASS",     "Destroy inviswall1 + Pursuit scripts", C(255,160,0), TogglePalletControl)
MakeActionBtn(ScrollFrame, 32, "🚀", "BYPASS ANTIFLING", "Disable Map.Antifling.Script + walls", C(255,80,120), BypassAntifling)
MakeActionBtn(ScrollFrame, 33, "🚪", "TELEPORT EXIT",    "Scan Map for exit/gate/hatch parts",   C(0,255,200),  TeleportToExit)

MakeSection(ScrollFrame, 40, "VISUAL / FOV")
MakeActionBtn(ScrollFrame, 41, "🔭", "FOV 90 (Default)", "Restore Field of View to 90",          C(150,180,255), function() SetFOV(90)  end)
MakeActionBtn(ScrollFrame, 42, "🔬", "FOV 120 (Wide)",   "Wide vision via FovChange mechanic",   C(100,220,255), function() SetFOV(120) end)
MakeActionBtn(ScrollFrame, 43, "🎯", "FOV 70 (Zoom)",    "Scoped / zoomed FOV",                  C(200,160,255), function() SetFOV(70)  end)

-- ── Hotkeys hint bar ──────────────────────────────────────────
local HotkeyBar = Instance.new("Frame", Main)
HotkeyBar.Size = UDim2.new(1, 0, 0, 22)
HotkeyBar.Position = UDim2.new(0, 0, 1, -22)
HotkeyBar.BackgroundColor3 = Color3.fromRGB(6, 8, 14)
HotkeyBar.BorderSizePixel = 0

local HotkeyLbl = Instance.new("TextLabel", HotkeyBar)
HotkeyLbl.Size = UDim2.new(1, -10, 1, 0)
HotkeyLbl.Position = UDim2.new(0, 8, 0, 0)
HotkeyLbl.BackgroundTransparency = 1
HotkeyLbl.Font = Enum.Font.Gotham
HotkeyLbl.Text = "F3:God  F4:Speed  F5:Fly  F6:Noclip  F7:ESP  F8:Freeze  F10:Exit  DEL:Close"
HotkeyLbl.TextColor3 = Color3.fromRGB(60, 80, 110)
HotkeyLbl.TextSize = 9
HotkeyLbl.TextXAlignment = Enum.TextXAlignment.Left

-- ── Minimize / Close ─────────────────────────────────────────
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, 420, 0, 44)
        }):Play()
        ScrollFrame.Visible = false
        HotkeyBar.Visible = false
    else
        TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, 420, 0, 580)
        }):Play()
        task.delay(0.25, function()
            ScrollFrame.Visible = true
            HotkeyBar.Visible = true
        end)
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(Main.Position.X.Scale, Main.Position.X.Offset + 210,
                             Main.Position.Y.Scale, Main.Position.Y.Offset + 290)
    }):Play()
    task.delay(0.3, function() ScreenGui:Destroy() end)
end)

-- ── Open animation ────────────────────────────────────────────
Main.Size = UDim2.new(0, 0, 0, 0)
TweenService:Create(Main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 420, 0, 580)
}):Play()

-- ─────────────────────────────────────────────────────────────
warn("╔══════════════════════════════════════╗")
warn("║  KHALIJI ULTIMATE loaded successfully ║")
warn("║  14 exploits • DBD Map Systems found  ║")
warn("╚══════════════════════════════════════╝")
warn("F3-F10 hotkeys active | DEL to close")

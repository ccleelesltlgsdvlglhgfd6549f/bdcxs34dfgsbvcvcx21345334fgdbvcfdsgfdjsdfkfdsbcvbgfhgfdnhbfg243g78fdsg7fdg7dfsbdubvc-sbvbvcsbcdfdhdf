--[[
    lina's stand | Fling (commands only, no UI)
    Type !help in chat to print the command list to the F9 console.
    Saved files (workspace): lina.cc_fling_whitelist.json, lina.cc_fling_loop.json, lina.cc_fling_settings.json
    (file names kept the same so old saved data is not lost)
]]

if not game:IsLoaded() then game.Loaded:Wait() end

-- Loader lock: getgenv().Script must contain "discord.gg/standd" or the script does nothing
do
    local s = getgenv().Script
    if type(s) ~= "string" or not s:find("discord.gg/standd", 1, true) then return end
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local SCRIPT_NAME = "lina's stand"
getgenv().LinaStandGen = (getgenv().LinaStandGen or 0) + 1
local MY_GEN = getgenv().LinaStandGen
local function alive() return getgenv().LinaStandGen == MY_GEN end

local function HRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function Hum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function sendGameChat(message)
    if type(message) ~= "string" or message == "" then return end
    local sent = false
    pcall(function()
        local channel = TextChatService.TextChannels and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if channel then
            channel:SendAsync(message)
            sent = true
        end
    end)
    if sent then return end
    pcall(function()
        local chatEvents = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
        local say = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")
        if say then say:FireServer(message, "All") end
    end)
end

local Aim = { Bone = "Head", WallCheck = true }

local function hasKnife(parent)
    if not parent then return false end
    for _, t in ipairs(parent:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("knife", 1, true) then return true end
    end
    return false
end
local function isMurdererPlayer(p)
    if not p or p == LocalPlayer or not p.Parent then return false end
    return hasKnife(p.Character) or hasKnife(p:FindFirstChildOfClass("Backpack"))
end
local function hasGun(parent)
    if not parent then return false end
    for _, t in ipairs(parent:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("gun", 1, true) then return true end
    end
    return false
end

local function doInfo(say, isWhitelistedFn)
    local mPlayer, mSelf = nil, false
    if hasKnife(LocalPlayer.Character) or hasKnife(LocalPlayer:FindFirstChildOfClass("Backpack")) then
        mSelf = true
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and (hasKnife(p.Character) or hasKnife(p:FindFirstChildOfClass("Backpack"))) then
                mPlayer = p
                break
            end
        end
    end
    local sPlayer, sSelf = nil, false
    if hasGun(LocalPlayer.Character) or hasGun(LocalPlayer:FindFirstChildOfClass("Backpack")) then
        sSelf = true
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and (hasGun(p.Character) or hasGun(p:FindFirstChildOfClass("Backpack"))) then
                sPlayer = p
                break
            end
        end
    end
    local function label(p, isSelf)
        if isSelf then return LocalPlayer.Name .. " (you)" end
        if not p then return "unknown" end
        if isWhitelistedFn and isWhitelistedFn(p) then return "whitelisted" end
        return p.Name
    end
    local mName = label(mPlayer, mSelf)
    local sName = label(sPlayer, sSelf)
    say("murderer: " .. mName, "Info")
    say("sheriff: " .. sName, "Info")
    print("[" .. SCRIPT_NAME .. "] murderer: " .. mName .. " | sheriff: " .. sName)
    sendGameChat("murderer:" .. mName .. "  sheriff:" .. sName)
end

local function getMurdererPlayer()
    for _, p in ipairs(Players:GetPlayers()) do
        if isMurdererPlayer(p) then return p end
    end
    return nil
end
local function isLocalMurderer()
    return hasKnife(LocalPlayer.Character) or hasKnife(LocalPlayer:FindFirstChildOfClass("Backpack"))
end
local function localKnife()
    local c = LocalPlayer.Character
    if not c then return nil end
    for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("knife", 1, true) then return t end
    end
    return nil
end
local function targetPart(char)
    if not char then return nil end
    if Aim.Bone == "Head" then return char:FindFirstChild("Head") end
    return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
end
local function equippedGun()
    local c = LocalPlayer.Character
    if not c then return nil end
    for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("gun", 1, true) then return t end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find("gun", 1, true) then
                local h = Hum()
                if h then pcall(function() h:EquipTool(t) end) task.wait(0.1) end
                return c:FindFirstChild(t.Name)
            end
        end
    end
    return nil
end
local function shootRemote(gun)
    if not gun then return nil end
    local e = gun:FindFirstChild("Shoot")
    if e and e:IsA("RemoteEvent") then return e end
    local ev = gun:FindFirstChild("Events")
    if ev then
        local e2 = ev:FindFirstChild("Shoot")
        if e2 and e2:IsA("RemoteEvent") then return e2 end
    end
    for _, d in ipairs(gun:GetDescendants()) do
        if d.Name == "Shoot" and d:IsA("RemoteEvent") then return d end
    end
    return nil
end
local function predict(part, shooterPart)
    if not part then return nil end
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if not ok or not ping then ping = 0.05 end
    local relativeVel = part.AssemblyLinearVelocity
    if shooterPart then relativeVel = relativeVel - shooterPart.AssemblyLinearVelocity end
    return CFrame.new(part.Position + relativeVel * (ping * 1.15))
end
local function charFromPart(part)
    local cur = part
    while cur and cur ~= workspace do
        if cur:IsA("Model") then
            local p = Players:GetPlayerFromCharacter(cur)
            if p then return p end
        end
        cur = cur.Parent
    end
    return nil
end
local function pathHit(from, to, tChar)
    local dir = to - from
    local dist = dir.Magnitude
    if dist < 0.5 then return "clear" end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { workspace.CurrentCamera }
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    if tChar then
        for _, part in ipairs(tChar:GetDescendants()) do
            if part:IsA("Accessory") or part:IsA("Accoutrement") then table.insert(ignore, part) end
        end
    end
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    local res = workspace:Raycast(from, dir.Unit * (dist + 1), params)
    if not res then return "clear" end
    if tChar and (res.Instance:IsDescendantOf(tChar) or res.Instance == tChar) then return "target" end
    local hp = charFromPart(res.Instance)
    if hp and hp ~= LocalPlayer and not isMurdererPlayer(hp) then return "innocent" end
    return "wall"
end
local function canShoot(from, to, tChar)
    local hit = pathHit(from, to, tChar)
    if hit == "innocent" then return false end
    if not Aim.WallCheck then return true end
    return hit ~= "wall"
end
local function fireAt(part, plr)
    if plr and not isMurdererPlayer(plr) then return false end
    local gun = equippedGun()
    if not gun then return false end
    local rem = shootRemote(gun)
    if not rem then return false end
    local my = HRP()
    if not my then return false end
    if not canShoot(my.Position, part.Position, plr and plr.Character) then return false end
    local cf = predict(part, my) or CFrame.new(part.Position)
    return pcall(function() rem:FireServer(my.CFrame, cf) end)
end
local function findGunDrop()
    for _, o in ipairs(workspace:GetChildren()) do
        if o:IsA("BasePart") and o.Name:lower():find("gundrop") then return o end
        if o:IsA("Model") then
            local f = o:FindFirstChild("GunDrop", true)
            if f and f:IsA("BasePart") then return f end
        end
    end
    return workspace:FindFirstChild("GunDrop", true)
end
local function grabGun(obj)
    task.spawn(function()
        local start = tick()
        while obj and obj.Parent and (tick() - start) < 5 do
            local c = LocalPlayer.Character
            if not c then break end
            if equippedGun() then break end
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildOfClass("BasePart") or obj:FindFirstChildWhichIsA("BasePart", true)
            if not part then break end
            for _, n in ipairs({ "HumanoidRootPart", "RightHand", "LeftHand" }) do
                local b = c:FindFirstChild(n)
                if b then
                    pcall(function() firetouchinterest(part, b, 0) end)
                    task.wait(0.02)
                    pcall(function() firetouchinterest(part, b, 1) end)
                end
            end
            task.wait(0.1)
        end
    end)
end
local function pressSlot1()
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.One, false, game)
        task.wait(0.05)
        vim:SendKeyEvent(false, Enum.KeyCode.One, false, game)
    end)
end
local function killAllAura()
    local knife = localKnife()
    if not knife then
        pressSlot1()
        task.wait(0.2)
        knife = localKnife()
    end
    if not knife then
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") and t.Name:lower():find("knife", 1, true) then
                    pressSlot1()
                    task.wait(0.3)
                    knife = localKnife()
                    if not knife then
                        local h = Hum()
                        if h then pcall(function() h:EquipTool(t) end) end
                        task.wait(0.3)
                        knife = localKnife()
                    end
                    break
                end
            end
        end
    end
    if not knife then return false end
    local ev = knife:FindFirstChild("Events")
    if not ev then return false end
    local stab = ev:FindFirstChild("KnifeStabbed")
    local touch = ev:FindFirstChild("HandleTouched")
    if not stab or not touch then return false end
    local saved = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local h = p.Character:FindFirstChild("HumanoidRootPart")
            if h then
                saved[p] = { size = h.Size, trans = h.Transparency, coll = h.CanCollide }
                h.Size = Vector3.new(60, 60, 60)
                h.Transparency = 1
                h.CanCollide = false
            end
        end
    end
    local start = tick()
    task.spawn(function()
        while tick() - start < 5 do
            pcall(function() stab:FireServer() end)
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local ph = p.Character:FindFirstChildOfClass("Humanoid")
                    if ph and ph.Health > 0 then
                        for _, part in ipairs(p.Character:GetChildren()) do
                            if part:IsA("BasePart") then pcall(function() touch:FireServer(part) end) end
                        end
                    end
                end
            end
            task.wait(0.03)
        end
        for p, data in pairs(saved) do
            if p.Character then
                local h = p.Character:FindFirstChild("HumanoidRootPart")
                if h then
                    h.Size = data.size
                    h.Transparency = data.trans
                    h.CanCollide = data.coll
                end
            end
        end
    end)
    return true
end

-- ===================== NO RENDER SCREEN =====================
-- FarmOn = true  -> old screen (black + "join .gg/standd" + role + "total collected: N")
-- FarmOn = false -> new rainbow ".gg/standd" pattern screen (+ role in the middle)
local NR = {
    On = false, FarmOn = false, Count = 0,
    Frame = nil, Label = nil, CountLabel = nil, Rainbow = nil, RoleLabel = nil,
    Gui = nil, Conn = nil, Orig = nil,
}

-- Shows/hides the right pieces depending on NoRender on/off and autofarm on/off.
function NR.applyMode()
    local on, farm = NR.On, NR.FarmOn
    if NR.Frame then NR.Frame.Visible = on end
    if NR.FpsLabel then NR.FpsLabel.Visible = on end
    if NR.Label then NR.Label.Visible = on and farm end
    if NR.CountLabel then NR.CountLabel.Visible = on and farm end
    if NR.Rainbow then NR.Rainbow.Visible = on and not farm end
    if NR.RoleLabel then
        NR.RoleLabel.Visible = on
        if farm then
            NR.RoleLabel.Size = UDim2.new(1, 0, 0, 36)
            NR.RoleLabel.Position = UDim2.new(0.5, 0, 0.5, 52)
        else
            NR.RoleLabel.Size = UDim2.new(0, 260, 0, 44)
            NR.RoleLabel.Position = UDim2.fromScale(0.5, 0.5)
        end
        NR.RoleLabel.BackgroundTransparency = 1
    end
end

function NR.setCount(n)
    NR.Count = n or 0
    if NR.CountLabel then
        NR.CountLabel.Text = "total collected: " .. tostring(NR.Count)
    end
end

local function killFx(v)
    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
        v.Enabled = false
    end
end

local function setNoRender(state)
    NR.On = state and true or false
    NR.applyMode()
    pcall(function() RunService:Set3dRenderingEnabled(not NR.On) end)
    if NR.On then
        if not NR.Orig then
            NR.Orig = {
                Quality = settings().Rendering.QualityLevel,
                Shadows = Lighting.GlobalShadows,
            }
        end
        pcall(function() settings().Rendering.QualityLevel = 1 end)
        Lighting.GlobalShadows = false
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        for _, v in ipairs(workspace:GetDescendants()) do killFx(v) end
        if not NR.Conn then NR.Conn = workspace.DescendantAdded:Connect(killFx) end
    else
        if NR.Conn then NR.Conn:Disconnect() NR.Conn = nil end
        if NR.Orig then
            pcall(function() settings().Rendering.QualityLevel = NR.Orig.Quality end)
            Lighting.GlobalShadows = NR.Orig.Shadows
        end
    end
end

-- ===== ".gg/standd" grid (NoRender screen while autofarm is off) =====
-- Parallel grid that covers the whole screen. Every cell types the text in, holds it, erases it
-- backwards and types it again, all in sync (no cursor line). One shared 30 Hz loop that only
-- touches the labels when a letter actually changes, so it stays light even with many cells.
local RB = {
    TEXT = ".gg/standd", TEXT_SIZE = 22, CELL_W = 150, CELL_H = 38, MAX_CELLS = 150,
    SATURATION = 0.55, COLOR_SPEED = 0.05,
    TYPE_DELAY = 0.09, ERASE_DELAY = 0.05, HOLD = 1.6, PAUSE = 0.5,
    cells = {}, container = nil, started = false, viewKey = "", k = 0,
}

local function rbTextWidth()
    local w = #RB.TEXT * RB.TEXT_SIZE * 0.6
    pcall(function()
        w = game:GetService("TextService"):GetTextSize(RB.TEXT, RB.TEXT_SIZE, Enum.Font.Code, Vector2.new(1000, 1000)).X
    end)
    return w
end

local function rbLayout()
    local c = RB.container
    if not c then return end
    local view = c.AbsoluteSize
    if view.X < 200 or view.Y < 200 then
        local cam = workspace.CurrentCamera
        if cam then view = cam.ViewportSize end
    end
    local key = math.floor(view.X) .. "x" .. math.floor(view.Y)
    if key == RB.viewKey and #RB.cells > 0 then return end
    RB.viewKey = key

    for _, cell in ipairs(RB.cells) do pcall(function() cell.label:Destroy() end) end
    RB.cells = {}

    local w, h = RB.CELL_W, RB.CELL_H
    local cols = math.max(math.floor(view.X / w), 1)
    local rows = math.max(math.floor(view.Y / h), 1)
    while cols * rows > RB.MAX_CELLS do
        w, h = w * 1.15, h * 1.15
        cols = math.max(math.floor(view.X / w), 1)
        rows = math.max(math.floor(view.Y / h), 1)
    end
    local padX = (view.X - cols * w) / 2
    local padY = (view.Y - rows * h) / 2
    local textW = rbTextWidth()
    local inX = (w - textW) / 2

    for r = 0, rows - 1 do
        for col = 0, cols - 1 do
            local hue = (r + col) / (rows + cols)
            local label = Instance.new("TextLabel")
            label.Size = UDim2.fromOffset(textW + 6, h)
            label.Position = UDim2.fromOffset(padX + col * w + inX, padY + r * h)
            label.BackgroundTransparency = 1
            label.Text = RB.TEXT
            label.TextColor3 = Color3.fromHSV(hue, RB.SATURATION, 1)
            label.TextSize = RB.TEXT_SIZE
            label.Font = Enum.Font.Code
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.TextYAlignment = Enum.TextYAlignment.Center
            label.TextTransparency = 0.1
            label.TextStrokeTransparency = 1
            label.MaxVisibleGraphemes = RB.k
            label.Active = false
            label.Selectable = false
            label.ZIndex = 11
            label.Parent = c
            RB.cells[#RB.cells + 1] = { label = label, hue = hue }
        end
    end
end

local function buildRainbow(gui)
    local container = Instance.new("Frame")
    container.Size = UDim2.fromScale(1, 1)
    container.BackgroundTransparency = 1
    container.Active = false
    container.ZIndex = 11
    container.Parent = gui
    RB.container = container
    RB.cells = {}
    RB.viewKey = ""
    rbLayout()
    return container
end

local function rbSetVisible(k)
    RB.k = k
    for _, cell in ipairs(RB.cells) do cell.label.MaxVisibleGraphemes = k end
end

local function rbStart()
    if RB.started then return end
    RB.started = true
    task.spawn(function()
        local n = #RB.TEXT
        local phase, nextAt, colorAt = "type", 0, 0
        while alive() do
            task.wait(0.03)
            -- only works while the NoRender screen is on and autofarm is off;
            -- when NoRender is turned off the container is hidden and 3D comes back
            if NR.On and not NR.FarmOn and RB.container and RB.container.Parent then
                rbLayout()
                local now = tick()
                if now >= nextAt then
                    if phase == "type" then
                        rbSetVisible(math.min(RB.k + 1, n))
                        if RB.k >= n then
                            phase, nextAt = "hold", now + RB.HOLD
                        else
                            nextAt = now + RB.TYPE_DELAY
                        end
                    elseif phase == "hold" then
                        phase, nextAt = "erase", now
                    elseif phase == "erase" then
                        rbSetVisible(math.max(RB.k - 1, 0))
                        if RB.k <= 0 then
                            phase, nextAt = "pause", now + RB.PAUSE
                        else
                            nextAt = now + RB.ERASE_DELAY
                        end
                    else
                        phase, nextAt = "type", now
                    end
                end
                if now >= colorAt then
                    colorAt = now + 0.25
                    local shift = now * RB.COLOR_SPEED
                    for _, cell in ipairs(RB.cells) do
                        cell.label.TextColor3 = Color3.fromHSV((shift + cell.hue) % 1, RB.SATURATION, 1)
                    end
                end
            end
        end
    end)
end

local function buildNoRenderGui()
    local guiParent
    pcall(function() if gethui then guiParent = gethui() end end)
    if not guiParent then pcall(function() guiParent = game:GetService("CoreGui") end) end
    if not guiParent then guiParent = PlayerGui end

    for _, par in ipairs({ guiParent, PlayerGui }) do
        local old = par and par:FindFirstChild("NoRender")
        if old then pcall(function() old:Destroy() end) end
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NoRender"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 100
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    gui.Parent = guiParent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BorderSizePixel = 0
    frame.ZIndex = 10
    frame.Visible = NR.On
    frame.Parent = gui

    -- OLD screen (shown while autofarm is on): invite text + role + total collected
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 60)
    label.Position = UDim2.new(0, 0, 0.5, -30)
    label.BackgroundTransparency = 1
    label.Text = "join .gg/standd"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.ZIndex = 11
    label.Visible = false
    label.Parent = gui

    local countLabel = Instance.new("TextLabel")
    countLabel.Size = UDim2.new(1, 0, 0, 32)
    countLabel.Position = UDim2.new(0, 0, 0.5, 76)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "total collected: " .. tostring(NR.Count)
    countLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
    countLabel.TextScaled = true
    countLabel.Font = Enum.Font.GothamBold
    countLabel.ZIndex = 11
    countLabel.Visible = false
    countLabel.Parent = gui

    -- NEW screen (shown when autofarm is off): rainbow pattern
    local rainbow = buildRainbow(gui)
    rainbow.Visible = false

    -- Role text: dark translucent box in rainbow mode, plain text under the invite in farm mode
    -- (applyMode adjusts size/position/background for the active mode)
    local roleLabel = Instance.new("TextLabel")
    roleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    roleLabel.Size = UDim2.new(0, 260, 0, 44)
    roleLabel.Position = UDim2.fromScale(0.5, 0.5)
    roleLabel.BackgroundTransparency = 1
    roleLabel.Text = ""
    roleLabel.TextColor3 = Color3.fromRGB(90, 230, 90)
    roleLabel.TextScaled = true
    roleLabel.Font = Enum.Font.GothamBold
    roleLabel.ZIndex = 12
    roleLabel.Visible = false
    roleLabel.Parent = gui

    -- FPS counter (top right of the NoRender screen)
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.AnchorPoint = Vector2.new(1, 0)
    fpsLabel.Size = UDim2.fromOffset(140, 26)
    fpsLabel.Position = UDim2.new(1, -12, 0, 8)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Text = "fps: --"
    fpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    fpsLabel.TextSize = 18
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Right
    fpsLabel.Font = Enum.Font.Code
    fpsLabel.ZIndex = 12
    fpsLabel.Visible = NR.On
    fpsLabel.Parent = gui
    NR.FpsLabel = fpsLabel

    NR.Gui, NR.Frame, NR.Label, NR.CountLabel, NR.Rainbow, NR.RoleLabel = gui, frame, label, countLabel, rainbow, roleLabel
    NR.applyMode()
    rbStart()
end

buildNoRenderGui()
setNoRender(getgenv().DisableRendering ~= false)

do
    local cap = tonumber(getgenv().FPSCap)
    if cap and cap >= 0 and type(setfpscap) == "function" then pcall(setfpscap, cap) end
end

do
    local frames, acc = 0, 0
    RunService.Heartbeat:Connect(function(dt)
        if not alive() then return end
        frames += 1
        acc += dt
        if acc >= 0.5 then
            if NR.FpsLabel then NR.FpsLabel.Text = "fps: " .. math.floor(frames / acc + 0.5) end
            frames, acc = 0, 0
        end
    end)
end

task.spawn(function()
    while alive() do
        task.wait(2)
        if NR.On then
            if not (NR.Gui and NR.Gui.Parent) then pcall(buildNoRenderGui) end
            NR.applyMode()
            pcall(function() RunService:Set3dRenderingEnabled(false) end)
        end
    end
end)

-- Keeps the NoRender role line updated: green "innocent", red "murderer", blue "sheriff".
local function ownsGunNow()
    return hasGun(LocalPlayer.Character) or hasGun(LocalPlayer:FindFirstChildOfClass("Backpack"))
end
task.spawn(function()
    while alive() do
        task.wait(0.5)
        if NR.RoleLabel then
            if isLocalMurderer() then
                NR.RoleLabel.Text = "murderer"
                NR.RoleLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
            elseif ownsGunNow() then
                NR.RoleLabel.Text = "sheriff"
                NR.RoleLabel.TextColor3 = Color3.fromRGB(80, 160, 255)
            else
                NR.RoleLabel.Text = "innocent"
                NR.RoleLabel.TextColor3 = Color3.fromRGB(90, 230, 90)
            end
        end
    end
end)

do
    local vu = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end)
end

local OasisUI = {}
function OasisUI:Notify(o)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = o.Title or SCRIPT_NAME,
            Text = string.sub(tostring(o.Content or ""), 1, 200),
            Duration = o.Duration or 3,
        })
    end)
end
local function notifySay(content, typ)
    OasisUI:Notify({ Title = SCRIPT_NAME, Content = content, Type = typ or "Info", Duration = 3 })
end

local F = {
    Targets = {},
    Whitelist = {},
    WhitelistFriends = false,
    ChatCmd = true,
    Time = 7,
    OldPos = nil,
    FPDH = workspace.FallenPartsDestroyHeight,
    friendCache = {},
    lastCmd = {},
    SaveFile = "lina.cc_fling_whitelist.json",

    queue = {},
    Loop = {},
    SelActive = false,
    AllActive = false,
    gen = 0,
    rr = 0,
    dirty = false,
    Paused = false,
    LoopFile = "lina.cc_fling_loop.json",
    TP_USERID = nil, -- set from getgenv().Owner (username) below
    MainName = nil,
    Void = false, VoidPos = nil, VoidReturn = nil, voidConn = nil, busy = false,
    VoidWanted = true,
    cmdBusy = 0,
    voidReturnAt = 0,
    bringGen = 0,
    Stand = { On = false, TargetName = nil, Conn = nil, PrevDance = nil },
    AutoBringActive = false, AutoBringTarget = nil, BringBusy = false,
    FollowMode = false,
    AutoInfo = false,
}

-- getgenv().Owner = "username": that account can command this client (resolved to a UserId)
do
    local owner = getgenv().Owner
    if type(owner) == "string" and owner ~= "" and owner ~= "YOUR_USERNAME_THERE" then
        task.spawn(function()
            local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(owner) end)
            if ok and type(id) == "number" then
                F.TP_USERID = id
                notifySay("Owner set: " .. owner, "Info")
            else
                notifySay("Owner not found: " .. owner, "Warning")
            end
        end)
    end
end

function F.loadSaved()
    local ok, names = pcall(function()
        if type(isfile) == "function" and isfile(F.SaveFile) then
            return HttpService:JSONDecode(readfile(F.SaveFile))
        end
    end)
    if ok and type(names) == "table" then
        for _, name in ipairs(names) do
            if type(name) == "string" then F.Whitelist[name] = true end
        end
    end
end
function F.save()
    if type(writefile) ~= "function" then return end
    local names = {}
    for name in pairs(F.Whitelist) do table.insert(names, name) end
    pcall(function() writefile(F.SaveFile, HttpService:JSONEncode(names)) end)
end
F.loadSaved()

function F.loadLoop()
    local ok, names = pcall(function()
        if type(isfile) == "function" and isfile(F.LoopFile) then
            return HttpService:JSONDecode(readfile(F.LoopFile))
        end
    end)
    if ok and type(names) == "table" then
        for _, name in ipairs(names) do
            if type(name) == "string" then F.Loop[name] = true end
        end
    end
end
function F.saveLoop()
    if type(writefile) ~= "function" then return end
    local names = {}
    for name in pairs(F.Loop) do table.insert(names, name) end
    pcall(function() writefile(F.LoopFile, HttpService:JSONEncode(names)) end)
end
F.loadLoop()

function F.loopList()
    local t = {}
    for name in pairs(F.Loop) do table.insert(t, name) end
    table.sort(t, function(a, b) return a:lower() < b:lower() end)
    return t
end

function F.removeName(tbl, name)
    local lower = name:lower()
    local removed = false
    for k in pairs(tbl) do
        if k:lower() == lower then tbl[k] = nil removed = true end
    end
    return removed
end

function F.whitelistList()
    local t = {}
    for name in pairs(F.Whitelist) do table.insert(t, name) end
    table.sort(t, function(a, b) return a:lower() < b:lower() end)
    return t
end

function F.names()
    local seen, t = {}, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not seen[p.Name] then
            seen[p.Name] = true
            table.insert(t, p.Name)
        end
    end
    for _, tbl in ipairs({ F.Whitelist, F.Loop }) do
        for name in pairs(tbl) do
            if not seen[name] then
                seen[name] = true
                table.insert(t, name)
            end
        end
    end
    table.sort(t, function(a, b) return a:lower() < b:lower() end)
    return t
end

function F.isFriend(p)
    local cached = F.friendCache[p.UserId]
    if cached ~= nil then return cached end
    local ok, res = pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end)
    F.friendCache[p.UserId] = ok and res or false
    return F.friendCache[p.UserId]
end

-- Case-insensitive on purpose: if the whitelist was typed with slightly different capitalization
-- than the player's actual username, an exact-case lookup would silently never match, and every
-- command from that (supposedly whitelisted) player would be ignored with no error shown anywhere.
function F.isWhitelisted(p)
    local target = p.Name:lower()
    for name in pairs(F.Whitelist) do
        if name:lower() == target then return true end
    end
    if F.WhitelistFriends and F.isFriend(p) then return true end
    return false
end

function F.cleanup()
    workspace.FallenPartsDestroyHeight = F.FPDH
    local hrp = HRP()
    if hrp then
        local bv = hrp:FindFirstChild("LinaFlingBV")
        if bv then bv:Destroy() end
        local bav = hrp:FindFirstChild("LinaFlingBAV")
        if bav then bav:Destroy() end
    end
    local h = Hum()
    if h then
        h:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        workspace.CurrentCamera.CameraSubject = h
    end
end

function F.fling(target, gen)
    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart
    local TCharacter = target.Character
    if not (Character and Humanoid and RootPart and TCharacter) then return end

    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")

    if THumanoid and THumanoid.Sit then return end
    if not TCharacter:FindFirstChildWhichIsA("BasePart") then return end

    local part = TRootPart or THead or Handle
    if not part then return end

    RootPart.Velocity = Vector3.zero
    RootPart.RotVelocity = Vector3.zero
    RootPart.CanCollide = true -- must actually collide with the target or none of this transfers force
    F.OldPos = RootPart.CFrame

    if THead then
        workspace.CurrentCamera.CameraSubject = THead
    elseif Handle then
        workspace.CurrentCamera.CameraSubject = Handle
    elseif THumanoid and TRootPart then
        workspace.CurrentCamera.CameraSubject = THumanoid
    end

    workspace.FallenPartsDestroyHeight = 0 / 0
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    -- Classic KILASIK-style fling: a single loop sets CFrame AND a one-shot huge
    -- Velocity/RotVelocity together, every tick. The previous version drove a
    -- continuous BodyVelocity/BodyAngularVelocity on TWO separate connections
    -- (Stepped + Heartbeat) while ALSO force-setting CFrame every Stepped frame -
    -- those two were fighting each other every physics step, which is what was
    -- flinging the BOT itself all over the place ("etrafa sacılıyor"), especially
    -- once the target started moving (the "goal" position was also shifting at
    -- the same time). The lead distance is now small and capped so a moving
    -- target doesn't cause a big, erratic jump either.
    local function stickAndFling(BasePart)
        local start = tick()
        repeat
            if RootPart.Parent and BasePart.Parent then
                local v = BasePart.AssemblyLinearVelocity
                if v.Magnitude > 120 then v = Vector3.zero end -- don't extrapolate an already-flung target
                local lead = v * 0.05
                if lead.Magnitude > 3 then lead = lead.Unit * 3 end -- capped so walking/running targets don't scatter the bot
                local cf = CFrame.new(BasePart.Position + lead)
                RootPart.CFrame = cf
                Character:PivotTo(cf)
                RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
            end
            task.wait()
        until start + F.Time < tick() or gen ~= F.gen or not BasePart.Parent
            or ((tick() - start) > 0.8 and BasePart.Parent and BasePart.AssemblyLinearVelocity.Magnitude > 1500)
    end

    stickAndFling(part)

    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    workspace.CurrentCamera.CameraSubject = Humanoid

    if F.OldPos then
        local t0 = tick()
        repeat
            RootPart.CFrame = F.OldPos * CFrame.new(0, 0.5, 0)
            Character:PivotTo(F.OldPos * CFrame.new(0, 0.5, 0))
            Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            for _, p in ipairs(Character:GetChildren()) do
                if p:IsA("BasePart") then
                    p.Velocity, p.RotVelocity = Vector3.zero, Vector3.zero
                end
            end
            task.wait()
        until (RootPart.Position - F.OldPos.Position).Magnitude < 25 or tick() - t0 > 5 or not RootPart.Parent
    end
    workspace.FallenPartsDestroyHeight = F.FPDH
end

function F.pool()
    local list, seen = {}, {}
    local function add(p)
        if p and p ~= LocalPlayer and p.Parent and not seen[p] and not F.isWhitelisted(p) then
            seen[p] = true
            table.insert(list, p)
        end
    end
    if not F.Paused then
        for name in pairs(F.Loop) do add(Players:FindFirstChild(name)) end
    end
    if F.SelActive then
        for name in pairs(F.Targets) do add(Players:FindFirstChild(name)) end
    end
    if F.AllActive then
        for _, p in ipairs(Players:GetPlayers()) do add(p) end
    end
    return list
end

function F.nextTarget()
    while #F.queue > 0 do
        local p = table.remove(F.queue, 1)
        if p and p.Parent and p ~= LocalPlayer and not F.isWhitelisted(p) then return p end
    end
    local list = F.pool()
    if #list == 0 then return nil end
    F.rr = (F.rr % #list) + 1
    return list[F.rr]
end

task.spawn(function()
    while alive() do
        local p = F.nextTarget()
        if p then
            F.leaveVoid()
            F.dirty = true
            local gen = F.gen
            F.busy = true
            local startHrp = HRP()
            if startHrp then
                for _, inst in ipairs(startHrp:GetChildren()) do
                    if inst:IsA("BodyVelocity") or inst:IsA("BodyGyro") or inst:IsA("BodyPosition") then
                        inst:Destroy()
                    end
                end
            end
            local ok = pcall(F.fling, p, gen)
            F.busy = false
            if not ok then F.cleanup() end
            task.wait(0.1)
        else
            if F.dirty then
                F.dirty = false
                F.cleanup()
                F.holdVoid(2)
            end
            task.wait(0.25)
        end
    end
end)

function F.isOwner(speaker)
    if speaker == LocalPlayer then return true end
    if F.TP_USERID and speaker.UserId == F.TP_USERID then return true end
    return false
end

function F.enqueue(p)
    for _, q in ipairs(F.queue) do
        if q == p then return end
    end
    table.insert(F.queue, p)
end

function F.waitAndClear()
    local hrp = HRP()
    if not hrp then return nil end
    F.gen = F.gen + 1
    local waited = 0
    while F.busy and waited < 2 do
        task.wait()
        waited = waited + 1 / 60
    end
    local bv = hrp:FindFirstChild("LinaFlingBV")
    if bv then bv:Destroy() end
    if hrp.Anchored then hrp.Anchored = false end
    hrp.Velocity = Vector3.zero
    hrp.RotVelocity = Vector3.zero
    return hrp
end

function F.safeSetCFrame(cf)
    if F.Void then F.setVoid(false, true) end
    local hrp = F.waitAndClear()
    if not hrp or not cf then return false end
    hrp.CFrame = cf
    hrp.Velocity = Vector3.zero
    hrp.RotVelocity = Vector3.zero
    return true
end

function F.stopAll()
    F.gen = F.gen + 1
    F.queue = {}
    F.Paused = true
    F.SelActive = false
    F.AllActive = false
    F.AutoBringActive = false
    F.BringBusy = false
    F.bringGen = F.bringGen + 1
    F.voidReturnAt = 0
    if F.loopToggle then pcall(function() F.loopToggle:Set(false, true) end) end
    if F.allToggle then pcall(function() F.allToggle:Set(false, true) end) end
end

function F.findPlayer(arg)
    arg = arg:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == arg or p.DisplayName:lower() == arg then return p end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1, #arg) == arg or p.DisplayName:lower():sub(1, #arg) == arg then return p end
    end
    return nil
end

function F.tpTo(target)
    local th = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not th then return false end
    return F.safeSetCFrame(th.CFrame * CFrame.new(0, 0, 3))
end

function F.tpToMain()
    local target
    if F.TP_USERID then
        target = Players:GetPlayerByUserId(F.TP_USERID)
    end
    if not target and F.MainName and F.MainName ~= "" then
        target = Players:FindFirstChild(F.MainName) or F.findPlayer(F.MainName)
    end
    return F.tpTo(target)
end

function F.leave()
    pcall(function() game:Shutdown() end)
    task.wait(1)
    pcall(function() LocalPlayer:Kick(SCRIPT_NAME .. ": !leave") end)
end

local LOADER_URL = ""

function F.doRejoin(say)
    if say then say("Rejoining...", "Warning") end
    pcall(function()
        if type(queue_on_teleport) == "function" and LOADER_URL ~= "" then
            -- getgenv() is wiped on teleport, so put the same values back before loading the loader again
            local e = getgenv()
            local function q(v) return v ~= nil and string.format("%q", tostring(v)) or "nil" end
            local pre = ("getgenv().Script=%s getgenv().Owner=%s getgenv().DisableRendering=%s getgenv().FPSCap=%s "):format(
                q(e.Script), q(e.Owner), tostring(e.DisableRendering ~= false), tostring(tonumber(e.FPSCap)))
            queue_on_teleport(pre .. ([[
                task.wait(2)
                pcall(function() loadstring(game:HttpGet(%q))() end)
            ]]):format(LOADER_URL))
        end
    end)
    task.wait(0.3)
    local ok = pcall(function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end)
    if not ok and say then
        say("Could not rejoin automatically, rejoin manually.", "Warning")
    end
end

function F.applyVoid()
    local hrp = HRP()
    if not hrp then return false end
    F.VoidReturn = hrp.CFrame
    local y = math.clamp(F.FPDH + 50, -5000, -100)
    F.VoidPos = Vector3.new(hrp.Position.X + 4000, y, hrp.Position.Z + 4000)
    if F.voidConn then F.voidConn:Disconnect() end
    F.voidConn = RunService.Heartbeat:Connect(function()
        if not F.Void then return end
        local h = HRP()
        if not h then return end
        if F.busy then return end
        if h.Anchored then h.Anchored = false end
        h.CFrame = CFrame.new(F.VoidPos)
        h.Velocity = Vector3.zero
        h.RotVelocity = Vector3.zero
    end)
    return true
end

function F.setVoid(state, internal)
    state = state and true or false
    if not internal then F.VoidWanted = state end
    if state and F.AF and F.AF.On then return end -- autofarm açıkken void'e girilmez
    if state == F.Void then return end
    F.Void = state
    if state then
        if not F.applyVoid() then F.Void = false end
    else
        if F.voidConn then F.voidConn:Disconnect() F.voidConn = nil end
        local h = F.waitAndClear()
        if h then
            if F.VoidReturn then h.CFrame = F.VoidReturn end
            h.Velocity = Vector3.zero
            h.RotVelocity = Vector3.zero
        end
    end
    if F.voidToggle then pcall(function() F.voidToggle:Set(F.Void, true) end) end
end

LocalPlayer.CharacterAdded:Connect(function()
    if not F.Void then return end
    if F.voidConn then F.voidConn:Disconnect() F.voidConn = nil end
    task.wait(1)
    if F.Void and not F.applyVoid() then F.Void = false end
end)

function F.leaveVoid()
    if F.Void then F.setVoid(false, true) end
end

function F.holdVoid(seconds)
    F.voidReturnAt = math.max(F.voidReturnAt, tick() + (seconds or 0))
end

function F.flingActive()
    if F.busy or #F.queue > 0 then return true end
    return #F.pool() > 0
end

function F.runOutOfVoid(holdAfter, fn)
    F.cmdBusy = F.cmdBusy + 1
    F.leaveVoid()
    local ok, ret = pcall(fn)
    F.cmdBusy = F.cmdBusy - 1
    F.holdVoid(ok and tonumber(ret) or holdAfter)
    return ok
end

-- The bot goes back to the void by itself, except while stand mode or autofarm is running.
task.spawn(function()
    while alive() do
        task.wait(0.25)
        if F.VoidWanted and not F.Void and F.cmdBusy <= 0 and tick() >= F.voidReturnAt
            and not F.flingActive() and not F.Stand.On and not (F.AF and F.AF.On) and HRP() then
            F.setVoid(true, true)
        end
    end
end)

function F.selfReset()
    local hrp = HRP()
    if hrp then
        local bv = hrp:FindFirstChild("LinaFlingBV")
        if bv then bv:Destroy() end
    end
    local h = Hum()
    if h and h.Health > 0 then h.Health = 0 end
end

local function bindFollowChar(char)
    task.spawn(function()
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        if not hum then return end
        hum.Died:Connect(function()
            if F.FollowMode then F.selfReset() end
        end)
    end)
end
local function bindFollowPlayer(p)
    if not F.TP_USERID or p.UserId ~= F.TP_USERID then return end
    if p.Character then bindFollowChar(p.Character) end
    p.CharacterAdded:Connect(bindFollowChar)
end
for _, p in ipairs(Players:GetPlayers()) do bindFollowPlayer(p) end
Players.PlayerAdded:Connect(bindFollowPlayer)

task.spawn(function()
    local hadGun = findGunDrop() ~= nil
    while alive() do
        task.wait(0.5)
        local hasGunNow = findGunDrop() ~= nil
        if hasGunNow and not hadGun then
            sendGameChat("gun is available")
            notifySay("Gun is available", "Info")
            print("[" .. SCRIPT_NAME .. "] gun drop detected, posted to chat")
        end
        hadGun = hasGunNow
    end
end)

task.spawn(function()
    local wasMurderer, wasSheriff = isLocalMurderer(), false
    wasSheriff = ownsGunNow()
    while alive() do
        task.wait(0.5)
        local isM = isLocalMurderer()
        local isS = ownsGunNow()
        if isM and not wasMurderer then
            sendGameChat("im murderer")
            notifySay("You are the murderer", "Warning")
            print("[" .. SCRIPT_NAME .. "] role: murderer")
        end
        if isS and not wasSheriff then
            sendGameChat("im sheriff")
            notifySay("You are the sheriff", "Info")
            print("[" .. SCRIPT_NAME .. "] role: sheriff")
        end
        wasMurderer, wasSheriff = isM, isS
    end
end)

F.AinfoXP = 20

local function isXPNamed(name)
    name = name:lower()
    return name:find("xp") or name:find("survival")
end

local function findXPStat()
    for _, root in ipairs({ LocalPlayer, PlayerGui }) do
        for _, v in ipairs(root:GetDescendants()) do
            if (v:IsA("IntValue") or v:IsA("NumberValue")) and isXPNamed(v.Name) then
                return v
            end
        end
    end
    return nil
end
local function dumpXPCandidates()
    local parts = {}
    for _, root in ipairs({ LocalPlayer, PlayerGui }) do
        for _, v in ipairs(root:GetDescendants()) do
            if (v:IsA("IntValue") or v:IsA("NumberValue")) and isXPNamed(v.Name) then
                table.insert(parts, v:GetFullName() .. "=" .. tostring(v.Value))
            end
        end
    end
    if #parts == 0 then
        print("[" .. SCRIPT_NAME .. "] ainfo debug: no xp/survival-named IntValue or NumberValue found under Player or PlayerGui")
    else
        print("[" .. SCRIPT_NAME .. "] ainfo debug, xp candidates: " .. table.concat(parts, ", "))
    end
end
task.spawn(function()
    local firedThisRound = false
    local lastVal = nil
    local lastDump = 0
    while alive() do
        task.wait(0.5)
        local stat = findXPStat()
        local val = stat and stat.Value
        if val == nil then
            if F.AutoInfo and tick() - lastDump > 10 then
                lastDump = tick()
                dumpXPCandidates()
            end
        else
            if lastVal and val < lastVal then
                firedThisRound = false
            end
            if F.AutoInfo and not firedThisRound and val >= F.AinfoXP then
                firedThisRound = true
                print("[" .. SCRIPT_NAME .. "] ainfo: " .. stat:GetFullName() .. " reached " .. tostring(val) .. " (threshold " .. F.AinfoXP .. "), posting now")
                doInfo(notifySay, F.isWhitelisted)
            end
            lastVal = val
        end
    end
end)

task.spawn(function()
    if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end
    task.wait(1)
    F.setVoid(true)
end)

F.BringGrabDelay = 0.5 -- seconds to wait after grabbing the gun, before the tp
F.BringHoldDelay = 0.6 -- seconds to stay next to the requester before the reset

function F.bringCore(speaker, say, myGen)
    if not equippedGun() then
        local g = findGunDrop()
        if g then
            local part = g:IsA("BasePart") and g or g:FindFirstChildWhichIsA("BasePart", true)
            if part then F.safeSetCFrame(part.CFrame * CFrame.new(0, 2, 0)) end
            grabGun(g)
        end
        local start = tick()
        while tick() - start < 5 do
            if myGen ~= F.bringGen then return false end
            if equippedGun() then break end
            task.wait(0.1)
        end
    end
    if myGen ~= F.bringGen then return false end
    if not equippedGun() then
        say("Could not grab the gun.", "Warning")
        return false
    end
    if not (speaker and speaker.Parent) then
        say("Requester left the server.", "Warning")
        return false
    end

    -- 1) small delay so the server registers the gun in our hands before we move
    task.wait(F.BringGrabDelay)
    if myGen ~= F.bringGen then return false end

    -- 2) tp next to the requester, and retry until we are really standing there
    local arrived = false
    for _ = 1, 4 do
        if not (speaker and speaker.Parent) then break end
        if F.tpTo(speaker) then
            task.wait(0.25)
            local hrp = HRP()
            local th = speaker.Character and speaker.Character:FindFirstChild("HumanoidRootPart")
            if hrp and th and (hrp.Position - th.Position).Magnitude < 15 then
                arrived = true
                break
            end
        else
            task.wait(0.3)
        end
        if myGen ~= F.bringGen then return false end
    end
    if not arrived then
        say("Could not reach " .. speaker.Name .. ", keeping the gun for now.", "Warning")
        return false
    end

    -- 3) stay there a moment so the position settles on the server, then reset (the gun drops at our feet)
    task.wait(F.BringHoldDelay)
    if myGen ~= F.bringGen then return false end
    local hrp = HRP()
    if hrp then local bv = hrp:FindFirstChild("LinaFlingBV") if bv then bv:Destroy() end end
    local h = Hum()
    if h then h.Health = 0 end
    return true
end

function F.doBring(speaker, say)
    if F.BringBusy then
        say("A bring is already in progress, try again in a moment.", "Warning")
        return
    end
    F.BringBusy = true
    F.cmdBusy = F.cmdBusy + 1
    F.leaveVoid()
    local myGen = F.bringGen
    task.spawn(function()
        local ok, did = pcall(F.bringCore, speaker, say, myGen)
        if not ok then say("Bring failed, try again.", "Warning") end
        F.BringBusy = false
        F.cmdBusy = F.cmdBusy - 1
        F.holdVoid((ok and did) and 4 or 2)
    end)
end

F.AutoBringDelay = 0.4    -- seconds to wait when the gun is spotted, before !abring starts a bring
F.AutoBringCooldown = 2   -- seconds to rest after each auto-bring

function F.autoBringLoop(say)
    if F.AutoBringActive then return end
    F.AutoBringActive = true
    task.spawn(function()
        while F.AutoBringActive and alive() do
            local target = F.AutoBringTarget and Players:FindFirstChild(F.AutoBringTarget)
            if target and not F.BringBusy and (equippedGun() or findGunDrop()) then
                -- small delay before each auto-bring (the grab/tp/reset delays inside bringCore apply too)
                task.wait(F.AutoBringDelay)
                if F.AutoBringActive and not F.BringBusy and Players:FindFirstChild(F.AutoBringTarget or "") then
                    F.BringBusy = true
                    F.cmdBusy = F.cmdBusy + 1
                    F.leaveVoid()
                    local ok, did = pcall(F.bringCore, target, say, F.bringGen)
                    F.BringBusy = false
                    F.cmdBusy = F.cmdBusy - 1
                    F.holdVoid((ok and did) and 4 or 2)
                    task.wait(F.AutoBringCooldown)
                end
            else
                task.wait(1)
            end
        end
    end)
end

local DANCES = {
    jamal = "83796130837213",
    thel = "74430100028293",
    gamgam = "129764254213842",
    fly = "77529400769588",
    zombie = "81931167118728",
    headless = "84323682148776",
    bug = "86036950557685",
    kick = "92249489340640",
    minibox = "113994067684875",
}
local DANCE_NAMES = { "jamal", "thel", "gamgam", "fly", "zombie", "headless", "bug", "kick", "minibox" }
local DANCE_ALIASES = {
    jamalbrasil = "jamal", takethel = "thel", takel = "thel", l = "thel",
    gamgamstyle = "gamgam", gangnamstyle = "gamgam", zombiewalk = "zombie",
    headlesskorblox = "headless", korblox = "headless", insanebug = "bug", box = "minibox",
}
local currentDanceId = DANCES.jamal
local danceTrack, danceWant = nil, false

local function stopDance()
    danceWant = false
    if danceTrack then
        pcall(function() danceTrack:Stop(0) end)
        danceTrack = nil
    end
end
local ALL_DANCE_ANIMS = {}
for _, id in pairs(DANCES) do ALL_DANCE_ANIMS["rbxassetid://" .. id] = true end
local danceRev, danceFailNotified = 0, nil

local function playDance()
    local c = LocalPlayer.Character
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return end
    local an = h:FindFirstChildOfClass("Animator")
    if not an then return end

    danceRev = danceRev + 1
    local myRev = danceRev
    local wantId = "rbxassetid://" .. currentDanceId

    for _, t in ipairs(an:GetPlayingAnimationTracks()) do
        local aid = t.Animation and t.Animation.AnimationId
        if aid and ALL_DANCE_ANIMS[aid] and aid ~= wantId then
            pcall(function() t:Stop(0) end)
        end
    end
    if danceTrack then pcall(function() danceTrack:Stop(0) end) danceTrack = nil end

    local anim = Instance.new("Animation")
    anim.AnimationId = wantId
    local ok, track = pcall(function() return an:LoadAnimation(anim) end)
    if not (ok and track) then return end
    track.Priority = Enum.AnimationPriority.Action4
    track.Looped = true
    track:Play(0.1)
    danceTrack = track

    local t0 = tick()
    while track.Length == 0 and tick() - t0 < 1.5 do task.wait(0.05) end
    if myRev ~= danceRev then
        pcall(function() track:Stop(0) end)
        return
    end
    if track.Length == 0 and danceFailNotified ~= currentDanceId then
        danceFailNotified = currentDanceId
        notifySay("Dance failed to load: " .. currentDanceId, "Warning")
    end
end
local function startDance(id)
    if id then currentDanceId = tostring(id) end
    danceWant = true
    task.spawn(playDance)
end

local function resolveDance(raw)
    if type(raw) == "number" then return tostring(raw) end
    if type(raw) ~= "string" then return nil end
    local norm = raw:lower():gsub("[^%w]", "")
    if norm == "" then return DANCES.jamal end
    if DANCES[norm] then return DANCES[norm] end
    if DANCE_ALIASES[norm] and DANCES[DANCE_ALIASES[norm]] then return DANCES[DANCE_ALIASES[norm]] end
    local id = raw:match("%d%d%d%d+")
    if id then return id end
    return nil
end

pcall(function()
    getgenv().LinaDance = function(x)
        local id = resolveDance(x)
        if id then startDance(id) return true end
        return false
    end
end)

task.spawn(function()
    if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end
    task.wait(0.5)
    startDance()
end)
task.spawn(function()
    while alive() do
        task.wait(1)
        if danceWant then
            local wrong = danceTrack and danceTrack.Animation and danceTrack.Animation.AnimationId ~= ("rbxassetid://" .. currentDanceId)
            if (not danceTrack) or (not danceTrack.IsPlaying) or wrong then
                playDance()
            end
        end
    end
end)
LocalPlayer.CharacterAdded:Connect(function()
    danceTrack = nil
    if danceWant then
        task.wait(1)
        playDance()
    end
end)

-- Right side (kept), but now clearly BEHIND the shoulder instead of almost flush
-- beside it (that's what made it feel "too much right next to me").
local STAND_OFFSET = CFrame.new(2.2, 1.3, 1.8)

function F.standLoop()
    if F.Stand.Conn then F.Stand.Conn:Disconnect() F.Stand.Conn = nil end
    F.Stand.Conn = RunService.Heartbeat:Connect(function()
        if not alive() or not F.Stand.On then return end
        if F.busy then return end
        local targetPlr = F.Stand.TargetName and Players:FindFirstChild(F.Stand.TargetName)
        local tChar = targetPlr and targetPlr.Character
        local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local hrp = HRP()
        if not (tHrp and hrp) then return end
        if hrp.Anchored then hrp.Anchored = false end
        local goal = tHrp.CFrame * STAND_OFFSET
        hrp.CFrame = hrp.CFrame:Lerp(goal, 0.25)
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end)
end

function F.setStandMode(on, targetName)
    on = on and true or false
    if on then
        if targetName and targetName:lower() == LocalPlayer.Name:lower() then
            return false, "can't stand-follow yourself"
        end
        F.Stand.TargetName = targetName or F.Stand.TargetName
        if not F.Stand.TargetName then return false, "no target given" end
        if F.AF and F.AF.On then F.AFSet(false) end -- autofarm and stand mode can't run together
        if not F.Stand.On then F.Stand.PrevDance = currentDanceId end
        F.Stand.On = true
        if F.Void then F.setVoid(false, true) end
        startDance(DANCES.fly)
        F.standLoop()
    else
        F.Stand.On = false
        if F.Stand.Conn then F.Stand.Conn:Disconnect() F.Stand.Conn = nil end
        if F.Stand.PrevDance then
            startDance(F.Stand.PrevDance)
            F.Stand.PrevDance = nil
        end
    end
    return true
end

-- ===================== AUTOFARM =====================
do
    local TweenService = game:GetService("TweenService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local FARM_SPEED = 23

    local AF = {
        On = false, Type = nil, active = false, laid = false,
        tween = nil, holdConn = nil, noclipConn = nil, orig = {},
        collected = 0, total = 0, allDone = false,
        container = nil, containerCheck = 0, bagBusy = false,
        ResetOnFull = true,   -- çanta dolunca innocent isen karakteri resetle
        sessionTotal = 0,     -- autofarm açıkken toplanan toplam (ekranda "total collected")
        lastCollected = 0,
    }
    F.AF = AF

    local function afIsTarget(obj, itemType)
        if not obj or not itemType or not obj:IsA("BasePart") then return false end
        local id = obj:GetAttribute(itemType .. "ID") or obj:GetAttribute("ItemID") or obj:GetAttribute("CoinID")
        if id == itemType or id == "Coin" or id == "Candy" then return true end
        local n = obj.Name:lower()
        if itemType == "Candy" and n:find("candy", 1, true) then return true end
        if itemType == "Coin" and n:find("coin", 1, true) then return true end
        return false
    end

    local function afFindContainer(itemType)
        if AF.container and AF.container.Parent then return AF.container end
        AF.container = nil
        local now = tick()
        if now - AF.containerCheck < 1 then return nil end
        AF.containerCheck = now
        local names = { "CoinContainer", "CandyContainer", "ItemContainer", "CandyBagContainer" }
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") or obj:IsA("Folder") then
                for _, name in ipairs(names) do
                    local c = obj:FindFirstChild(name)
                    if c then AF.container = c return c end
                end
            end
        end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "CoinContainer" or obj.Name == "CandyContainer" or obj.Name == "ItemContainer" then
                AF.container = obj
                return obj
            end
        end
        return nil
    end

    local function afCollectible(item, itemType)
        if not item or not afIsTarget(item, itemType) then return false end
        if not item.CanTouch then return false end
        if not (item:FindFirstChildWhichIsA("TouchTransmitter") or item:FindFirstChild("TouchInterest")) then return false end
        if item.Transparency ~= 1 then return false end
        return true
    end

    local function afFindNearest(container, itemType)
        if not container or not itemType then return nil, math.huge end
        local hrp = HRP()
        if not hrp then return nil, math.huge end
        local best, bd = nil, math.huge
        for _, item in ipairs(container:GetDescendants()) do
            if afCollectible(item, itemType) then
                local d = (hrp.Position - item.Position).Magnitude
                if d < bd then bd, best = d, item end
            end
        end
        return best, bd
    end

    local function afAddGravity()
        local hrp = HRP()
        if not hrp then return end
        local old = hrp:FindFirstChild("FarmGravity")
        if old then old:Destroy() end
        local bp = Instance.new("BodyPosition")
        bp.Name = "FarmGravity"
        bp.MaxForce = Vector3.new(0, math.huge, 0)
        bp.D = 1000
        bp.P = 10000
        bp.Position = hrp.Position
        bp.Parent = hrp
    end
    local function afRemoveGravity()
        local hrp = HRP()
        local g = hrp and hrp:FindFirstChild("FarmGravity")
        if g then g:Destroy() end
    end
    local function afStopNoclip()
        if AF.noclipConn then AF.noclipConn:Disconnect() AF.noclipConn = nil end
    end
    local function afStartNoclip()
        if AF.noclipConn then return end
        AF.noclipConn = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    end

    function AF.stopFarm()
        if AF.holdConn then AF.holdConn:Disconnect() AF.holdConn = nil end
        if AF.tween then pcall(function() AF.tween:Cancel() end) AF.tween = nil end
        afStopNoclip()
        if not (AF.active or AF.laid) then return end
        AF.active = false
        for part, data in pairs(AF.orig) do
            if part and part.Parent then
                part.CanCollide = data.CanCollide
                part.Massless = data.Massless
            end
        end
        AF.orig = {}
        local hrp = HRP()
        if hrp and AF.laid then
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
            hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(-90), 0, 0)
            hrp.CFrame = hrp.CFrame + Vector3.new(0, 2.5, 0)
        end
        AF.laid = false
        local hum = Hum()
        if hum then
            hum.PlatformStand = false
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end
        afRemoveGravity()
    end

    function AF.startFarm()
        if AF.active then return end
        local hrp, hum = HRP(), Hum()
        if not hrp or not hum then return end
        if LocalPlayer:GetAttribute("Alive") == false then return end
        afAddGravity()
        AF.orig = {}
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                AF.orig[part] = { CanCollide = part.CanCollide, Massless = part.Massless }
            end
        end
        hrp.CFrame = hrp.CFrame - Vector3.new(0, 2.5, 0)
        hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(90), 0, 0)
        hum.PlatformStand = true
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        AF.laid = true
        AF.active = true
    end

    -- Ana döngü
    task.spawn(function()
        while alive() do
            RunService.Heartbeat:Wait()
            pcall(function()
                local farmType = AF.Type
                if AF.On and farmType and not AF.allDone and LocalPlayer:GetAttribute("Alive") ~= false then
                    local container = afFindContainer(farmType)
                    local item, dist = afFindNearest(container, farmType)
                    if item and AF.On and AF.Type == farmType then
                        if F.Void then F.leaveVoid() end
                        if not AF.active then AF.startFarm() end
                        local hrp, hum = HRP(), Hum()
                        if hrp and hum then
                            hrp.Velocity = Vector3.zero
                            hrp.RotVelocity = Vector3.zero
                            local target = CFrame.new(item.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(math.rad(90), 0, 0)
                            afStartNoclip()
                            if AF.tween then AF.tween:Cancel() end
                            local tweenTime = math.max(dist / FARM_SPEED, 0.15)
                            AF.tween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { CFrame = target })
                            AF.tween:Play()
                            if AF.holdConn then AF.holdConn:Disconnect() end
                            AF.holdConn = RunService.Heartbeat:Connect(function()
                                if not AF.On or not hrp.Parent then return end
                                hrp.Velocity = Vector3.zero
                                hrp.RotVelocity = Vector3.zero
                                local g = hrp:FindFirstChild("FarmGravity")
                                if g and g:IsA("BodyPosition") then g.Position = hrp.Position end
                                local h = Hum()
                                if h then h.PlatformStand = true end
                            end)
                            task.wait(tweenTime + 0.08)
                            if AF.On and AF.Type == farmType and item and item.Parent and afCollectible(item, farmType) then
                                if (hrp.Position - item.Position).Magnitude <= 4 then
                                    pcall(function() firetouchinterest(hrp, item, 0) end)
                                    task.wait(0.03)
                                    pcall(function() firetouchinterest(hrp, item, 1) end)
                                end
                            end
                            local checkStart = tick()
                            while AF.On and AF.Type == farmType and item and item.Parent and afCollectible(item, farmType)
                                and (tick() - checkStart) < 1.5 and LocalPlayer:GetAttribute("Alive") ~= false do
                                RunService.Heartbeat:Wait()
                            end
                            if AF.holdConn then AF.holdConn:Disconnect() AF.holdConn = nil end
                            if AF.tween then AF.tween:Cancel() AF.tween = nil end
                            if hrp.Parent then
                                hrp.Velocity = Vector3.zero
                                hrp.RotVelocity = Vector3.zero
                            end
                        end
                    else
                        AF.stopFarm()
                    end
                else
                    AF.stopFarm()
                end
            end)
        end
    end)

    -- Debug: autofarm açıkken 3 saniyede bir durumu F9 konsoluna yazar
    task.spawn(function()
        while alive() do
            task.wait(3)
            if AF.On then
                local c = AF.container
                local n = 0
                if c and c.Parent then
                    for _, it in ipairs(c:GetDescendants()) do
                        if afCollectible(it, AF.Type) then n = n + 1 end
                    end
                end
                print(string.format("[%s] autofarm debug: type=%s container=%s collectible=%d active=%s void=%s alive=%s allDone=%s collected=%d/%d",
                    SCRIPT_NAME, tostring(AF.Type), c and c.Name or "nil", n, tostring(AF.active),
                    tostring(F.Void), tostring(LocalPlayer:GetAttribute("Alive")), tostring(AF.allDone), AF.collected, AF.total))
            end
        end
    end)

    -- Void guard: autofarm açıkken void'deysen otomatik çıkar (item olsa da olmasa da, her an)
    task.spawn(function()
        while alive() do
            task.wait(0.2)
            if AF.On and F.Void then
                pcall(F.leaveVoid)
            end
        end
    end)

    -- Çanta dolunca: innocent isen resetle
    task.spawn(function()
        while alive() do
            task.wait(0.5)
            if AF.On and AF.allDone and not AF.bagBusy and LocalPlayer:GetAttribute("Alive") ~= false then
                AF.bagBusy = true
                AF.stopFarm()
                if AF.ResetOnFull and not isLocalMurderer() and not ownsGunNow() then
                    notifySay("Bag full, resetting.", "Info")
                    task.wait(0.5)
                    local h = Hum()
                    if h then h.Health = 0 end
                    task.wait(6)
                end
                AF.bagBusy = false
            end
        end
    end)

    -- Round / coin olayları
    task.spawn(function()
        local rem = ReplicatedStorage:WaitForChild("Remotes", 30)
        local gp = rem and rem:WaitForChild("Gameplay", 30)
        if not gp then return end
        local function resetCounters()
            AF.collected, AF.total, AF.allDone, AF.bagBusy = 0, 0, false, false
            AF.lastCollected = 0
            AF.container, AF.containerCheck = nil, 0
        end
        local roundEnd = gp:FindFirstChild("RoundEndFade")
        if roundEnd then
            roundEnd.OnClientEvent:Connect(function()
                resetCounters()
                AF.stopFarm()
            end)
        end
        local roundStart = gp:FindFirstChild("RoundStart")
        if roundStart then roundStart.OnClientEvent:Connect(resetCounters) end
        local coinEvent = gp:FindFirstChild("CoinCollected")
        if coinEvent then
            coinEvent.OnClientEvent:Connect(function(typ, collected, total)
                if typ == AF.Type or typ == nil then
                    AF.collected = tonumber(collected) or AF.collected
                    AF.total = tonumber(total) or AF.total
                    -- toplam sayaç: bu raundda önceki değerden ne kadar arttıysa ekle
                    if AF.On then
                        local c = AF.collected
                        if c < AF.lastCollected then AF.lastCollected = 0 end -- yeni raund başladı
                        if c > AF.lastCollected then
                            AF.sessionTotal = AF.sessionTotal + (c - AF.lastCollected)
                            AF.lastCollected = c
                            NR.setCount(AF.sessionTotal)
                        end
                    end
                    if AF.total > 0 and AF.collected >= AF.total then
                        AF.allDone = true
                        AF.stopFarm()
                    end
                end
            end)
        end
    end)

    -- Karakter yeniden doğunca durumu sıfırla
    LocalPlayer.CharacterAdded:Connect(function()
        if AF.holdConn then AF.holdConn:Disconnect() AF.holdConn = nil end
        if AF.tween then pcall(function() AF.tween:Cancel() end) AF.tween = nil end
        afStopNoclip()
        AF.active, AF.laid, AF.orig = false, false, {}
    end)

    -- on: ekran eski moda (invite + role + total collected) geçer
    -- off: rainbow ekran geri gelir
    function F.AFSet(on, typ)
        if on then
            if F.Stand.On then F.setStandMode(false) end
            AF.Type = typ or AF.Type or "Coin"
            AF.container, AF.containerCheck = nil, 0
            AF.allDone, AF.bagBusy, AF.collected, AF.total = false, false, 0, 0
            AF.lastCollected = 0
            if not AF.On then AF.sessionTotal = 0 end
            AF.On = true
            NR.FarmOn = true
            NR.setCount(AF.sessionTotal)
            NR.applyMode()
            F.leaveVoid()
        else
            AF.On = false
            AF.Type = nil
            AF.stopFarm()
            NR.FarmOn = false
            NR.applyMode()
            F.holdVoid(2)
        end
    end
    function F.AFStop()
        if AF.On then F.AFSet(false) end
    end
end

F.SettingsFile = "lina.cc_fling_settings.json"
function F.saveSettings()
    if type(writefile) ~= "function" then return end
    pcall(function()
        writefile(F.SettingsFile, HttpService:JSONEncode({
            Time = F.Time,
            WhitelistFriends = F.WhitelistFriends,
            MainName = F.MainName,
            FollowMode = F.FollowMode,
            AutoInfo = F.AutoInfo,
            AinfoXP = F.AinfoXP,
        }))
    end)
end
function F.loadSettings()
    local ok, data = pcall(function()
        if type(isfile) == "function" and isfile(F.SettingsFile) then
            return HttpService:JSONDecode(readfile(F.SettingsFile))
        end
    end)
    if not ok or type(data) ~= "table" then return end
    if type(data.Time) == "number" then F.Time = math.clamp(data.Time, 0.5, 10) end
    if type(data.WhitelistFriends) == "boolean" then F.WhitelistFriends = data.WhitelistFriends end
    if type(data.MainName) == "string" and data.MainName ~= "" then F.MainName = data.MainName end
    if type(data.FollowMode) == "boolean" then F.FollowMode = data.FollowMode end
    if type(data.AutoInfo) == "boolean" then F.AutoInfo = data.AutoInfo end
    if type(data.AinfoXP) == "number" then F.AinfoXP = math.clamp(data.AinfoXP, 1, 1000) end
end

-- ===================== ADVERTISE =====================
-- !advertise [on|off]: posts the two ad messages to chat, one after the other, every 60 seconds.
F.Ad = { On = false, Gen = 0, Index = 0 }
local AD_MESSAGES = {
    "join /standd for best private universal stand!",
    "Haven't you joined /standd yet? You're missing out on a lot.",
}

function F.setAdvertise(on)
    F.Ad.Gen = F.Ad.Gen + 1 -- stops any older loop
    F.Ad.On = on and true or false
    if not F.Ad.On then return end
    local myGen = F.Ad.Gen
    task.spawn(function()
        while alive() and F.Ad.On and F.Ad.Gen == myGen do
            F.Ad.Index = F.Ad.Index % #AD_MESSAGES + 1
            sendGameChat(AD_MESSAGES[F.Ad.Index])
            for _ = 1, 35 do
                if not (alive() and F.Ad.On and F.Ad.Gen == myGen) then return end
                task.wait(1)
            end
        end
    end)
end

F.HELP = [[
lina's stand commands:
  Usable by you AND whitelisted players:
    !fling <user>        fling once
    !flingall             fling everyone once (whitelist skipped)
    !loop <user>          loop forever (saved list, survives rejoin)
    !unloop <user|all>    remove from the loop list
    !loopall              keep flinging everyone (whitelist skipped)
    !bring                go to the gun, take it, tp to you, reset (delivers the gun to you)
    !abring               keep doing !bring every time the gun drops
    !list                 show whitelist and loop list
    !info                 sheriff/murderer info (also posts to chat, whitelisted players show as "whitelisted")
    !standmode [user]      float beside that player's shoulder forever, dancing fly, follows them
    !standmode             (no name) stand-follow whoever typed the command
    !standmode off          stop stand mode, restores the previous dance
    !stop                 stop EVERYTHING (fling, loops, bring) except the dance, and go back to the void
    !resume               resume the loop list
    !reset                reset your character
    !shoot                (sheriff) shoot the murderer once
    !killall              (murderer) knife aura for 5 seconds
    !tp                   teleport to the main account
    !tp <user>            teleport to that user
    !void / !unvoid       void hide on/off permanently (on by default)
    !followmode on|off    when the main account dies or !reset's, this bot auto-resets too
    !autofarm [on|off] [candy|coin]   autofarm (default candy). While it is ON the black screen shows
                          "join .gg/standd" + role + "total collected: N"; when OFF the rainbow .gg/standd screen comes back
    !rejoin               teleport to a new server and re-inject (set LOADER_URL at the top of the script first)

  Usable ONLY from your own account (or the main account, id bound, see below):
    !whitelist <user>     add to whitelist (saved)
    !unwhitelist <user>   remove from whitelist
    !setmain <user>       set the "main account" bare !tp goes to (saved)
    !ainfo on|off [xp]     auto-post !info once your XP leaderstat reaches this value (default 20)
    !advertise [on|off]   post the /standd ads to chat, alternating, every 60 seconds
    !leave                leave the game
    !time <0.5-10>        seconds spent per player (default 7)
    !friends on|off       never fling your friends
    !norender on|off      3D rendering off + black screen
    !dance [name|id]      jamal(default)/thel/gamgam/fly/zombie/headless/bug/kick/minibox or an animation id
    !help                 print this list to the F9 console

  Void rules: every command first takes you OUT of the void, then the bot goes back by itself:
    !tp -> 15s later | !bring -> 4s after the reset | !fling/!loop -> 2s after the last fling
    !reset -> 4s later | !shoot -> 3s later | !killall -> 2s after the aura | !stop -> right away
  The dance is always on and is never touched by !stop. Stand mode and autofarm are independent of !stop too
  (use !standmode off / !autofarm off to end them). The bot does not hide in the void while autofarm or stand mode is on.
  GUI dance hook: getgenv().LinaDance("gamgam") or getgenv().LinaDance(1234567890)
]]

local COMMANDS = {
    loopall = true, list = true, help = true, time = true, friends = true, norender = true,
    void = true, unvoid = true, fling = true, flingall = true, loop = true, unloop = true,
    stop = true, resume = true, whitelist = true, unwhitelist = true, leave = true, tp = true,
    reset = true, shoot = true, killall = true, setmain = true, bring = true, abring = true, dance = true,
    info = true, followmode = true, ainfo = true, standmode = true, rejoin = true, advertise = true,
    autofarm = true,
}
local ADMIN = {
    time = true, friends = true, norender = true,
    whitelist = true, unwhitelist = true, leave = true,
    setmain = true, dance = true,
    ainfo = true, advertise = true,
}

-- Debug trace: when a message that LOOKS like a command gets rejected, print exactly why to F9
-- instead of silently doing nothing. This is the only way to tell "not whitelisted" apart from
-- "typo in the command name", "admin-only command", or "no character yet" without guessing blind.
local function traceReject(speaker, text, reason)
    if type(text) ~= "string" or text:sub(1, 1) ~= "!" then return end
    local wl = {}
    for name in pairs(F.Whitelist) do table.insert(wl, name) end
    print(string.format("[%s] REJECTED '%s' from %s (id %d): %s | whitelist=[%s]",
        SCRIPT_NAME, text, speaker and speaker.Name or "?", speaker and speaker.UserId or -1, reason, table.concat(wl, ", ")))
end

function F.onChat(speaker, text)
    if not alive() then return end
    if not F.ChatCmd or type(text) ~= "string" then return end
    local isMe = F.isOwner(speaker)
    if not isMe and not F.isWhitelisted(speaker) then
        traceReject(speaker, text, "not the owner and not whitelisted")
        return
    end
    local cmd, arg = text:match("^%s*!(%a+)%s*(%S*)")
    if not cmd then
        traceReject(speaker, text, "doesn't match the !command pattern")
        return
    end
    cmd = cmd:lower()
    if not COMMANDS[cmd] then
        traceReject(speaker, text, "'" .. cmd .. "' is not a known command")
        return
    end
    if ADMIN[cmd] and not isMe then
        traceReject(speaker, text, "'" .. cmd .. "' is owner-only")
        return
    end

    local key = speaker.UserId .. ":" .. text
    local now = tick()
    if F.lastCmd[key] and now - F.lastCmd[key] < 1.5 then return end
    F.lastCmd[key] = now

    local say = notifySay
    local function sync() if F.refreshUI then F.refreshUI() end end

    if cmd == "stop" then
        F.stopAll()
        say(speaker.Name .. " stopped everything (dance keeps going). Back to the void. Use !resume for the loop list.")
        return
    elseif cmd == "resume" then
        F.Paused = false
        say("Loop list resumed.", "Success")
        return
    elseif cmd == "void" then
        F.setVoid(true)
        if F.AF and F.AF.On then
            say("Autofarm is on, void will start after !autofarm off.", "Warning")
            return
        end
        say(F.Void and "Void mode on. Use !unvoid to come back." or "Could not enter the void (no character).", F.Void and "Success" or "Warning")
        return
    elseif cmd == "unvoid" then
        F.setVoid(false)
        say("Void mode off. Back at your old position.", "Success")
        return
    elseif cmd == "loopall" then
        F.leaveVoid()
        F.AllActive = true
        say("Looping everyone (whitelist skipped). Use !stop to end.", "Warning")
        return
    elseif cmd == "list" then
        local wl, lp = table.concat(F.whitelistList(), ", "), table.concat(F.loopList(), ", ")
        say("Whitelist: " .. (wl ~= "" and wl or "-"), "Info")
        say("Loop: " .. (lp ~= "" and lp or "-"), "Info")
        print("[" .. SCRIPT_NAME .. "] Whitelist: " .. wl .. " | Loop: " .. lp)
        return
    elseif cmd == "help" then
        print(F.HELP)
        say("Command list printed to the F9 console.", "Info")
        return
    elseif cmd == "info" then
        doInfo(say, F.isWhitelisted)
        return
    elseif cmd == "time" then
        local n = tonumber(arg)
        if n then
            F.Time = math.clamp(n, 0.5, 10)
            F.saveSettings()
            say("Fling time per player: " .. F.Time .. "s", "Success")
        else
            say("Usage: !time <0.5-10>", "Warning")
        end
        return
    elseif cmd == "ainfo" then
        local rest = text:match("^%s*!ainfo%s+(.-)%s*$") or ""
        local w1, w2 = rest:match("^(%S*)%s*(%S*)$")
        w1 = (w1 or ""):lower()
        if w1 == "on" or w1 == "off" then
            F.AutoInfo = (w1 == "on")
            local n = tonumber(w2)
            if n then F.AinfoXP = math.clamp(n, 1, 1000) end
        elseif tonumber(w1) then
            F.AinfoXP = math.clamp(tonumber(w1), 1, 1000)
        else
            say("Usage: !ainfo on|off [xp], e.g. !ainfo on 20  (posts once your XP stat reaches this)", "Warning")
            return
        end
        F.saveSettings()
        say("Auto-info: " .. (F.AutoInfo and "on" or "off") .. ", posts once XP reaches " .. F.AinfoXP .. ".", "Success")
        return
    elseif cmd == "followmode" then
        local v = arg:lower()
        if v ~= "on" and v ~= "off" then say("Usage: !followmode on|off", "Warning") return end
        F.FollowMode = (v == "on")
        F.saveSettings()
        say("Follow mode: " .. v .. " (this bot resets when the main account dies/resets)", "Success")
        return
    elseif cmd == "advertise" then
        local v = arg:lower()
        local on
        if v == "on" then on = true
        elseif v == "off" then on = false
        else on = not F.Ad.On end -- no argument: toggles
        F.setAdvertise(on)
        say(on and "Advertising on: a new message every 60s." or "Advertising off.", on and "Success" or "Info")
        return
    elseif cmd == "autofarm" then
        -- !autofarm            toggles (candy)
        -- !autofarm on [candy|coin] / !autofarm off / !autofarm candy / !autofarm coin
        local rest = text:match("^%s*!autofarm%s+(.-)%s*$") or ""
        local w1, w2 = rest:match("^(%S*)%s*(%S*)$")
        w1, w2 = (w1 or ""):lower(), (w2 or ""):lower()
        local on, typ
        if w1 == "off" then
            on = false
        elseif w1 == "" then
            on = not F.AF.On
            typ = "Candy"
        elseif w1 == "on" then
            on = true
            typ = (w2 == "coin" or w2 == "coins") and "Coin" or "Candy"
        elseif w1 == "coin" or w1 == "coins" then
            on, typ = true, "Coin"
        elseif w1 == "candy" or w1 == "candies" then
            on, typ = true, "Candy"
        else
            say("Usage: !autofarm [on|off] [candy|coin]", "Warning")
            return
        end
        F.AFSet(on, typ)
        if on then
            say("Autofarm on (" .. string.lower(F.AF.Type or "candy") .. "). Screen shows total collected. Use !autofarm off to end.", "Success")
        else
            say("Autofarm off. Rainbow screen is back.", "Info")
        end
        return
    elseif cmd == "friends" or cmd == "norender" then
        local v = arg:lower()
        if v ~= "on" and v ~= "off" then say("Usage: !" .. cmd .. " on|off", "Warning") return end
        local on = v == "on"
        if cmd == "friends" then F.WhitelistFriends = on
        else setNoRender(on) end
        F.saveSettings()
        say(cmd .. ": " .. v, "Success")
        return
    elseif cmd == "leave" then
        say(speaker.Name .. " -> leaving the game...", "Warning")
        task.spawn(F.leave)
        return
    elseif cmd == "rejoin" then
        say(speaker.Name .. " -> rejoining a new server...", "Warning")
        task.spawn(function() F.doRejoin(say) end)
        return
    elseif cmd == "standmode" then
        local vl = arg:lower()
        if vl == "off" then
            F.setStandMode(false)
            say("Stand mode off.", "Info")
        else
            local targetName
            if vl == "" or vl == "on" then
                targetName = speaker.Name
            else
                local found = F.findPlayer(arg)
                if not found then
                    say("Player not found: " .. arg, "Warning")
                    return
                end
                targetName = found.Name
            end
            local ok, err = F.setStandMode(true, targetName)
            if ok then
                say("Stand mode on, floating beside " .. targetName .. " (fly dance).", "Success")
            else
                say(err or "Could not start stand mode.", "Warning")
            end
        end
        return
    elseif cmd == "reset" then
        F.runOutOfVoid(4, function() F.selfReset() end)
        say("Character reset.", "Info")
        return
    elseif cmd == "shoot" then
        F.runOutOfVoid(3, function()
            local m = getMurdererPlayer()
            if not m or not m.Character then
                say("No murderer found.", "Warning")
                return 1
            end
            local tp = targetPart(m.Character)
            if tp and fireAt(tp, m) then
                say("Shot fired at " .. m.Name .. ".", "Success")
            else
                say("Could not fire.", "Warning")
            end
            return 3
        end)
        return
    elseif cmd == "killall" then
        F.runOutOfVoid(2, function()
            if not isLocalMurderer() then
                say("You are not the murderer.", "Warning")
                return 1
            end
            if killAllAura() then
                say("Kill aura active for 5 seconds.", "Success")
                return 7
            end
            say("No knife equipped.", "Warning")
            return 1
        end)
        return
    elseif cmd == "dance" then
        local rest = text:match("^%s*!%a+%s*(.-)%s*$") or ""
        local id = resolveDance(rest)
        print("[" .. SCRIPT_NAME .. "] dance request: '" .. rest .. "' -> " .. tostring(id))
        if id then
            startDance(id)
            local shown = rest ~= "" and rest or "jamal"
            say("Now dancing: " .. shown .. " forever (can't be stopped).", "Success")
        else
            say("Unknown dance. Options: " .. table.concat(DANCE_NAMES, ", "), "Warning")
        end
        return
    elseif cmd == "tp" then
        F.runOutOfVoid(15, function()
            local hold = 1
            if arg == "" then
                if F.tpToMain() then
                    hold = 15
                    say("Teleported to main account.", "Success")
                else
                    say("Main account is not in the server. Use !setmain <user>.", "Warning")
                end
            else
                local found = F.findPlayer(arg)
                if not found or found == LocalPlayer then
                    say("Player not found: " .. arg, "Warning")
                elseif F.tpTo(found) then
                    hold = 15
                    say("Teleported to " .. found.Name .. ".", "Success")
                else
                    say(found.Name .. "'s character is not loaded.", "Warning")
                end
            end
            return hold
        end)
        return
    end

    if cmd == "flingall" then
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p ~= speaker and not F.isWhitelisted(p) then
                table.insert(list, p)
            end
        end
        local n = #list
        if n > 0 then F.leaveVoid() end
        for _, p in ipairs(list) do F.enqueue(p) end
        say(n > 0 and (speaker.Name .. " -> flinging " .. n .. " player(s). Whitelist is skipped.") or "No non-whitelisted players to fling.", n > 0 and "Info" or "Warning")
        return
    end

    if cmd == "bring" then
        F.doBring(speaker, say)
        say("Bringing the gun to " .. speaker.Name .. ".", "Info")
        return
    elseif cmd == "abring" then
        F.AutoBringTarget = speaker.Name
        F.autoBringLoop(say)
        say("Auto-bring active for " .. speaker.Name .. ". Use !stop to end.", "Success")
        return
    end

    if arg == "" then
        if cmd == "setmain" then say("Usage: !setmain <user>", "Warning") end
        return
    end

    if cmd == "setmain" then
        F.MainName = arg
        F.saveSettings()
        say("Main account set to " .. arg .. ".", "Success")
        return
    end

    if cmd == "unloop" and arg:lower() == "all" then
        F.Loop = {}
        F.saveLoop()
        sync()
        say("Loop list cleared.")
        return
    end

    local found = F.findPlayer(arg)
    local name = found and found.Name or arg
    if name:lower() == LocalPlayer.Name:lower() or name:lower() == speaker.Name:lower() then return end

    if cmd == "fling" then
        if not found or F.isWhitelisted(found) then return end
        F.leaveVoid()
        F.enqueue(found)
        say(speaker.Name .. " -> " .. found.Name .. " is being flung.")
    elseif cmd == "loop" then
        if F.Whitelist[name] then say(name .. " is whitelisted and can't be looped.", "Warning") return end
        if found then F.leaveVoid() end
        F.Loop[name] = true
        F.Paused = false
        F.saveLoop()
        sync()
        say(name .. " added to the loop list (stays after rejoin). Use !stop to pause.", "Warning")
    elseif cmd == "unloop" then
        F.removeName(F.Loop, name)
        F.saveLoop()
        sync()
        say(name .. " removed from the loop list.")
    elseif cmd == "whitelist" then
        F.Whitelist[name] = true
        F.removeName(F.Loop, name)
        F.save()
        F.saveLoop()
        sync()
        say(name .. " added to whitelist.", "Success")
    elseif cmd == "unwhitelist" then
        F.removeName(F.Whitelist, name)
        F.save()
        sync()
        say(name .. " removed from the whitelist.")
    end
end

local function bindChat(p)
    p.Chatted:Connect(function(msg) F.onChat(p, msg) end)
end
for _, p in ipairs(Players:GetPlayers()) do bindChat(p) end
Players.PlayerAdded:Connect(bindChat)

pcall(function()
    TextChatService.MessageReceived:Connect(function(msg)
        local src = msg.TextSource
        if not src then return end
        local p = Players:GetPlayerByUserId(src.UserId)
        if p then F.onChat(p, msg.Text) end
    end)
end)

do
    local CHANNEL, BOT_DIR = "stand_cmd.json", "stand_bots"
    local lastSeq = 0
    pcall(function()
        if isfile(CHANNEL) then
            local d = HttpService:JSONDecode(readfile(CHANNEL))
            if type(d) == "table" and type(d.seq) == "number" then lastSeq = d.seq end
        end
    end)
    local function forMe(to)
        if to == nil or to == "all" then return true end
        for name in tostring(to):gmatch("[^,]+") do
            if name:lower() == LocalPlayer.Name:lower() then return true end
        end
        return false
    end
    task.spawn(function()
        while alive() do
            task.wait(0.2)
            pcall(function()
                if not isfile(CHANNEL) then return end
                local d = HttpService:JSONDecode(readfile(CHANNEL))
                if type(d) ~= "table" or type(d.cmds) ~= "table" then return end
                local maxSeq = lastSeq
                for _, c in ipairs(d.cmds) do
                    if type(c.n) == "number" and c.n > lastSeq then
                        if c.n > maxSeq then maxSeq = c.n end
                        if forMe(c.to) and type(c.msg) == "string" then
                            task.spawn(F.onChat, LocalPlayer, c.msg)
                        end
                    end
                end
                lastSeq = maxSeq
            end)
        end
    end)
    task.spawn(function()
        pcall(function() if not isfolder(BOT_DIR) then makefolder(BOT_DIR) end end)
        while alive() do
            pcall(function()
                local role = "innocent"
                if isLocalMurderer() then role = "murderer"
                elseif ownsGunNow() then role = "sheriff" end
                writefile(BOT_DIR .. "/" .. LocalPlayer.Name .. ".json",
                    HttpService:JSONEncode({ name = LocalPlayer.Name, ts = os.time(), role = role }))
            end)
            task.wait(1)
        end
    end)
end

F.loadSettings()
OasisUI:Notify({ Title = SCRIPT_NAME, Content = "Fling loaded (commands only). Type !help for the list.", Type = "Success", Duration = 4 })

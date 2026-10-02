-- language: Lua, file: prisonlife.lua, target: Prison Life (PlaceId 155615604)
-- *Prison Life: rig R6. silent via remote UpdateMousePos ou Mouse.Hit/Target.*

-- CONFIG
getgenv().JF = getgenv().JF or {}
local CFG = getgenv().JF
CFG.aimbot = CFG.aimbot or {
    enabled=false, key=Enum.UserInputType.MouseButton2, fov=150,
    smoothness=1.0, y_offset=1.5, vis_check=false, team_check=false,
    auto_switch=true, override_cam=false, bone="Head",
}
CFG.silent = CFG.silent or { remote=false, mouse=false, prediction=0.165, hitchance=100 }
CFG.esp = CFG.esp or {
    box=true, skeleton=true, box_color=Color3.fromRGB(55,0,61),
    skeleton_color=Color3.fromRGB(25,45,100), name_color=Color3.fromRGB(255,255,255),
    max_dist=1000,
}

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Camera           = Workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

local RIG = {
    aim = {"Head", "Torso", "HumanoidRootPart"},
    skeleton = {
        {"Head","Torso"},{"Torso","HumanoidRootPart"},
        {"Torso","Left Arm"},{"Torso","Right Arm"},
        {"HumanoidRootPart","Left Leg"},{"HumanoidRootPart","Right Leg"},
    },
    head = "Head", hrp = "HumanoidRootPart",
}

-- HELPERS
local function world_to_screen(pos)
    local sp, on = Camera:WorldToViewportPoint(pos)
    if not on then return nil end
    return Vector2.new(sp.X, sp.Y), sp.Z
end

local function get_char(player)
    local char = player.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return char, hum
end

local function get_aim_part(char)
    return char:FindFirstChild(CFG.aimbot.bone) or char:FindFirstChild(RIG.head) or char:FindFirstChild(RIG.hrp)
end

local function is_target_valid(player)
    if player == LocalPlayer then return false end
    if CFG.aimbot.team_check and player.Team and player.Team == LocalPlayer.Team then return false end
    return true
end

local function find_target()
    local center = Camera.ViewportSize / 2
    local closest, closest_dist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if is_target_valid(player) then
            local char = get_char(player)
            if char then
                local part = get_aim_part(char)
                if part then
                    local aim_pos = part.Position + Vector3.new(0, CFG.aimbot.y_offset or 0, 0)
                    local sp = world_to_screen(aim_pos)
                    if sp then
                        local sd = (sp - center).Magnitude
                        if sd <= CFG.aimbot.fov then
                            local d3 = (part.Position - Camera.CFrame.Position).Magnitude
                            if d3 < closest_dist then
                                closest_dist = d3
                                closest = { Player=player, Part=part, Position=aim_pos, Distance=d3, Char=char }
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- SILENT — remote UpdateMousePos
local mt = getrawmetatable(game)
local old_namecall = mt.__namecall
pcall(function() setreadonly(mt, false) end)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = { ... }

    if CFG.silent.remote and method == "FireServer" and not checkcaller() and args[1] == "UpdateMousePos" then
        local target = find_target()
        if target and math.random(0, 100) <= CFG.silent.hitchance then
            local hrp = target.Char:FindFirstChild(RIG.hrp)
            local predicted = target.Part.Position
            if hrp then predicted = predicted + (hrp.AssemblyLinearVelocity * CFG.silent.prediction) end
            args[3] = predicted
        end
    end

    return old_namecall(self, unpack(args))
end)

pcall(function() setreadonly(mt, true) end)

-- SILENT — Mouse.Hit/Target hook
local Mouse = LocalPlayer:GetMouse()
local mouse_mt = getrawmetatable(Mouse)
local mouse_index_orig = mouse_mt and mouse_mt.__index

local function apply_mouse_hook()
    if not CFG.silent.mouse or not mouse_mt then return end
    local target = find_target()
    if not target then return end
    pcall(function()
        setreadonly(mouse_mt, false)
        mouse_mt.__index = newcclosure(function(self, key)
            if self == Mouse and key == "Hit" then
                return CFrame.new(Camera.CFrame.Position, target.Position)
            elseif self == Mouse and key == "Target" then
                return target.Part
            end
            return mouse_index_orig(self, key)
        end)
        setreadonly(mouse_mt, true)
    end)
end

-- AIMBOT
local holding = false
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then holding = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then holding = false end
end)

RunService.RenderStepped:Connect(function()
    if CFG.silent.mouse then apply_mouse_hook() end
    if CFG.aimbot.enabled and holding then
        local t = find_target()
        if t then
            if CFG.aimbot.override_cam then Camera.CameraType = Enum.CameraType.Scriptable end
            local cf = CFrame.new(Camera.CFrame.Position, t.Position)
            Camera.CFrame = CFG.aimbot.smoothness >= 0.99 and cf or Camera.CFrame:Lerp(cf, CFG.aimbot.smoothness)
        end
    end
end)

-- ESP
local esp_cache = {}
local function new_drawing(kind)
    local ok, d = pcall(function() return Drawing.new(kind) end)
    if not ok then return nil end
    return d
end

local function create_esp(player)
    if esp_cache[player] then return esp_cache[player] end
    local e = { box=new_drawing("Square"), box_outline=new_drawing("Square"), name=new_drawing("Text"), lines={} }
    if e.box then e.box.Thickness=1; e.box.Filled=false; e.box.Transparency=1; e.box.Visible=false end
    if e.box_outline then e.box_outline.Thickness=3; e.box_outline.Color=Color3.new(0,0,0)
        e.box_outline.Filled=false; e.box_outline.Transparency=1; e.box_outline.Visible=false end
    if e.name then e.name.Size=14; e.name.Center=true; e.name.Outline=true; e.name.Visible=false end
    for _ = 1, #RIG.skeleton do
        local line = new_drawing("Line")
        if line then line.Thickness=1.5; line.Transparency=1; line.Visible=false end
        table.insert(e.lines, line)
    end
    esp_cache[player] = e
    return e
end

local function get_box_bounds(char, hrp)
    local head = char:FindFirstChild(RIG.head); if not head then return nil end
    local top_s = world_to_screen(head.Position + Vector3.new(0, head.Size.Y/2, 0))
    local bot_s = world_to_screen(hrp.Position - Vector3.new(0, 3, 0))
    if not top_s or not bot_s then return nil end
    local h = math.abs(bot_s.Y - top_s.Y); if h <= 0 then return nil end
    local w = h * 0.55
    return Vector2.new((top_s.X + bot_s.X)/2 - w/2, math.min(top_s.Y, bot_s.Y)), w, h
end

RunService.RenderStepped:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char, hum = get_char(player)
            if char then
                local hrp = char:FindFirstChild(RIG.hrp)
                if hrp then
                    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                    if dist <= CFG.esp.max_dist then
                        local e = create_esp(player)
                        local tl, w, h = get_box_bounds(char, hrp)
                        if tl then
                            if CFG.esp.box and e.box then
                                e.box.Size = Vector2.new(w, h); e.box.Position = tl
                                e.box.Color = CFG.esp.box_color; e.box.Visible = true
                                if e.box_outline then
                                    e.box_outline.Size = Vector2.new(w, h); e.box_outline.Position = tl; e.box_outline.Visible = true
                                end
                            end
                            if e.name then
                                local head = char:FindFirstChild(RIG.head)
                                local hs = head and world_to_screen(head.Position + Vector3.new(0, head.Size.Y, 0))
                                if hs then
                                    e.name.Position = Vector2.new(tl.X + w/2, hs.Y)
                                    e.name.Text = string.format("%s [%dm]", player.Name, math.floor(dist))
                                    e.name.Color = CFG.esp.name_color; e.name.Visible = true
                                end
                            end
                            if CFG.esp.skeleton then
                                for i, pair in ipairs(RIG.skeleton) do
                                    local line = e.lines[i]
                                    local a = char:FindFirstChild(pair[1]); local b = char:FindFirstChild(pair[2])
                                    if line and a and b then
                                        local sa = world_to_screen(a.Position); local sb = world_to_screen(b.Position)
                                        if sa and sb then line.From=sa; line.To=sb; line.Color=CFG.esp.skeleton_color; line.Visible=true
                                        else line.Visible=false end
                                    elseif line then line.Visible = false end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    local e = esp_cache[p]
    if e then
        if e.box then e.box:Remove() end
        if e.box_outline then e.box_outline:Remove() end
        if e.name then e.name:Remove() end
        for _, line in ipairs(e.lines) do if line then line:Remove() end end
        esp_cache[p] = nil
    end
end)

-- UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title="jeetfed", SubTitle="Prison Life | R6",
    TabWidth=160, Size=UDim2.fromOffset(560,460),
    Acrylic=true, Theme="Dark", MinimizeKey=Enum.KeyCode.Insert,
})
Fluent:SetTheme({ Accent=Color3.fromRGB(55,0,61), Background=Color3.fromRGB(0,0,0), Text=Color3.fromRGB(255,255,255) })

local Tabs = {
    Aim=Window:AddTab({Title="Aim", Icon="crosshair"}),
    Silent=Window:AddTab({Title="Silent", Icon="eye-off"}),
    Visual=Window:AddTab({Title="Visual", Icon="eye"}),
}

Tabs.Aim:AddSection("Aimbot")
local a = Tabs.Aim:AddToggle("A1", {Title="Enable Aimbot", Default=false})
a:OnChanged(function(v) CFG.aimbot.enabled = v end)
local f = Tabs.Aim:AddSlider("A1F", {Title="FOV", Min=10, Max=800, Default=150, Rounding=0})
f:OnChanged(function(v) CFG.aimbot.fov = v end)
local s = Tabs.Aim:AddSlider("A1S", {Title="Smoothness", Min=0.01, Max=1, Default=1, Rounding=2})
s:OnChanged(function(v) CFG.aimbot.smoothness = v end)

Tabs.Silent:AddSection("Prison Life")
local sr = Tabs.Silent:AddToggle("SR", {Title="Silent (remote UpdateMousePos)", Default=false})
sr:OnChanged(function(v) CFG.silent.remote = v end)
local sm = Tabs.Silent:AddToggle("SM", {Title="Silent (Mouse.Hit/Target)", Default=false})
sm:OnChanged(function(v) CFG.silent.mouse = v end)
local mp = Tabs.Silent:AddSlider("MP", {Title="Prediction", Min=0.01, Max=1, Default=0.165, Rounding=3})
mp:OnChanged(function(v) CFG.silent.prediction = v end)

Tabs.Visual:AddSection("ESP (R6)")
local eb = Tabs.Visual:AddToggle("EB", {Title="ESP Box", Default=true})
eb:OnChanged(function(v) CFG.esp.box = v end)
local es = Tabs.Visual:AddToggle("ES", {Title="ESP Skeleton", Default=true})
es:OnChanged(function(v) CFG.esp.skeleton = v end)

Fluent:Notify({Title="jeetfed", Content="Prison Life carregado. R6.", Duration=4})

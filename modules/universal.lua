local function apply_universal_magic()
    if not CFG.magic.enabled then return end
    local target = find_target()
    if not target then return end

    pcall(function()
        local orig = Workspace.Raycast
        if type(orig) == "function" and not rawget(Workspace, "__jf_hooked") then
            rawset(Workspace, "__jf_hooked", true)
            Workspace.Raycast = newcclosure(function(self, origin, direction, params)
                local t = find_target()
                if t then
                    local hrp = t.Char:FindFirstChild(RIG.hrp)
                    local predicted = t.Part.Position
                    if hrp then predicted = predicted + (hrp.AssemblyLinearVelocity * CFG.magic.prediction) end
                    direction = (predicted - origin).Unit * direction.Magnitude
                end
                return orig(self, origin, direction, params)
            end)
        end
    end)

    pcall(function()
        local orig = Camera.WorldToScreenPoint
        if type(orig) == "function" then
            Camera.WorldToScreenPoint = newcclosure(function(self, pos, ...)
                if typeof(pos) == "Vector3" and (pos - target.Part.Position).Magnitude < 3 then
                    return Vector3.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2, pos.Z), true
                end
                return orig(self, pos, ...)
            end)
        end
    end)

    pcall(function()
        local orig = Camera.WorldToViewportPoint
        if type(orig) == "function" then
            Camera.WorldToViewportPoint = newcclosure(function(self, pos, ...)
                if typeof(pos) == "Vector3" and (pos - target.Part.Position).Magnitude < 3 then
                    return Vector3.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2, pos.Z), true
                end
                return orig(self, pos, ...)
            end)
        end
    end)
end

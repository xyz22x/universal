-- language: Lua, file: loader.lua, target: Roblox (executor 98% UNC)
-- *lê PlaceId, carrega o módulo do jogo. fallback universal. tudo em pcall.*
-- *troque BASE pela URL raw do seu repo antes de subir.*

local Loader = {}

local GAME_MODULES = {
    [155615604]       = "prisonlife",
    [84556640895285]  = "deagle",
    [9534705677]      = "sniper",
    [90568084448279]  = "onetap",
    [116232903312659] = "gunfight",
    [116293316214063] = "combat",
    [112757576021097] = "defusal",
}

local BASE = "https://raw.githubusercontent.com/xyz22/universal/main/modules/"

local function load_module(name)
    local url = BASE .. name .. ".lua"
    local ok, code = pcall(function() return game:HttpGet(url, true) end)
    if not ok or not code or code == "" then
        return nil, "falha ao baixar " .. name
    end
    local fn, err = loadstring(code)
    if not fn then
        return nil, "erro de sintaxe em " .. name .. ": " .. tostring(err)
    end
    local ok2, result = pcall(fn)
    if not ok2 then
        return nil, "erro ao executar " .. name .. ": " .. tostring(result)
    end
    return result or true
end

local place = game.PlaceId
local module_name = GAME_MODULES[place]

if module_name then
    local ok, err = load_module(module_name)
    if not ok then
        warn("[jeetfed] " .. tostring(err) .. " — caindo pro universal")
        load_module("universal")
    end
else
    load_module("universal")
end

return Loader

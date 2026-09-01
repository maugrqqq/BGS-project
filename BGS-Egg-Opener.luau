local RayfieldSrc = game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua')
RayfieldSrc = RayfieldSrc:gsub('Settings%.ConfigurationSaving%.FileName = tostring%(game%.PlaceId%)', 'Settings.ConfigurationSaving.FileName = tostring(game.JobId)')
local Rayfield = loadstring(RayfieldSrc)()

local Window = Rayfield:CreateWindow({
    Name = "BGS Egg Opener",
    Icon = 4483362458,
    LoadingTitle = "BGS Project",
    LoadingSubtitle = "by maugrqqq",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "BGS_Egg_Opener"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
    KeySystem = false
})

local Tab = Window:CreateTab("Egg Opener", 4483362458)

local selectedEgg = "Spotted Egg"
local autoHatchEnabled = false
local tripleHatchEnabled = false
local speedBoostEnabled = false
local shinyBoostEnabled = false
local mythicBoostEnabled = false
local noCooldownEnabled = false
local currentCooldown = 3

local eggList = {
    "Common Egg",
    "Spotted Egg",
    "Ice Shard Egg",
    "Spikey Egg",
    "Magma Egg",
    "Crystal Egg",
    "Lunar Egg",
    "Void Shard Egg",
    "Nightmare Egg",
    "Hell Egg",
    "Rainbow Egg",
    "New Year Egg",
    "100K Egg",
    "Valentine Egg",
    "Lucky Egg",
    "300m Egg",
    "Snowman Egg",
    "Festive Egg",
    "Globe Egg",
    "Hot Cocoa Egg",
    "Frost Egg",
    "Christmas Egg",
    "Ice Cream Egg",
    "Gummy Egg",
    "Slushy Egg"
}

local EggService = require(game.ReplicatedStorage.Assets.Modules.EggService)
local Services = require(game.ReplicatedStorage.Assets.Modules.Services)
local LocalPlayer = game.Players.LocalPlayer

local oldGetHatchCooldown = EggService.GetHatchCooldown
local oldIs2xShinyEnabled = Services:GetService("Is2xShinyEnabled")
local oldIs2xMythicEnabled = Services:GetService("Is2xMythicEnabled")
local oldIs2xSpeedEnabled = Services:GetService("Is2xSpeedEnabled")

local function updateCooldown()
    if noCooldownEnabled then
        currentCooldown = 0.05
    else
        local baseCooldown = oldGetHatchCooldown(EggService, LocalPlayer)
        if speedBoostEnabled then
            currentCooldown = baseCooldown * 0.75
        else
            currentCooldown = baseCooldown
        end
    end
    return currentCooldown
end

local function updateBoosts()
    if shinyBoostEnabled then
        Services:SetService("Is2xShinyEnabled", function() return true end)
    else
        Services:SetService("Is2xShinyEnabled", oldIs2xShinyEnabled)
    end
    if mythicBoostEnabled then
        Services:SetService("Is2xMythicEnabled", function() return true end)
    else
        Services:SetService("Is2xMythicEnabled", oldIs2xMythicEnabled)
    end
    if speedBoostEnabled then
        Services:SetService("Is2xSpeedEnabled", function() return true end)
    else
        Services:SetService("Is2xSpeedEnabled", oldIs2xSpeedEnabled)
    end
end

Tab:CreateDropdown({
    Name = "Select Egg",
    Options = eggList,
    CurrentOption = {"Spotted Egg"},
    Callback = function(Option)
        selectedEgg = Option
    end
})

Tab:CreateToggle({
    Name = "Open Selected Egg",
    CurrentValue = false,
    Callback = function(Value)
        autoHatchEnabled = Value
    end
})

Tab:CreateToggle({
    Name = "Triple Hatch",
    CurrentValue = false,
    Callback = function(Value)
        tripleHatchEnabled = Value
    end
})

Tab:CreateToggle({
    Name = "2x Speed Boost",
    CurrentValue = false,
    Callback = function(Value)
        speedBoostEnabled = Value
        updateBoosts()
        updateCooldown()
    end
})

Tab:CreateToggle({
    Name = "2x Shiny Luck",
    CurrentValue = false,
    Callback = function(Value)
        shinyBoostEnabled = Value
        updateBoosts()
    end
})

Tab:CreateToggle({
    Name = "2x Mythic Luck",
    CurrentValue = false,
    Callback = function(Value)
        mythicBoostEnabled = Value
        updateBoosts()
    end
})

Tab:CreateToggle({
    Name = "No Cooldown (0.05s)",
    CurrentValue = false,
    Callback = function(Value)
        noCooldownEnabled = Value
        updateCooldown()
    end
})

Tab:CreateLabel("Current Cooldown: " .. tostring(currentCooldown) .. "s")

Tab:CreateButton({
    Name = "Hatch Egg",
    Callback = function()
        local RemoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild("NetworkRemoteEvent")
        if RemoteEvent then
            RemoteEvent:FireServer("PurchaseEgg", selectedEgg, tripleHatchEnabled)
        end
    end
})

task.spawn(function()
    while true do
        if autoHatchEnabled then
            local RemoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild("NetworkRemoteEvent")
            if RemoteEvent then
                RemoteEvent:FireServer("PurchaseEgg", selectedEgg, tripleHatchEnabled)
            end
        end
        wait(updateCooldown())
    end
end)

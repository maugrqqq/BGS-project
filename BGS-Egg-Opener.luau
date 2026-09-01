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
local weekendEventEnabled = false
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
local LocalPlayer = game.Players.LocalPlayer
local WeekendEventSchedule = require(game.ReplicatedStorage.Assets.Modules.WeekendEventSchedule)

local oldIsActive = WeekendEventSchedule.IsActive

local function updateWeekendEvent()
    if weekendEventEnabled then
        WeekendEventSchedule.IsActive = function(self, p1, p2)
            return true
        end
    else
        WeekendEventSchedule.IsActive = oldIsActive
    end
    currentCooldown = EggService:GetHatchCooldown(LocalPlayer)
    return currentCooldown
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

Tab:CreateParagraph({
    Title = "Events",
    Content = "Activate weekend events (2x Speed, 2x Luck, etc.)"
})

Tab:CreateToggle({
    Name = "Enable Weekend Event",
    CurrentValue = false,
    Callback = function(Value)
        weekendEventEnabled = Value
        updateWeekendEvent()
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
        local cooldown = EggService:GetHatchCooldown(LocalPlayer)
        wait(cooldown)
    end
end)

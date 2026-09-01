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
local hatchInterval = 0.5

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

Tab:CreateDropdown({
    Name = "Select Egg",
    Options = eggList,
    CurrentOption = {"Spotted Egg"},
    Callback = function(Option)
        selectedEgg = Option
    end
})

Tab:CreateSlider({
    Name = "Hatch Interval (seconds)",
    Range = {0.1, 5},
    Increment = 0.1,
    CurrentValue = 0.5,
    Callback = function(Value)
        hatchInterval = Value
    end
})

Tab:CreateToggle({
    Name = "Auto Hatch Selected Egg",
    CurrentValue = false,
    Callback = function(Value)
        autoHatchEnabled = Value
    end
})

Tab:CreateButton({
    Name = "Open Selected Egg",
    Callback = function()
        local RemoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild("NetworkRemoteEvent")
        if RemoteEvent then
            RemoteEvent:FireServer("PurchaseEgg", selectedEgg, false)
        end
    end
})

task.spawn(function()
    while true do
        if autoHatchEnabled then
            local RemoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild("NetworkRemoteEvent")
            if RemoteEvent then
                RemoteEvent:FireServer("PurchaseEgg", selectedEgg, false)
            end
        end
        wait(hatchInterval)
    end
end)

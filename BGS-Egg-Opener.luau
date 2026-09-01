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

local eggsFolder = game:GetService('Workspace'):FindFirstChild('Eggs')
local eggList = {}

if eggsFolder then
    for _, child in ipairs(eggsFolder:GetChildren()) do
        if child:IsA('Model') and child.Name:find('Egg') then
            table.insert(eggList, child.Name)
        end
    end
end

table.sort(eggList)

if #eggList == 0 then
    eggList = {"Common Egg", "Spotted Egg", "Hacker Egg", "Alien Egg", "Space Crystal Egg"}
end

local Event = game:GetService('ReplicatedStorage').NetworkRemoteEvent

local function hatchEgg()
    local success, err = pcall(function()
        Event:FireServer('PurchaseEgg', selectedEgg, tripleHatchEnabled)
    end)
    if not success then
        print('[BGS] Error:', err)
    end
end

Tab:CreateDropdown({
    Name = "Select Egg",
    Options = eggList,
    CurrentOption = {"Spotted Egg"},
    Callback = function(OptionTable)
        selectedEgg = OptionTable[1]
        print('[BGS] Selected:', selectedEgg)
    end
})

Tab:CreateToggle({
    Name = "Open Selected Egg",
    CurrentValue = false,
    Callback = function(Value)
        autoHatchEnabled = Value
        print('[BGS] Auto Hatch:', Value)
    end
})

Tab:CreateToggle({
    Name = "Triple Hatch",
    CurrentValue = false,
    Callback = function(Value)
        tripleHatchEnabled = Value
        print('[BGS] Triple Hatch:', Value)
    end
})

Tab:CreateParagraph({
    Title = "Events",
    Content = "Activate weekend events"
})

Tab:CreateToggle({
    Name = "Enable Weekend Event",
    CurrentValue = false,
    Callback = function(Value)
        weekendEventEnabled = Value
        local WeekendEventSchedule = require(game.ReplicatedStorage.Assets.Modules.WeekendEventSchedule)
        if Value then
            WeekendEventSchedule.IsActive = function(self, p1, p2) return true end
        else
            WeekendEventSchedule.IsActive = function(self, p1, p2) return false end
        end
        print('[BGS] Weekend Event:', Value)
    end
})

task.spawn(function()
    while true do
        if autoHatchEnabled then
            hatchEgg()
        end
        wait(0.5)
    end
end)

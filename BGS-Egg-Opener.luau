local RayfieldSrc = game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua')
RayfieldSrc = RayfieldSrc:gsub('Settings%.ConfigurationSaving%.FileName = tostring%(game%.PlaceId%)', 'Settings.ConfigurationSaving.FileName = tostring(game.JobId)')
local Rayfield = loadstring(RayfieldSrc)()

local Window = Rayfield:CreateWindow({
    Name = "BGS Egg Opener",
    Icon = 4483362458,
    LoadingTitle = "BGS Project",
    LoadingSubtitle = "by maugrqqq",
    Theme = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
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

local selectedEgg = "Hacker Egg"
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
local leaderstats = game.Players.LocalPlayer:WaitForChild('leaderstats')
local eggsOpenedValue = leaderstats:WaitForChild('Eggs Opened')

local lastEggsCount = eggsOpenedValue.Value
local lastUpdateTime = os.clock()
local eggsPerMinute = 0
local eggsPerHour = 0

local statsWindow = {}
local MAX_STATS_WINDOW = 10

local StatsLabel = Tab:CreateLabel("Eggs Opened: " .. tostring(eggsOpenedValue.Value))
local RateLabel = Tab:CreateLabel("Rate: 0/min | 0/hr")

local function hatchEgg()
    local success, err = pcall(function()
        Event:FireServer('PurchaseEgg', selectedEgg, tripleHatchEnabled)
    end)
    if not success then
        print('[BGS] Error:', err)
    end
end

local function updateStats()
    local currentCount = eggsOpenedValue.Value
    local currentTime = os.clock()
    local deltaTime = currentTime - lastUpdateTime
    
    if deltaTime > 0 then
        local deltaEggs = currentCount - lastEggsCount
        if deltaEggs > 0 then
            table.insert(statsWindow, {
                time = currentTime,
                count = deltaEggs
            })
        end
    end
    
    while #statsWindow > 0 and currentTime - statsWindow[1].time > MAX_STATS_WINDOW do
        table.remove(statsWindow, 1)
    end
    
    local totalEggs = 0
    local windowDuration = math.min(currentTime - lastUpdateTime, MAX_STATS_WINDOW)
    
    for _, entry in ipairs(statsWindow) do
        totalEggs = totalEggs + entry.count
    end
    
    if windowDuration > 0 and #statsWindow > 0 then
        local oldestTime = statsWindow[1].time
        local actualDuration = currentTime - oldestTime
        if actualDuration > 0 then
            eggsPerMinute = (totalEggs / actualDuration) * 60
            eggsPerHour = (totalEggs / actualDuration) * 3600
        end
    elseif deltaTime > 5 then
        eggsPerMinute = 0
        eggsPerHour = 0
    end
    
    lastEggsCount = currentCount
    lastUpdateTime = currentTime
    
    StatsLabel:Set("Eggs Opened: " .. tostring(currentCount))
    RateLabel:Set(string.format("Rate: %.0f/min | %.0f/hr", eggsPerMinute, eggsPerHour))
end

Tab:CreateDropdown({
    Name = "Select Egg",
    Options = eggList,
    CurrentOption = {"Hacker Egg"},
    Callback = function(OptionTable)
        if type(OptionTable) == 'table' and #OptionTable > 0 then
            selectedEgg = OptionTable[1]
            print('[BGS] Selected:', selectedEgg)
        end
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
        updateStats()
        wait(0.5)
    end
end)

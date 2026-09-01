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

local StatsLabel = Tab:CreateLabel("Eggs Opened: " .. tostring(eggsOpenedValue.Value))
local RateLabel = Tab:CreateLabel("Rate: calculating...")

local countStart = 0
local countEnd = 0
local timerStarted = false
local timerStartTime = 0
local eggsPerMinute = 0
local eggsPerHour = 0

local function hatchEgg()
    local success, err = pcall(function()
        Event:FireServer('PurchaseEgg', selectedEgg, tripleHatchEnabled)
    end)
    if not success then
        print('[BGS] Error:', err)
    end
end

local function startTimer()
    countStart = eggsOpenedValue.Value
    timerStarted = true
    timerStartTime = os.clock()
    print('[BGS] Timer started at:', countStart)
end

local function checkTimer()
    if not timerStarted then return end
    
    local elapsed = os.clock() - timerStartTime
    
    if elapsed >= 60 then
        countEnd = eggsOpenedValue.Value
        eggsPerMinute = countEnd - countStart
        eggsPerHour = eggsPerMinute * 60
        
        print('[BGS] Timer complete. Started:', countStart, 'Ended:', countEnd, 'Per min:', eggsPerMinute)
        
        RateLabel:Set(string.format("Rate: %d/min | %d/hr", eggsPerMinute, eggsPerHour))
        
        timerStarted = false
    else
        local currentCount = eggsOpenedValue.Value
        local progressEggs = currentCount - countStart
        local projectedMinute = progressEggs / (elapsed / 60)
        RateLabel:Set(string.format("Progress: %d/%d | %.0f/min", progressEggs, 60 - math.floor(elapsed), projectedMinute))
    end
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
        if Value then
            startTimer()
        else
            timerStarted = false
            RateLabel:Set("Rate: stopped")
        end
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
        StatsLabel:Set("Eggs Opened: " .. tostring(eggsOpenedValue.Value))
        checkTimer()
        wait(0.5)
    end
end)

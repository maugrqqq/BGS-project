local NetworkRemoteEvent = game.ReplicatedStorage.NetworkRemoteEvent

local RayfieldSrc = game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua')
RayfieldSrc = RayfieldSrc:gsub('Settings%.ConfigurationSaving%.FileName = tostring%(game%.PlaceId%)', 'Settings.ConfigurationSaving.FileName = tostring(game.JobId)')
local Rayfield = loadstring(RayfieldSrc)()

local CONFIG_FILE = 'BGS_Egg_Opener_Config.json'
local HttpService = game:GetService('HttpService')
local function loadConfig()
    local ok, data = pcall(function() if isfile(CONFIG_FILE) then return HttpService:JSONDecode(readfile(CONFIG_FILE)) end return {} end)
    if ok then return data end return {}
end
local function saveConfig(cfg) pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end) end
local config = loadConfig()

task.spawn(function()
    local CoreGui = game:GetService('CoreGui')
    while true do
        pcall(function()
            for _, name in ipairs({'RobloxPromptGui','PurchasePromptApp','BulkPurchaseApp','CommercePurchaseApp'}) do
                local obj = CoreGui:FindFirstChild(name) if obj then obj:Destroy() end
            end
        end)
        wait(0.2)
    end
end)

local Window = Rayfield:CreateWindow({Name='BGS Egg Opener', Icon=4483362458, LoadingTitle='BGS Project', LoadingSubtitle='by maugrqqq', Theme='Default', DisableRayfieldPrompts=true, DisableBuildWarnings=true, ConfigurationSaving={Enabled=true, FolderName=nil, FileName='BGS_Egg_Opener'}, Discord={Enabled=false, Invite='', RememberJoins=true}, KeySystem=false})
local MainTab = Window:CreateTab('Main', 4483362458)
local EventTab = Window:CreateTab('Events', 4483362458)
local WebhookTab = Window:CreateTab('Webhook', 4483362458)
local TasksTab = Window:CreateTab('Tasks', 4483362458)

local selectedEgg = config.selectedEgg or 'Hacker Egg'
local autoHatchEnabled = config.autoHatchEnabled or false
local tripleHatchEnabled = config.tripleHatchEnabled or false
local webhookEnabled = config.webhookEnabled or false
local webhookURL = config.webhookURL or ''
local eventsEnabled = config.eventsEnabled or false
local autoGroupBenefits = config.autoGroupBenefits or false
local autoSpinToWin = config.autoSpinToWin or false
local autoDailyRewards = config.autoDailyRewards or false

local LocalPlayer = game.Players.LocalPlayer
local Workspace = game:GetService('Workspace')
local Event = game:GetService('ReplicatedStorage').NetworkRemoteEvent
local RunService = game:GetService('RunService')
local Services = require(game.ReplicatedStorage.Assets.Modules.Services)
local GuiService = Services:GetService('GuiService')
local ScreenGui = LocalPlayer.PlayerGui:WaitForChild('ScreenGui', 10)

local eggsFolder = Workspace:FindFirstChild('Eggs')
local eggList = {}
if eggsFolder then for _, child in ipairs(eggsFolder:GetChildren()) do if child:IsA('Model') and child.Name:find('Egg') then table.insert(eggList, child.Name) end end end
table.sort(eggList) if #eggList == 0 then eggList = {'Common Egg','Spotted Egg','Hacker Egg'} end

local groupSeconds = 0
local dailyText = '...'
local lastGroupRefresh = 0
local lastDailyRefresh = 0
local GROUP_REFRESH_INTERVAL = 30
local DAILY_REFRESH_INTERVAL = 10

local function getCharacter() return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() end
local function getEggPosition()
    local eggModel = eggsFolder and eggsFolder:FindFirstChild(selectedEgg)
    if not eggModel then return nil end
    local primary = eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA('BasePart')
    if not primary then return nil end
    return primary.Position
end
local teleportLoop = nil
local function startTeleportLoop()
    if teleportLoop then return end
    teleportLoop = RunService.RenderStepped:Connect(function()
        local char = getCharacter() local root = char:FindFirstChild('HumanoidRootPart')
        if not root then return end
        local eggPos = getEggPosition()
        if eggPos then root.CFrame = CFrame.new(eggPos + Vector3.new(0, 10, 0)) end
    end)
end
local function stopTeleportLoop() if teleportLoop then teleportLoop:Disconnect() teleportLoop = nil end end
local function hatchEgg() pcall(function() Event:FireServer('PurchaseEgg', selectedEgg, tripleHatchEnabled) end) end
local function formatTime(seconds)
    local h = math.floor(seconds / 3600) local m = math.floor((seconds % 3600) / 60) local s = math.floor(seconds % 60)
    if h > 0 then return string.format('%dh %dm %ds', h, m, s) end
    return string.format('%dm %ds', m, s)
end

local function readGroupSeconds()
    pcall(function() GuiService:ShowGroupBenefits() end)
    for attempt = 1, 6 do
        wait(0.4)
        local problemFrame = ScreenGui:FindFirstChild('GroupBenefitsProblem')
        if problemFrame then
            for _, d in ipairs(problemFrame:GetDescendants()) do
                if d:IsA('TextLabel') and d.Name == 'Desc' and d.Text ~= '' then
                    local text = d.Text
                    local hours = text:match('(%d+)h') or 0
                    local mins = text:match('(%d+)m') or 0
                    local secs = text:match('(%d+)s') or 0
                    local total = tonumber(hours) * 3600 + tonumber(mins) * 60 + tonumber(secs)
                    problemFrame.Visible = false
                    return total
                end
            end
        end
    end
    return 0
end

local function readDailyText()
    pcall(function() GuiService:DisplayFrame('DailyRewards') end)
    for attempt = 1, 6 do
        wait(0.4)
        local frame = ScreenGui:FindFirstChild('DailyRewards')
        if frame then
            local category, progress, nextReward, claimed = '', '', '', false
            for _, d in ipairs(frame:GetDescendants()) do
                if d:IsA('TextLabel') then
                    if d.Name == 'Category' and d.Text ~= '' then category = d.Text end
                    if d.Text:find('%d+ %/ %d+') then progress = d.Text end
                    if d.Name == 'NextRewardIn' then nextReward = d.Text end
                    if d.Text == 'Claimed reward!' then claimed = true end
                end
            end
            local result = '...'
            if claimed and nextReward ~= '' then result = 'Done! Next in ' .. nextReward:gsub('Next reward in ', '')
            elseif category ~= '' and progress ~= '' then result = category .. ' [' .. progress .. ']'
            elseif category ~= '' then result = category end
            pcall(function() GuiService:DisplayFrame('') end)
            return result
        end
    end
    pcall(function() GuiService:DisplayFrame('') end)
    return '...'
end

local function canClaimDaily()
    if not dailyText or dailyText == '...' then return false end
    if dailyText:find('Done!') then return false end
    local progress = dailyText:match('%[(.-)%]')
    if not progress then return false end
    local currentStr = progress:match('([%d,]+)')
    local targetStr = progress:match('/(%s*[%d,]+)')
    if not currentStr or not targetStr then return false end
    local current = tonumber(currentStr:gsub(',', '')) or 0
    local target = tonumber(targetStr:gsub(',', '')) or 0
    return current >= target
end
local function collectGroupReward()
    pcall(function() Event:FireServer('CollectGroupReward') end)
    wait(0.5) groupSeconds = readGroupSeconds() lastGroupRefresh = os.clock()
end
local function spinToWin() pcall(function() Event:FireServer('SpinToWin') end) end
local function claimDaily()
    pcall(function() Event:FireServer('ClaimDailyReward') end)
    wait(0.5) dailyText = readDailyText() lastDailyRefresh = os.clock()
end
local function enableEvents()
    local WeekendEventSchedule = require(game.ReplicatedStorage.Assets.Modules.WeekendEventSchedule)
    WeekendEventSchedule.IsActive = function() return true end
    local Is2xShiny = require(game.ReplicatedStorage.Assets.Modules.Is2xShinyEnabled)
    local Is2xMythic = require(game.ReplicatedStorage.Assets.Modules.Is2xMythicEnabled)
    pcall(function() debug.setupvalue(Is2xShiny, 1, true) end)
    pcall(function() debug.setupvalue(Is2xMythic, 1, true) end)
end
local function disableEvents()
    local WeekendEventSchedule = require(game.ReplicatedStorage.Assets.Modules.WeekendEventSchedule)
    WeekendEventSchedule.IsActive = function() return false end
    local Is2xShiny = require(game.ReplicatedStorage.Assets.Modules.Is2xShinyEnabled)
    local Is2xMythic = require(game.ReplicatedStorage.Assets.Modules.Is2xMythicEnabled)
    pcall(function() debug.setupvalue(Is2xShiny, 1, false) end)
    pcall(function() debug.setupvalue(Is2xMythic, 1, false) end)
end
local function sendWebhook(message)
    if not webhookEnabled or webhookURL == '' then return end
    pcall(function() HttpService:PostAsync(webhookURL, HttpService:JSONEncode({content = message})) end)
end
local function saveCurrent()
    saveConfig({selectedEgg=selectedEgg, autoHatchEnabled=autoHatchEnabled, tripleHatchEnabled=tripleHatchEnabled, webhookEnabled=webhookEnabled, webhookURL=webhookURL, eventsEnabled=eventsEnabled, autoGroupBenefits=autoGroupBenefits, autoSpinToWin=autoSpinToWin, autoDailyRewards=autoDailyRewards})
end

NetworkRemoteEvent.OnClientEvent:Connect(function(eventName, ...)
    if eventName == 'DisplayLegendaryInChat' then
        local args = {...}
        if webhookEnabled and webhookURL ~= '' then sendWebhook(args[1] .. ' hatched a Legendary ' .. args[2]) end
    end
end)

MainTab:CreateParagraph({Title='Egg Opener', Content='Auto hatch eggs'})
MainTab:CreateDropdown({Name='Select Egg', Options=eggList, CurrentOption={selectedEgg}, Callback=function(opt) selectedEgg = opt[1] saveCurrent() end})
MainTab:CreateToggle({Name='Open Selected Egg', CurrentValue=autoHatchEnabled, Callback=function(v) autoHatchEnabled = v if v then startTeleportLoop() else stopTeleportLoop() end saveCurrent() end})
MainTab:CreateToggle({Name='Triple Hatch', CurrentValue=tripleHatchEnabled, Callback=function(v) tripleHatchEnabled = v saveCurrent() end})
EventTab:CreateParagraph({Title='Events', Content='Activate 2x events'})
EventTab:CreateToggle({Name='Enable Weekend Event', CurrentValue=eventsEnabled, Callback=function(v) eventsEnabled = v if v then enableEvents() else disableEvents() end saveCurrent() end})
WebhookTab:CreateParagraph({Title='Discord Webhook', Content='Send hatched pets to Discord'})
WebhookTab:CreateToggle({Name='Enable Webhook', CurrentValue=webhookEnabled, Callback=function(v) webhookEnabled = v saveCurrent() end})
WebhookTab:CreateInput({Name='Webhook URL', PlaceholderText='https://discord.com/api/webhooks/...', RemoveTextAfterFocusLost=false, Callback=function(text) webhookURL = text saveCurrent() end})
TasksTab:CreateParagraph({Title='Tasks', Content='Auto tasks'})
TasksTab:CreateToggle({Name='Auto Group Benefits', CurrentValue=autoGroupBenefits, Callback=function(v) autoGroupBenefits = v saveCurrent() end})
local GroupLabel = TasksTab:CreateLabel('Loading...')
TasksTab:CreateToggle({Name='Auto Spin To Win', CurrentValue=autoSpinToWin, Callback=function(v) autoSpinToWin = v saveCurrent() end})
local SpinLabel = TasksTab:CreateLabel('Ready')
TasksTab:CreateToggle({Name='Auto Daily Rewards', CurrentValue=autoDailyRewards, Callback=function(v) autoDailyRewards = v saveCurrent() end})
local DailyLabel = TasksTab:CreateLabel('Loading...')

if autoHatchEnabled then startTeleportLoop() end
if eventsEnabled then enableEvents() end

task.spawn(function()
    wait(1)
    groupSeconds = readGroupSeconds() lastGroupRefresh = os.clock()
    dailyText = readDailyText() lastDailyRefresh = os.clock()
    GroupLabel:Set(groupSeconds > 0 and formatTime(groupSeconds) or 'Ready')
    DailyLabel:Set(dailyText)
end)

task.spawn(function()
    local lastTick = os.clock()
    while true do
        local now = os.clock() local delta = now - lastTick lastTick = now
        if groupSeconds > 0 then groupSeconds = math.max(0, groupSeconds - delta) end
        if groupSeconds <= 0 then GroupLabel:Set('Ready') if autoGroupBenefits then collectGroupReward() end
        else GroupLabel:Set(formatTime(groupSeconds)) end
        if now - lastGroupRefresh >= GROUP_REFRESH_INTERVAL then groupSeconds = readGroupSeconds() lastGroupRefresh = now end
        if now - lastDailyRefresh >= DAILY_REFRESH_INTERVAL then dailyText = readDailyText() lastDailyRefresh = now end
        DailyLabel:Set(dailyText)
        if autoDailyRewards and canClaimDaily() then claimDaily() end
        if autoHatchEnabled then hatchEgg() end
        if autoSpinToWin then spinToWin() end
        wait(0.2)
    end
end)

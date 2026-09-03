-- BGS Egg Opener - Fixed v25
-- AlienSpinLabel после тумблера
-- Chat detection: working legacy chat method (OnMessageDoneFiltering with messageData.Message)
-- Misc tab: Auto Blow Toggle, Discover Islands, WalkSpeed and JumpPower

local NetworkRemoteEvent = game.ReplicatedStorage.NetworkRemoteEvent
local Services = require(game.ReplicatedStorage.Assets.Modules.Services)
local GuiService = Services:GetService('GuiService')
local ScreenGui = game.Players.LocalPlayer.PlayerGui:WaitForChild('ScreenGui', 10)
local HttpService = game:GetService('HttpService')
local Event = game:GetService('ReplicatedStorage').NetworkRemoteEvent
local TextChatService = game:GetService('TextChatService')
local TweenService = game:GetService('TweenService')

local function safeSet(label, text)
    if not label then return end
    local ok, err = pcall(function() label:Set(text) end)
    if not ok then
        task.spawn(function() task.wait(0.05) pcall(function() label:Set(text) end) end)
    end
end

pcall(function()
    if gethui then local old = gethui():FindFirstChild('Rayfield') if old then old:Destroy() end end
    local coreOld = game:GetService('CoreGui'):FindFirstChild('Rayfield') if coreOld then coreOld:Destroy() end
end)

local RayfieldSrc = game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua')
RayfieldSrc = RayfieldSrc:gsub('Settings%.ConfigurationSaving%.FileName = tostring%(game%.PlaceId%)', 'Settings.ConfigurationSaving.FileName = tostring(game.JobId)')
local Rayfield = loadstring(RayfieldSrc)()

local CONFIG_FILE = 'BGS_Egg_Opener_Config.json'
local function loadConfig()
    local ok, data = pcall(function() if isfile(CONFIG_FILE) then return HttpService:JSONDecode(readfile(CONFIG_FILE)) end return {} end)
    if ok then return data end return {}
end
local function saveConfig(cfg) pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end) end
local config = loadConfig()

local CoreGui = game:GetService('CoreGui')
local function autoDestroyRobloxPrompts()
    pcall(function()
        for _, name in ipairs({'RobloxPromptGui','PurchasePromptApp','BulkPurchaseApp','CommercePurchaseApp'}) do
            local obj = CoreGui:FindFirstChild(name)
            if obj then obj:Destroy() end
        end
    end)
end

local Window = Rayfield:CreateWindow({
    Name = 'BGS Egg Opener', Icon = 4483362458, LoadingTitle = 'BGS Project', LoadingSubtitle = 'by maugrqqq',
    Theme = 'Default', DisableRayfieldPrompts = true, DisableBuildWarnings = true,
    ConfigurationSaving = {Enabled = true, FolderName = nil, FileName = 'BGS_Egg_Opener'},
    Discord = {Enabled = false, Invite = '', RememberJoins = true}, KeySystem = false
})
local MainTab = Window:CreateTab('Main', 4483362458)
local EventTab = Window:CreateTab('Events', 4483362458)
local WebhookTab = Window:CreateTab('Webhook', 4483362458)
local TasksTab = Window:CreateTab('Tasks', 4483362458)
local MiscTab = Window:CreateTab('Misc', 4483362458)

local selectedEgg = config.selectedEgg or 'Hacker Egg'
local autoHatchEnabled = config.autoHatchEnabled or false
local tripleHatchEnabled = config.tripleHatchEnabled or false
local teleportEnabled = config.teleportEnabled or false
local teleportMode = config.teleportMode or 'On Hatching'
local teleportTimeout = config.teleportTimeout or 5
local webhookEnabled = config.webhookEnabled or false
local webhookURL = config.webhookURL or ''
local eventsEnabled = config.eventsEnabled or false
local autoGroupBenefits = config.autoGroupBenefits or false
local autoSpinToWin = config.autoSpinToWin or false
local autoDailyRewards = config.autoDailyRewards or false
local autoAlienSpinToWin = config.autoAlienSpinToWin or false
local autoBlowEnabled = false
local moveSpeed = 24
local jumpHeight = 70

local LocalPlayer = game.Players.LocalPlayer
local Workspace = game:GetService('Workspace')
local RunService = game:GetService('RunService')

local eggsFolder = Workspace:FindFirstChild('Eggs')
local eggList = {}
if eggsFolder then
    for _, child in ipairs(eggsFolder:GetChildren()) do
        if child:IsA('Model') and child.Name:find('Egg') then table.insert(eggList, child.Name) end
    end
end
table.sort(eggList)
if #eggList == 0 then eggList = {'Common Egg','Spotted Egg','Hacker Egg'} end

local groupSeconds = -1
local dailyText = 'Off'
local dailySeconds = -1
local spinSeconds = -1
local alienSpinSeconds = -1
local lastGroupRefresh = 0
local lastDailyRefresh = 0
local lastSpinRefresh = 0
local lastAlienSpinRefresh = 0
local SYNC_INTERVAL = 90

local function getCharacter() return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() end
local function getEggPosition()
    local eggModel = eggsFolder and eggsFolder:FindFirstChild(selectedEgg)
    if not eggModel then return nil end
    local primary = eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA('BasePart')
    if not primary then return nil end
    return primary.Position
end

local function teleportToSelectedEgg()
    if not autoHatchEnabled then return end
    local eggPos = getEggPosition()
    if not eggPos then return end
    local char = getCharacter()
    local root = char:FindFirstChild('HumanoidRootPart')
    if root then
        root.CFrame = CFrame.new(eggPos + Vector3.new(0, 10, 0))
    end
end

local function getEggsOpened()
    local leaderstats = LocalPlayer:FindFirstChild('leaderstats')
    if leaderstats then
        local eggsOpened = leaderstats:FindFirstChild('Eggs Opened')
        if eggsOpened and eggsOpened:IsA('IntValue') then
            return eggsOpened.Value
        end
    end
    return -1
end

local function hatchEgg() pcall(function() Event:FireServer('PurchaseEgg', selectedEgg, tripleHatchEnabled) end) end
local function formatTime(seconds)
    local h = math.floor(seconds / 3600) local m = math.floor((seconds % 3600) / 60) local s = math.floor(seconds % 60)
    if h > 0 then return string.format('%dh %dm %ds', h, m, s) end
    return string.format('%dm %ds', m, s)
end

local function parseTimeFromText(text)
    if not text then return -1 end
    for hours, mins, secs in text:gmatch('(%d+)h%s*(%d+)m%s*(%d+)s') do
        return tonumber(hours) * 3600 + tonumber(mins) * 60 + tonumber(secs)
    end
    for mins, secs in text:gmatch('(%d+)m%s*(%d+)s') do
        return tonumber(mins) * 60 + tonumber(secs)
    end
    return -1
end

local function readGroupSeconds()
    local deadline = os.clock() + 8
    repeat
        pcall(function() GuiService:ShowGroupBenefits() end)
        wait(0.4)
        local problemFrame = ScreenGui:FindFirstChild('GroupBenefitsProblem')
        if problemFrame then
            for _, d in ipairs(problemFrame:GetDescendants()) do
                if d:IsA('TextLabel') and d.Name == 'Desc' and d.Text ~= '' then
                    local text = d.Text
                    if text:find('Come back in') then
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
    until os.clock() >= deadline
    return -1
end

local function readDailyText()
    local deadline = os.clock() + 8
    repeat
        pcall(function() GuiService:DisplayFrame('DailyRewards') end)
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
            if claimed and nextReward ~= '' then
                local timeStr = nextReward:gsub('Next reward in ', '')
                result = 'Next in ' .. timeStr
                dailySeconds = parseTimeFromText(timeStr)
            elseif category ~= '' and progress ~= '' then
                result = category .. ' [' .. progress .. ']'
                dailySeconds = -1
            elseif category ~= '' then
                result = category
                dailySeconds = -1
            end
            pcall(function() GuiService:DisplayFrame('') end)
            return result
        end
    until os.clock() >= deadline
    pcall(function() GuiService:DisplayFrame('') end)
    return '...'
end

local function readSpinSeconds()
    local GetHalfDay = function() return math.floor(os.time() / 43200) end
    local secondsLeft = (GetHalfDay() + 1) * 43200 - os.time()
    local spinToWin = ScreenGui:FindFirstChild('SpinToWinSpooky')
    if spinToWin then
        local timeRemaining = spinToWin:FindFirstChild('TimeRemaining', true)
        if timeRemaining and timeRemaining:IsA('TextLabel') then
            if not timeRemaining.Visible then return 0 end
        end
    end
    return math.max(0, secondsLeft)
end

local function readAlienSpinSeconds()
    local deadline = os.clock() + 8
    local result = -1
    repeat
        pcall(function()
            if GuiService.UpdateAlienSpinToWin then
                GuiService:UpdateAlienSpinToWin()
            end
            GuiService:DisplayFrame('AlienSpinToWin')
        end)
        wait(0.4)
        local alienSpin = ScreenGui:FindFirstChild('AlienSpinToWin')
        if alienSpin then
            local timeRemaining = alienSpin:FindFirstChild('TimeRemaining', true)
            if timeRemaining and timeRemaining:IsA('TextLabel') then
                if not timeRemaining.Visible then
                    result = 0
                else
                    local seconds = parseTimeFromText(timeRemaining.Text)
                    if seconds >= 0 then
                        result = seconds
                    end
                end
            end
        end
        if result >= 0 then break end
    until os.clock() >= deadline
    pcall(function() GuiService:DisplayFrame('') end)
    return result
end

local function canClaimDaily()
    if not dailyText or dailyText == '...' or dailyText == 'Off' then return false end
    if dailyText:find('Next in') then return false end
    local progress = dailyText:match('%[(.-)%]')
    if not progress then return false end
    local currentStr = progress:match('([%d,]+)')
    local targetStr = progress:match('/(%s*[%d,]+)')
    if not currentStr or not targetStr then return false end
    local current = tonumber(string.gsub(currentStr, ',', ''), 10)
    local target = tonumber(string.gsub(targetStr, ',', ''), 10)
    if not current or not target then return false end
    return current >= target
end
local function collectGroupReward()
    pcall(function() Event:FireServer('CollectGroupReward') end)
    wait(0.5)
    groupSeconds = readGroupSeconds()
    lastGroupRefresh = os.clock()
end
local function spinToWin() pcall(function() Event:FireServer('SpinToWin') end) end
local function alienSpinToWin()
    pcall(function() Event:FireServer('AlienSpinToWin') end)
    wait(0.5)
    alienSpinSeconds = readAlienSpinSeconds()
    lastAlienSpinRefresh = os.clock()
end
local function claimDaily()
    pcall(function() Event:FireServer('ClaimDailyReward') end)
    wait(0.5)
    dailyText = readDailyText()
    lastDailyRefresh = os.clock()
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

local petImageUrls = {
    ["Alien Ghost"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/6/68/Alien_Ghost.png/revision/latest?cb=20260810210117",
    ["Mythic Alien Ghost"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/a/a9/Mythic_Alien_Ghost.webp/revision/latest?cb=20260814222905",
    ["Shiny Alien Ghost"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/6/68/Alien_Ghost.png/revision/latest?cb=20260810210117",
    ["Shiny Mythic Alien Ghost"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/a/a9/Mythic_Alien_Ghost.webp/revision/latest?cb=20260814222905",
    ["Alien Omen"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/9/9e/Alien_Omen.png/revision/latest?cb=20260814224125",
    ["Mythic Alien Omen"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/7/79/Mythic_Alien_Omen.webp/revision/latest?cb=20260814222911",
    ["Shiny Alien Omen"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/9/9e/Alien_Omen.png/revision/latest?cb=20260814224125",
    ["Shiny Mythic Alien Omen"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/7/79/Mythic_Alien_Omen.webp/revision/latest?cb=20260814222911",
    ["Alien Overlord"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/1/19/Alien_Overlord.png/revision/latest?cb=20260814224130",
    ["Mythic Alien Overlord"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/f/f4/Mythic_Alien_Overlord.webp/revision/latest?cb=20260814222916",
    ["Shiny Alien Overlord"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/1/19/Alien_Overlord.png/revision/latest?cb=20260814224130",
    ["Shiny Mythic Alien Overlord"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/f/f4/Mythic_Alien_Overlord.webp/revision/latest?cb=20260814222916",
    ["UFO"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/7/77/UFO.png/revision/latest?cb=20260814223242",
    ["Mythic UFO"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/7/7a/Mythic_UFO.webp/revision/latest?cb=20260814222928",
    ["Shiny UFO"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/7/77/UFO.png/revision/latest?cb=20260814223242",
    ["Shiny Mythic UFO"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/7/7a/Mythic_UFO.webp/revision/latest?cb=20260814222928",
    ["Alien Kraken"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/f/f5/Alien_Kraken.png/revision/latest?cb=20260814223208",
    ["Mythic Alien Kraken"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/2/2b/Mythic_Alien_Kraken.webp/revision/latest?cb=20260814222923",
    ["Shiny Alien Kraken"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/f/f5/Alien_Kraken.png/revision/latest?cb=20260814223208",
    ["Shiny Mythic Alien Kraken"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/2/2b/Mythic_Alien_Kraken.webp/revision/latest?cb=20260814222923",
    ["Galactic Dementor"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/5/5b/Galactic_Dementor.png/revision/latest?cb=20260814223227",
    ["Mythic Galactic Dementor"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/4/40/Mythic_Galactic_Dementor.webp/revision/latest?cb=20260814222933",
    ["Shiny Galactic Dementor"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/5/5b/Galactic_Dementor.png/revision/latest?cb=20260814223227",
    ["Shiny Mythic Galactic Dementor"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/4/40/Mythic_Galactic_Dementor.webp/revision/latest?cb=20260814222933",
    ["Hacker Phoenix"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/6/69/Hacker_Phoenix.png/revision/latest?cb=20260829182629",
    ["Hacker Gem"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/9/91/Hacker_Gem.png/revision/latest?cb=20260829172252",
    ["D0GGY1337"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/d/d4/D0GGY1337.png/revision/latest?cb=20260829185938",
    ["Hackarium"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/d/d6/Hackarium.png/revision/latest?cb=20260829172458",
    ["5H0CK"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/0/06/5H0CK.png/revision/latest?cb=20260829182537",
    ["Galactic Wolflord"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/0/0c/Galactic_Wolflord.png/revision/latest?cb=20260829172444",
    ["Mechanical Robot"] = "https://static.wikia.nocookie.net/bubble-gum-simulator/images/3/3b/Mechanical_Robot.png/revision/latest?cb=20260829172548"
}

local function parseChatColor(text)
    local color = tostring(text or ""):match("<font%s+[^>]*color%s*=%s*[\"']#([%x][%x][%x][%x][%x][%x])[\"'][^>]*>")
    if not color then
        local red, green, blue = tostring(text or ""):match("<font%s+[^>]*color%s*=%s*[\"']rgb%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)[\"'][^>]*>")
        if red and green and blue then
            return tonumber(red) * 65536 + tonumber(green) * 256 + tonumber(blue)
        end
    end
    if not color then return nil end
    return tonumber(color:sub(1, 2), 16) * 65536 + tonumber(color:sub(3, 4), 16) * 256 + tonumber(color:sub(5, 6), 16)
end

local function sendWebhookMessage(cleanMsg, petName, chance, chatColor)
    if not webhookEnabled or webhookURL == '' then return end
    local proxyUrl = webhookURL:gsub('https://discord%.com/api/webhooks/', 'https://webhook.lewisakura.moe/api/webhooks/')
    proxyUrl = proxyUrl:gsub('https://discordapp%.com/api/webhooks/', 'https://webhook.lewisakura.moe/api/webhooks/')
    local embed = {
        description = cleanMsg,
        color = chatColor or 65535
    }
    if petName and petName ~= '' then
        local img = petImageUrls[petName]
        if img then
            embed.author = { name = chance .. ' • ' .. petName, icon_url = img }
        end
    end
    local payload = HttpService:JSONEncode({ embeds = { embed } })
    pcall(function()
        if syn and syn.request then
            syn.request({ Url = proxyUrl, Method = 'POST', Headers = { ['Content-Type'] = 'application/json' }, Body = payload })
        elseif request then
            request({ Url = proxyUrl, Method = 'POST', Headers = { ['Content-Type'] = 'application/json' }, Body = payload })
        else
            HttpService:PostAsync(proxyUrl, payload)
        end
    end)
end

local function processSystemMessage(msgText)
    if not webhookEnabled or webhookURL == '' then return end
    if not msgText or msgText == '' then return end
    local playerName = LocalPlayer.Name
    local displayName = LocalPlayer.DisplayName
    local isLocalPlayer = false
    if msgText:find(playerName, 1, true) or msgText:find(displayName, 1, true) then
        isLocalPlayer = true
    end
    local isHatch = string.find(string.lower(msgText), 'hatched')
    if not (isLocalPlayer and isHatch) then return end
    local cleanMsg = msgText:gsub('<[^>]+>', '')
    local chatColor = parseChatColor(msgText)
    local petName = ''
    for name in pairs(petImageUrls) do
        if cleanMsg:find(name, 1, true) then
            petName = name
            break
        end
    end
    local chance = cleanMsg:match('%(([^%)]+)%)') or ''
    sendWebhookMessage(cleanMsg, petName, chance, chatColor)
end

pcall(function()
    local chatEvents = game.ReplicatedStorage:FindFirstChild('DefaultChatSystemChatEvents')
    if chatEvents then
        local onMessage = chatEvents:FindFirstChild('OnMessageDoneFiltering')
        if onMessage and onMessage:IsA('RemoteEvent') then
            onMessage.OnClientEvent:Connect(function(messageData)
                if messageData and type(messageData) == 'table' and messageData.Message then
                    processSystemMessage(tostring(messageData.Message))
                end
            end)
        end
    end
end)

pcall(function()
    if TextChatService then
        TextChatService.MessageReceived:Connect(function(textChatMessage)
            if textChatMessage and textChatMessage.Text then
                processSystemMessage(tostring(textChatMessage.Text))
            end
        end)
    end
end)

local function discoverIslands()
    task.spawn(function()
        local char = getCharacter()
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hrp then return end
        local originalCFrame = hrp.CFrame
        local checkpoints = Workspace:FindFirstChild('Checkpoints')
        local floatingIslands = Workspace:FindFirstChild('FloatingIslands')
        if not checkpoints or not floatingIslands then return end
        local redDoors = {}
        for _, island in ipairs(checkpoints:GetChildren()) do
            local door = island:FindFirstChild('Door')
            if door and door:IsA('BasePart') then
                local c = door.Color
                if c.R > 0.9 and c.G < 0.1 and c.B < 0.1 then
                    table.insert(redDoors, island.Name)
                end
            end
        end
        for _, islandName in ipairs(redDoors) do
            local targetIsland = nil
            for _, world in ipairs(floatingIslands:GetChildren()) do
                local found = world:FindFirstChild(islandName)
                if found then
                    targetIsland = found
                    break
                end
            end
            if targetIsland then
                local targetPos = targetIsland:GetPivot().Position
                local targetCFrame = CFrame.new(targetPos)
                hrp.CFrame = targetCFrame
                wait(0.2)
                local downPos = targetPos - Vector3.new(0, 50, 0)
                local tween = TweenService:Create(hrp, TweenInfo.new(1, Enum.EasingStyle.Linear), {CFrame = CFrame.new(downPos)})
                tween:Play()
                tween.Completed:Wait()
                wait(0.2)
                hrp.CFrame = originalCFrame
                wait(0.2)
            end
        end
    end)
end

local function saveCurrent()
    saveConfig({selectedEgg=selectedEgg, autoHatchEnabled=autoHatchEnabled, tripleHatchEnabled=tripleHatchEnabled,
        teleportEnabled=teleportEnabled, teleportMode=teleportMode, teleportTimeout=teleportTimeout,
        webhookEnabled=webhookEnabled, webhookURL=webhookURL, eventsEnabled=eventsEnabled,
        autoGroupBenefits=autoGroupBenefits, autoSpinToWin=autoSpinToWin, autoDailyRewards=autoDailyRewards,
        autoAlienSpinToWin=autoAlienSpinToWin, autoBlowEnabled=autoBlowEnabled, moveSpeed=moveSpeed, jumpHeight=jumpHeight})
end

MainTab:CreateParagraph({Title='Egg Opener', Content='Auto hatch eggs'})
MainTab:CreateDropdown({Name='Select Egg', Options=eggList, CurrentOption={selectedEgg}, Callback=function(opt)
    selectedEgg = opt[1]
    if teleportEnabled then teleportToSelectedEgg() end
    saveCurrent()
end})
MainTab:CreateToggle({Name='Open Selected Egg', CurrentValue=autoHatchEnabled, Callback=function(v)
    autoHatchEnabled = v
    if v and teleportEnabled and teleportMode == 'On Hatching' then teleportToSelectedEgg() end
    saveCurrent()
end})
MainTab:CreateToggle({Name='Triple Hatch', CurrentValue=tripleHatchEnabled, Callback=function(v) tripleHatchEnabled = v saveCurrent() end})
MainTab:CreateDivider()
MainTab:CreateToggle({Name='Teleport To Egg', CurrentValue=teleportEnabled, Callback=function(v)
    teleportEnabled = v
    if v then teleportToSelectedEgg() end
    saveCurrent()
end})
MainTab:CreateDropdown({Name='When To Teleport', Options={'On Hatching', 'Hatching Stalled'}, CurrentOption={teleportMode}, Callback=function(opt)
    teleportMode = opt[1]
    saveCurrent()
end})
MainTab:CreateSlider({
    Name = 'Timeout (seconds)',
    Range = {1, 30},
    Increment = 1,
    CurrentValue = teleportTimeout,
    Callback = function(v)
        teleportTimeout = v
        saveCurrent()
    end
})
EventTab:CreateParagraph({Title='Events', Content='Activate 2x events'})
EventTab:CreateToggle({Name='Enable Weekend Event', CurrentValue=eventsEnabled, Callback=function(v) eventsEnabled = v if v then enableEvents() else disableEvents() end saveCurrent() end})
WebhookTab:CreateParagraph({Title='Discord Webhook', Content='Send hatched pets to Discord'})
WebhookTab:CreateToggle({Name='Enable Webhook', CurrentValue=webhookEnabled, Callback=function(v) webhookEnabled = v saveCurrent() end})
WebhookTab:CreateInput({Name='Webhook URL', PlaceholderText='https://discord.com/api/webhooks/...', RemoveTextAfterFocusLost=false, Callback=function(text) webhookURL = text saveCurrent() end})
TasksTab:CreateParagraph({Title='Tasks', Content='Auto tasks'})

TasksTab:CreateToggle({Name='Auto Group Benefits', CurrentValue=autoGroupBenefits, Callback=function(v)
    autoGroupBenefits = v saveCurrent()
    if v then
        safeSet(GroupLabel, 'Loading...')
        task.spawn(function()
            groupSeconds = readGroupSeconds() lastGroupRefresh = os.clock()
            if groupSeconds > 0 then safeSet(GroupLabel, 'Next in ' .. formatTime(groupSeconds))
            elseif groupSeconds == 0 then safeSet(GroupLabel, 'Ready') else safeSet(GroupLabel, 'Loading...') end
        end)
    else safeSet(GroupLabel, 'Off') end
end})
local GroupLabel = TasksTab:CreateLabel('Off')

TasksTab:CreateToggle({Name='Auto Spin To Win', CurrentValue=autoSpinToWin, Callback=function(v)
    autoSpinToWin = v saveCurrent()
    if v then
        safeSet(SpinLabel, 'Loading...')
        task.spawn(function()
            spinSeconds = readSpinSeconds() lastSpinRefresh = os.clock()
            if spinSeconds > 0 then safeSet(SpinLabel, 'Next in ' .. formatTime(spinSeconds))
            elseif spinSeconds == 0 then safeSet(SpinLabel, 'Ready') else safeSet(SpinLabel, 'Loading...') end
        end)
    else safeSet(SpinLabel, 'Off') end
end})
local SpinLabel = TasksTab:CreateLabel('Off')

TasksTab:CreateToggle({Name='Auto Alien Spin To Win', CurrentValue=autoAlienSpinToWin, Callback=function(v)
    autoAlienSpinToWin = v saveCurrent()
    if v then
        safeSet(AlienSpinLabel, 'Loading...')
        task.spawn(function()
            alienSpinSeconds = readAlienSpinSeconds() lastAlienSpinRefresh = os.clock()
            if alienSpinSeconds > 0 then safeSet(AlienSpinLabel, 'Next in ' .. formatTime(alienSpinSeconds))
            elseif alienSpinSeconds == 0 then
                safeSet(AlienSpinLabel, 'Ready')
                alienSpinToWin()
            else safeSet(AlienSpinLabel, 'Loading...') end
        end)
    else safeSet(AlienSpinLabel, 'Off') end
end})
local AlienSpinLabel = TasksTab:CreateLabel('Off')

TasksTab:CreateToggle({Name='Auto Daily Rewards', CurrentValue=autoDailyRewards, Callback=function(v)
    autoDailyRewards = v saveCurrent()
    if v then
        safeSet(DailyLabel, 'Loading...')
        task.spawn(function()
            dailyText = readDailyText() lastDailyRefresh = os.clock() safeSet(DailyLabel, dailyText)
        end)
    else safeSet(DailyLabel, 'Off') end
end})
local DailyLabel = TasksTab:CreateLabel('Off')

MiscTab:CreateToggle({Name='Auto Blow', CurrentValue=autoBlowEnabled, Callback=function(v) autoBlowEnabled = v saveCurrent() end})

MiscTab:CreateParagraph({Title='Discovery', Content='Teleport to all undiscovered floating islands'})
MiscTab:CreateButton({Name='Discover Islands', Callback=function() discoverIslands() end})

MiscTab:CreateParagraph({Title='Character', Content=''})
MiscTab:CreateInput({Name='WalkSpeed', PlaceholderText='24', RemoveTextAfterFocusLost=false, Callback=function(text)
    local num = tonumber(text)
    if num then
        moveSpeed = num
        pcall(function()
            local char = getCharacter()
            local humanoid = char:FindFirstChildOfClass('Humanoid')
            if humanoid then humanoid.WalkSpeed = moveSpeed end
        end)
        saveCurrent()
    end
end})
MiscTab:CreateInput({Name='JumpPower', PlaceholderText='70', RemoveTextAfterFocusLost=false, Callback=function(text)
    local num = tonumber(text)
    if num then
        jumpHeight = num
        pcall(function()
            local char = getCharacter()
            local humanoid = char:FindFirstChildOfClass('Humanoid')
            if humanoid then humanoid.JumpPower = jumpHeight end
        end)
        saveCurrent()
    end
end})

if teleportEnabled and autoHatchEnabled then teleportToSelectedEgg() end
if eventsEnabled then enableEvents() end

if autoGroupBenefits then
    safeSet(GroupLabel, 'Loading...')
    task.spawn(function() groupSeconds = readGroupSeconds() lastGroupRefresh = os.clock()
        if groupSeconds > 0 then safeSet(GroupLabel, 'Next in ' .. formatTime(groupSeconds))
        elseif groupSeconds == 0 then safeSet(GroupLabel, 'Ready') else safeSet(GroupLabel, 'Loading...') end
    end)
end
if autoSpinToWin then
    safeSet(SpinLabel, 'Loading...')
    task.spawn(function() spinSeconds = readSpinSeconds() lastSpinRefresh = os.clock()
        if spinSeconds > 0 then safeSet(SpinLabel, 'Next in ' .. formatTime(spinSeconds))
        elseif spinSeconds == 0 then safeSet(SpinLabel, 'Ready') else safeSet(SpinLabel, 'Loading...') end
    end)
end
if autoAlienSpinToWin then
    safeSet(AlienSpinLabel, 'Loading...')
    task.spawn(function() alienSpinSeconds = readAlienSpinSeconds() lastAlienSpinRefresh = os.clock()
        if alienSpinSeconds > 0 then safeSet(AlienSpinLabel, 'Next in ' .. formatTime(alienSpinSeconds))
        elseif alienSpinSeconds == 0 then
            safeSet(AlienSpinLabel, 'Ready')
            alienSpinToWin()
        else safeSet(AlienSpinLabel, 'Loading...') end
    end)
end
if autoDailyRewards then
    safeSet(DailyLabel, 'Loading...')
    task.spawn(function() dailyText = readDailyText() lastDailyRefresh = os.clock() safeSet(DailyLabel, dailyText) end)
end

local lastEggsOpened = -1
local stalledTime = 0
local lastBlowAt = 0

local lastTick = os.clock()
while true do
    autoDestroyRobloxPrompts()
    local now = os.clock()
    local delta = now - lastTick
    lastTick = now

    if autoBlowEnabled then
        if now - lastBlowAt >= 0.5 then
            lastBlowAt = now
            pcall(function() Event:FireServer('BlowBubble') end)
        end
    end

    if autoHatchEnabled and teleportEnabled and teleportMode == 'Hatching Stalled' then
        local currentEggsOpened = getEggsOpened()
        if lastEggsOpened == -1 then
            lastEggsOpened = currentEggsOpened
            stalledTime = now
        elseif currentEggsOpened ~= lastEggsOpened then
            lastEggsOpened = currentEggsOpened
            stalledTime = now
        elseif now - stalledTime >= teleportTimeout then
            teleportToSelectedEgg()
            stalledTime = now
        end
    elseif not autoHatchEnabled or not teleportEnabled or teleportMode ~= 'Hatching Stalled' then
        lastEggsOpened = -1
    end

    if autoGroupBenefits then
        if groupSeconds > 0 then
            groupSeconds = math.max(0, groupSeconds - delta)
            if groupSeconds <= 0 then safeSet(GroupLabel, 'Ready') collectGroupReward()
            else safeSet(GroupLabel, 'Next in ' .. formatTime(groupSeconds)) end
        elseif groupSeconds == 0 then safeSet(GroupLabel, 'Ready') end
    end

    if autoSpinToWin then
        if spinSeconds > 0 then
            spinSeconds = math.max(0, spinSeconds - delta)
            if spinSeconds <= 0 then safeSet(SpinLabel, 'Ready') spinToWin()
            else safeSet(SpinLabel, 'Next in ' .. formatTime(spinSeconds)) end
        elseif spinSeconds == 0 then safeSet(SpinLabel, 'Ready') end
    end

    if autoAlienSpinToWin then
        if alienSpinSeconds > 0 then
            alienSpinSeconds = math.max(0, alienSpinSeconds - delta)
            if alienSpinSeconds <= 0 then
                safeSet(AlienSpinLabel, 'Ready')
                alienSpinToWin()
            else safeSet(AlienSpinLabel, 'Next in ' .. formatTime(alienSpinSeconds)) end
        elseif alienSpinSeconds == 0 then
            safeSet(AlienSpinLabel, 'Ready')
            alienSpinToWin()
        end
    end

    if autoDailyRewards then
        if dailySeconds > 0 then
            dailySeconds = math.max(0, dailySeconds - delta)
            if dailySeconds <= 0 then dailyText = 'Ready' safeSet(DailyLabel, dailyText)
            else dailyText = 'Next in ' .. formatTime(dailySeconds) safeSet(DailyLabel, dailyText) end
        end
    end

    if now - lastGroupRefresh >= SYNC_INTERVAL then
        if autoGroupBenefits then
            task.spawn(function() groupSeconds = readGroupSeconds() lastGroupRefresh = os.clock()
                if groupSeconds > 0 then safeSet(GroupLabel, 'Next in ' .. formatTime(groupSeconds)) end
            end)
        end
    end
    if now - lastSpinRefresh >= SYNC_INTERVAL then
        if autoSpinToWin then
            task.spawn(function() spinSeconds = readSpinSeconds() lastSpinRefresh = os.clock()
                if spinSeconds > 0 then safeSet(SpinLabel, 'Next in ' .. formatTime(spinSeconds)) end
            end)
        end
    end
    if now - lastAlienSpinRefresh >= SYNC_INTERVAL then
        if autoAlienSpinToWin then
            task.spawn(function() alienSpinSeconds = readAlienSpinSeconds() lastAlienSpinRefresh = os.clock()
                if alienSpinSeconds > 0 then safeSet(AlienSpinLabel, 'Next in ' .. formatTime(alienSpinSeconds))
                elseif alienSpinSeconds == 0 then
                    safeSet(AlienSpinLabel, 'Ready')
                    alienSpinToWin()
                end
            end)
        end
    end
    if now - lastDailyRefresh >= SYNC_INTERVAL then
        if autoDailyRewards then
            task.spawn(function() dailyText = readDailyText() lastDailyRefresh = os.clock() safeSet(DailyLabel, dailyText) end)
        end
    end

    if autoDailyRewards and canClaimDaily() then claimDaily() end
    if autoHatchEnabled then hatchEgg() end

    wait(0.2)
end
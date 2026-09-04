local pickupPathThread = nil
local function stopPickupLoop()
    pickupLoopEnabled = false
    if pickupPathThread then
        task.cancel(pickupPathThread)
        pickupPathThread = nil
    end
end

local function getPickupPathParts()
    local pickupsFolder = Workspace:FindFirstChild('Pickups')
    if not pickupsFolder then return {} end
    local char = getCharacter()
    local hrp = char:FindFirstChild('HumanoidRootPart')
    local playerPos = hrp and hrp.Position or Vector3.zero
    local entries = {}
    for _, part in ipairs(pickupsFolder:GetDescendants()) do
        if part:IsA('BasePart') and part.Name == 'Part' then
            local distance = (part.Position - playerPos).Magnitude
            if distance <= pickupRadius and part:IsDescendantOf(Workspace) then
                local priority = 0
                if #part:GetChildren() == 0 then priority = 1 end
                table.insert(entries, { part = part, distance = distance, priority = priority })
            end
        end
    end
    table.sort(entries, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.distance < b.distance
    end)
    local path = {}
    for _, entry in ipairs(entries) do table.insert(path, entry.part) end
    return path
end

local function startPickupLoop()
    if pickupPathThread then return end
    pickupLoopEnabled = true
    pickupPathThread = task.spawn(function()
        local char = getCharacter()
        local hrp = char:WaitForChild('HumanoidRootPart', 5)
        local humanoid = char:FindFirstChildOfClass('Humanoid')
        local pickupLastScan = 0
        if hrp then hrp.CanCollide = false end
        if humanoid then humanoid.AutoRotate = false end
        while pickupLoopEnabled do
            local now = os.clock()
            if now - pickupLastScan >= pickupScanInterval then
                pickupLastScan = now
                local path = getPickupPathParts()
                if #path == 0 then
                    task.wait(0.05)
                else
                    char = getCharacter()
                    hrp = char:WaitForChild('HumanoidRootPart', 5)
                    humanoid = char:FindFirstChildOfClass('Humanoid')
                    if hrp then hrp.CanCollide = false end
                    if humanoid then humanoid.AutoRotate = false end
                    if hrp and humanoid then
                        for _, part in ipairs(path) do
                            if not pickupLoopEnabled then break end
                            if not part:IsDescendantOf(Workspace) then continue end
                            local targetPos = part.Position + Vector3.new(0, 0.5, 0)
                            local distance = (hrp.Position - targetPos).Magnitude
                            local direction = targetPos - hrp.Position
                            local yaw = 0
                            if direction.Magnitude > 0 then yaw = math.atan2(direction.X, direction.Z) end
                            if distance <= 1.5 then
                                local finalCFrame = CFrame.new(targetPos + Vector3.new(0, pickupBelowOffset, 0)) * CFrame.Angles(0, yaw, 0)
                                hrp.CFrame = finalCFrame
                                hrp.AssemblyLinearVelocity = Vector3.zero
                                hrp.AssemblyAngularVelocity = Vector3.zero
                            else
                                local moveTime = math.max(0.05, distance / math.max(1, pickupTweenSpeed))
                                local tween = TweenService:Create(hrp, TweenInfo.new(moveTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
                                    CFrame = CFrame.new(targetPos) * CFrame.Angles(0, yaw, 0)
                                })
                                tween:Play()
                                tween.Completed:Wait()
                            end
                            task.wait(0.05)
                        end
                    end
                end
            end
            task.wait(0.05)
        end
        if hrp then hrp.CanCollide = true end
        if humanoid then humanoid.AutoRotate = true end
        pickupPathThread = nil
    end)
end

local function antiAfkLoop()
    task.spawn(function()
        while true do
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                wait(0.1)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
            wait(60)
        end
    end)
end

antiAfkLoop()

local function saveCurrent()
    saveConfig({selectedEgg=selectedEgg, autoHatchEnabled=autoHatchEnabled, tripleHatchEnabled=tripleHatchEnabled,
        teleportEnabled=teleportEnabled, teleportMode=teleportMode, teleportTimeout=teleportTimeout,
        webhookEnabled=webhookEnabled, webhookURL=webhookURL, eventsEnabled=eventsEnabled,
        autoGroupBenefits=autoGroupBenefits, autoSpinToWin=autoSpinToWin, autoDailyRewards=autoDailyRewards,
        autoAlienSpinToWin=autoAlienSpinToWin, autoBlowEnabled=autoBlowEnabled, pickupLoopEnabled=pickupLoopEnabled,
        pickupRadius=pickupRadius, pickupTweenSpeed=pickupTweenSpeed, pickupBelowOffset=pickupBelowOffset,
        pickupScanInterval=pickupScanInterval, moveSpeed=moveSpeed, jumpHeight=jumpHeight})
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
TrackersTab:CreateParagraph({Title='Selected Egg Info', Content='Balance, opens, and time'})
local selectedEggCostLabel = TrackersTab:CreateLabel('Cost: N/A')
local balanceAfterPurchaseLabel = TrackersTab:CreateLabel('Balance After Purchase: N/A')
local canOpenLabel = TrackersTab:CreateLabel('Can Open: N/A')
local timeToOpenLabel = TrackersTab:CreateLabel('Time to Open All: N/A')
TrackersTab:CreateParagraph({Title='All Eggs', Content='Egg costs'})
for name, data in pairs(eggCostData) do
    TrackersTab:CreateLabel(name .. ': ' .. data.costAmount .. ' ' .. data.costType)
end
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

PickupsTab:CreateParagraph({Title='Farm Pickups', Content='Auto collect nearby pickups'})
PickupsTab:CreateToggle({Name='Pickup Path', CurrentValue=pickupLoopEnabled, Callback=function(v)
    pickupLoopEnabled = v
    if v then startPickupLoop() else stopPickupLoop() end
    saveCurrent()
end})
PickupsTab:CreateSlider({
    Name = 'Pickup Radius',
    Range = {50, 500},
    Increment = 1,
    CurrentValue = pickupRadius,
    Callback = function(v) pickupRadius = v saveCurrent() end
})
PickupsTab:CreateSlider({
    Name = 'Tween Speed',
    Range = {50, 2000},
    Increment = 10,
    CurrentValue = pickupTweenSpeed,
    Callback = function(v) pickupTweenSpeed = v saveCurrent() end
})
PickupsTab:CreateSlider({
    Name = 'Below Offset',
    Range = {-5, 5},
    Increment = 0.1,
    CurrentValue = pickupBelowOffset,
    Callback = function(v) pickupBelowOffset = v saveCurrent() end
})
PickupsTab:CreateSlider({
    Name = 'Scan Delay',
    Range = {0.1, 1},
    Increment = 0.01,
    CurrentValue = pickupScanInterval,
    Callback = function(v) pickupScanInterval = v saveCurrent() end
})

MiscTab:CreateParagraph({Title='Game', Content='Auto blow bubbles'})
MiscTab:CreateToggle({Name='Auto Blow', CurrentValue=autoBlowEnabled, Callback=function(v) autoBlowEnabled = v saveCurrent() end})
MiscTab:CreateParagraph({Title='Discovery', Content='Teleport to all undiscovered floating islands'})
MiscTab:CreateButton({Name='Discover Islands', Callback=function() discoverIslands() end})
MiscTab:CreateParagraph({Title='Character', Content='Movement'})
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
if pickupLoopEnabled then startPickupLoop() end

local lastEggsOpened = -1
local stalledTime = 0
local lastBlowAt = 0
local lastTrackerRefresh = 0

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

    if now - lastTrackerRefresh >= 1 then
        lastTrackerRefresh = now
        local eggInfo = eggCostData[selectedEgg]
        if eggInfo then
            selectedEggCostLabel:Set('Cost: ' .. eggInfo.costAmount .. ' ' .. eggInfo.costType)
            local balance = 0
            local playerGui = LocalPlayer:FindFirstChild('PlayerGui')
            local screenGui = playerGui and playerGui:FindFirstChild('ScreenGui')
            local statsFrame = screenGui and screenGui:FindFirstChild('StatsFrame')
            if statsFrame then
                local currencyMap = {
                    ['Coins'] = 'Coins',
                    ['Gems'] = 'Gems',
                    ['AlienCoins'] = 'AlienCoins',
                    ['Shells'] = 'Shells',
                    ['Pearls'] = 'Pearls',
                    ['Blocks'] = 'Blocks',
                    ['Candy'] = 'Candy',
                    ['Crystals'] = 'Crystals',
                    ['Magma'] = 'Magma',
                    ['Stars'] = 'Stars',
                    ['Flowers'] = 'Flowers',
                    ['Bells'] = 'Bells',
                    ['Snowflakes'] = 'Snowflakes',
                    ['CandyCanes'] = 'CandyCanes',
                    ['CandyCorn'] = 'CandyCorn',
                    ['Treats'] = 'Treats',
                    ['Tickets'] = 'Tickets',
                    ['Tokens'] = 'Tokens',
                    ['Presents'] = 'Presents',
                    ['Rainbows'] = 'Rainbows',
                    ['Lollipops'] = 'Lollipops',
                    ['Halos'] = 'Halos',
                    ['Silver'] = 'Silver'
                }
                local currencyName = currencyMap[eggInfo.costType] or eggInfo.costType
                local currencyObj = statsFrame:FindFirstChild(currencyName)
                if currencyObj then
                    local amountNode = currencyObj:FindFirstChild('Amount')
                    if amountNode then
                        balance = tonumber((amountNode.Text or ''):gsub(',', '')) or 0
                    end
                end
            end
            local balanceAfterPurchase = math.max(0, balance - eggInfo.costAmount)
            balanceAfterPurchaseLabel:Set('Balance After Purchase: ' .. balanceAfterPurchase .. ' ' .. eggInfo.costType)
            local canOpen = math.floor(balance / eggInfo.costAmount)
            canOpenLabel:Set('Can Open: ' .. canOpen)
            local timePerEgg = 2.5
            local totalSeconds = canOpen * timePerEgg
            local hours = math.floor(totalSeconds / 3600)
            local mins = math.floor((totalSeconds % 3600) / 60)
            local secs = math.floor(totalSeconds % 60)
            timeToOpenLabel:Set(string.format('Time to Open All: %02d:%02d:%02d', hours, mins, secs))
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
ESX = exports["es_extended"]:getSharedObject()
local robberyCodes, activeRobbery, storeActive, storeRobbed, storeSafesLooted, passwordAttempts, storeOwnership = {}, {},
    {}, {}, {}, {}, {}
local passwordAttemptTimers = {} -- Track cooldown on failed attempts

-- Validate config on resource start
CreateThread(function()
    if not Config or not Config.Stores then
        print("^1[sm_storerobbery] ERROR: Config not loaded properly!^0")
        return
    end
    local storeCount = 0
    for _ in pairs(Config.Stores) do
        storeCount = storeCount + 1
    end
    print("^2[sm_storerobbery]^0 Loaded " .. storeCount .. " stores successfully")
end)

-- Clean up player data on disconnect
AddEventHandler('playerDropped', function()
    local src = source
    if activeRobbery[src] then
        local robberyData = activeRobbery[src]
        local storeId = type(robberyData) == "table" and robberyData.storeId or robberyData
        if storeId then
            storeActive[storeId] = nil
            TriggerClientEvent('sm_storerobbery:updateStoreState', -1, storeId, false)
        end
        activeRobbery[src] = nil
    end
    -- Clean up password attempts for disconnected player
    for storeId, attempts in pairs(passwordAttempts) do
        if attempts[src] then
            attempts[src] = nil
        end
    end

    -- Clean up password attempt timers
    for key, _ in pairs(passwordAttemptTimers) do
        if key:find('^' .. src .. ':') or key:find(':' .. src .. '$') then
            passwordAttemptTimers[key] = nil
        end
    end
end)

local function resetStore(storeId)
    storeActive[storeId] = nil
    storeRobbed[storeId] = nil
    storeSafesLooted[storeId] = nil
    robberyCodes[storeId] = nil
    passwordAttempts[storeId] = nil
    storeOwnership[storeId] = nil
    TriggerClientEvent('sm_storerobbery:updateStoreState', -1, storeId, false)
end

local function checkPoliceRequirement(src, storeId)
    if not storeId or not src then return false end

    local policeCount = 0
    local players = GetPlayers()
    if players then
        for _, playerId in ipairs(players) do
            local xPlayer = ESX.GetPlayerFromId(tonumber(playerId))
            if xPlayer and xPlayer.job.name == "police" then
                policeCount = policeCount + 1
            end
        end
    end

    if policeCount >= (Config.PoliceRequired or 1) or Config.PoliceRequired == 0 then
        return true
    else
        storeActive[storeId] = nil
        activeRobbery[src] = nil
        TriggerClientEvent('sm_storerobbery:updateStoreState', -1, storeId, false)
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Not enough police on duty. Need ' .. (Config.PoliceRequired or 1) .. ', found ' .. policeCount
        })
        return false
    end
end

local function checkItemRequirement(src, storeId)
    if not storeId or not src then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Store ID not set'
        })
        return
    end

    local items = {}
    local success = pcall(function()
        items = exports.ox_inventory:Search(src, 'count', { 'lockpick', 'advanced_lockpick', 'advancedlockpick' }) or {}
    end)

    if not success or not items then
        items = {}
    end

    local advancedItemName = nil
    if (items.advanced_lockpick or 0) > 0 then
        advancedItemName = 'advanced_lockpick'
    elseif (items.advancedlockpick or 0) > 0 then
        advancedItemName = 'advancedlockpick'
    end

    local hasAdvanced = advancedItemName ~= nil
    local hasBasic = (items.lockpick or 0) > 0

    if hasAdvanced then
        TriggerClientEvent('sm_storerobbery:startLockpick', src, storeId, 'advanced')
        activeRobbery[src] = { storeId = storeId, lockpickType = 'advanced', advancedItem = advancedItemName }
    elseif hasBasic then
        TriggerClientEvent('sm_storerobbery:startLockpick', src, storeId, 'basic')
        activeRobbery[src] = { storeId = storeId, lockpickType = 'basic' }
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'You need a lockpick to rob this store.'
        })
        storeActive[storeId] = nil
        activeRobbery[src] = nil
        TriggerClientEvent('sm_storerobbery:updateStoreState', -1, storeId, false)
    end
end

RegisterServerEvent('sm_storerobbery:startRobbery', function(storeId)
    local src = source
    TriggerClientEvent('sm_storerobbery:setCurrentStore', src, storeId)

    if not storeId or not Config.Stores[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Invalid store location'
        })
        return
    end

    if storeRobbed[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'This store has recently been robbed'
        })
        return
    end

    if storeActive[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Someone is already robbing this till.'
        })
        return
    end

    storeActive[storeId] = true
    TriggerClientEvent('sm_storerobbery:updateStoreState', -1, storeId, true)
    robberyCodes[storeId] = tostring(math.random(1000, 9999))
    activeRobbery[src] = storeId

    -- Check police and items requirement
    if checkPoliceRequirement(src, storeId) then
        checkItemRequirement(src, storeId)
    end
end)

RegisterServerEvent('sm_storerobbery:lockpickFailed', function(storeId)
    local src = source
    
    -- If storeId is nil, try to get it from activeRobbery
    if not storeId and activeRobbery[src] then
        storeId = type(activeRobbery[src]) == "table" and activeRobbery[src].storeId or activeRobbery[src]
    end
    
    if not storeId then
        -- Still no storeId, just clear player's active robbery
        activeRobbery[src] = nil
        return
    end

    if not Config.Stores[storeId] then
        activeRobbery[src] = nil
        return
    end

    -- Clear all store state to allow retry
    storeActive[storeId] = nil
    activeRobbery[src] = nil
    robberyCodes[storeId] = nil
    
    -- Broadcast state reset to all clients
    TriggerClientEvent('sm_storerobbery:updateStoreState', -1, storeId, false)
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'error',
        description = 'Robbery cancelled. State reset.'
    })
end)

RegisterServerEvent('sm_storerobbery:tillReward', function(storeId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then
        activeRobbery[src] = nil
        return
    end

    if not storeId then
        storeId = activeRobbery[src] and activeRobbery[src].storeId
    end

    if not storeId or not Config.Stores[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Store not found'
        })
        return
    end

    -- Verify robbery state is still active
    if not storeRobbed[storeId] and not storeActive[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Robbery state invalid'
        })
        activeRobbery[src] = nil
        return
    end

    local rewardAmount = math.random(Config.TillRewardMin or 1000, Config.TillRewardMax or 2500)
    local pcallSuccess, addSuccess = pcall(function()
        return exports.ox_inventory:AddItem(src, 'black_money', rewardAmount)
    end)

    if not pcallSuccess or not addSuccess then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Inventory is full!'
        })
        storeRobbed[storeId] = false
        storeActive[storeId] = false
        activeRobbery[src] = nil
        return
    end

    -- Remove the correct lockpick type that was used
    local lockpickType = activeRobbery[src] and activeRobbery[src].lockpickType or 'basic'
    if not lockpickType then lockpickType = 'basic' end

    pcall(function()
        if lockpickType == 'advanced' then
            local advancedItem = activeRobbery[src] and activeRobbery[src].advancedItem or 'advanced_lockpick'
            exports.ox_inventory:RemoveItem(src, advancedItem, 1)
        else
            exports.ox_inventory:RemoveItem(src, 'lockpick', 1)
        end
    end)

    -- Chance to get safe password
    if math.random(1, 100) <= (Config.Chance or 100) then
        local code = robberyCodes[storeId] or "UNKNOWN"
        local passwordItem = Config.SafePasswordItem or 'safe_password'
        local noteAdded = false

        local success, addResult = pcall(function()
            return exports.ox_inventory:AddItem(src, passwordItem, 1, {
                description = "Safe Code: " .. code
            })
        end)

        if success and addResult then
            noteAdded = true
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'success',
                description = 'Found Safe Password'
            })
        end

        -- Fallback: always provide the code if the item is missing or cannot be added.
        if not noteAdded then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'warning',
                description = 'Safe code item could not be added. Code: ' .. code
            })
        end
    end

    storeRobbed[storeId] = true
    storeActive[storeId] = nil
    activeRobbery[src] = nil
    storeOwnership[storeId] = src

    SetTimeout(Config.StoreCooldown * 1000, function()
        resetStore(storeId)
    end)
end)

RegisterServerEvent('sm_storerobbery:checkPassword', function(storeId, password)
    local src = source
    if not storeId or not password then return end

    password = tostring(password)

    if not Config.Stores[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Store not found'
        })
        return
    end

    if not storeRobbed[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'This safe cannot be opened.'
        })
        return
    end

    -- Validate player robbed the till
    local enforceSafeOwnership = Config.EnforceSafeOwnership ~= false
    if enforceSafeOwnership and storeOwnership[storeId] and storeOwnership[storeId] ~= src then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'You did not rob this store.'
        })
        return
    end

    if storeSafesLooted[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Safe already looted.'
        })
        return
    end

    -- Initialize attempts tracker
    if not passwordAttempts[storeId] then
        passwordAttempts[storeId] = {}
    end
    if not passwordAttempts[storeId][src] then
        passwordAttempts[storeId][src] = 0
    end

    -- Check failed attempts
    if passwordAttempts[storeId][src] >= (Config.MaxPasswordAttempts or 3) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Too many failed attempts. Safe locked.'
        })
        return
    end

    -- Check cooldown timer to prevent spam
    local attemptKey = storeId .. ':' .. src
    if passwordAttemptTimers[attemptKey] and GetGameTimer() < passwordAttemptTimers[attemptKey] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Please wait before trying again.'
        })
        return
    end

    -- Verify player has advanced lockpick
    local hasAdvancedLockpick = false
    pcall(function()
        local items = exports.ox_inventory:Search(src, 'count', { 'advanced_lockpick', 'advancedlockpick' }) or {}
        hasAdvancedLockpick = (items.advanced_lockpick or 0) > 0 or (items.advancedlockpick or 0) > 0
    end)

    if not hasAdvancedLockpick then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'You need an advanced lockpick to open this safe.'
        })
        return
    end

    local correctCode = robberyCodes[storeId]
    if not correctCode then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Safe code not found'
        })
        return
    end

    if password ~= correctCode then
        passwordAttempts[storeId][src] = passwordAttempts[storeId][src] + 1
        local attemptKey = storeId .. ':' .. src
        passwordAttemptTimers[attemptKey] = GetGameTimer() + 2000 -- 2 second cooldown
        local remaining = (Config.MaxPasswordAttempts or 3) - passwordAttempts[storeId][src]
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Incorrect Password (' .. remaining .. ' attempts remaining)'
        })
        return
    end

    -- Reset attempts on success
    passwordAttempts[storeId][src] = 0
    local attemptKey = storeId .. ':' .. src
    passwordAttemptTimers[attemptKey] = nil -- Clear cooldown on success
    TriggerClientEvent('sm_storerobbery:startUntangle', src, storeId)
end)

RegisterServerEvent('sm_storerobbery:safeLoot', function(storeId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer or not storeId or not Config.Stores[storeId] then
        return
    end

    -- Verify robbery state
    if not storeRobbed[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Till has not been robbed'
        })
        return
    end

    if storeSafesLooted[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Safe already looted'
        })
        return
    end

    storeSafesLooted[storeId] = true
    local rewardAmount = math.random(Config.SafeRewardMin or 3000, Config.SafeRewardMax or 6000)

    local pcallSuccess, addSuccess = pcall(function()
        return exports.ox_inventory:AddItem(src, 'black_money', rewardAmount)
    end)

    if pcallSuccess and addSuccess then
        pcall(function()
            local removed = exports.ox_inventory:RemoveItem(src, 'advanced_lockpick', 1)
            if not removed then
                exports.ox_inventory:RemoveItem(src, 'advancedlockpick', 1)
            end
        end)
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = 'You successfully looted the safe!'
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Inventory is full!'
        })
        storeSafesLooted[storeId] = nil
    end
end)

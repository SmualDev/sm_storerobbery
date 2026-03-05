ESX = exports["es_extended"]:getSharedObject()
local robberyCodes = {
}
local activeRobbery = {
}
local storeCooldowns = {
}
local storeActive = {
}
local storeRobbed = {
}
local storeSafesLooted = {
}
local function resetStore(storeId)
    storeActive[storeId] = nil
    storeRobbed[storeId] = nil
    storeSafesLooted[storeId] = nil
    robberyCodes[storeId] = nil

    TriggerClientEvent('sm_storerobbery:updateStoreState', -1, storeId, false)
end

RegisterServerEvent('sm_storerobbery:startRobbery', function(storeId)
    local src = source
    TriggerClientEvent('sm_storerobbery:setCurrentStore', src, storeId)
    if not Config.Stores[storeId] then
        print("Invalid storeId:", storeId)
        return
    end
    if storeRobbed[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'This store Has Recently Been Robbed'
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
    TriggerEvent('sm_storerobbery:checkPolice', src, storeId)
end)

RegisterServerEvent('sm_storerobbery:checkPolice', function(source, storeId)
    local src = source
    local policeCount = 0
    for _, playerId in pairs(GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer and xPlayer.job.name == "police" then
            policeCount = policeCount + 1
        end
    end
    if policeCount >= 1 then
        TriggerEvent('sm_storerobbery:checkItem', src, storeId)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Not enough police on duty.'
        })
    end
end)

RegisterServerEvent('sm_storerobbery:checkItem', function(source, storeId)
    local src = source
    local items = exports.ox_inventory:Search(src, 'count', Config.itemRequired)
    if items.lockpick > 0 and items.advanced_lockpick > 0 then
        TriggerClientEvent('sm_storerobbery:lockpickAdvanced', src)
    elseif items.lockpick > 0 then
        TriggerClientEvent('sm_storerobbery:lockpickNormal', src)
    elseif items.advanced_lockpick > 0 then
        TriggerClientEvent('sm_storerobbery:lockpickAdvanced', src)   
    end
end)

RegisterNetEvent('sm_storerobbery:lockpickFailed', function(storeId)
    storeActive[storeId] = nil
    activeRobbery[source] = nil
    TriggerClientEvent('sm_storerobbery:updateStoreState', -1, storeId, false)
end)

RegisterNetEvent('sm_storerobbery:tillReward', function(target)
  local src = target or source
  local success, response = exports.ox_inventory:AddItem(source, 'black_money', math.random(1000,2500))
  local chanceOfNote = (math.random(1, 100))
  local storeId = activeRobbery[src]
  local code = robberyCodes[storeId] or "UNKNOWN"
  local storeData = Config.Stores[storeId]
  if chanceOfNote <= Config.Chance then
    exports.ox_inventory:AddItem(src, 'safe_password', 1, {
        description = "Safe Code: " ..code
    })
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = 'Found Safe Password'
        })
  end
    storeRobbed[storeId] = true
    storeActive[storeId] = nil
    activeRobbery[src] = nil
    SetTimeout(Config.StoreCooldown * 1000, function()
        resetStore(storeId)
    end)
end)

RegisterServerEvent('sm_storerobbery:checkPassword', function(storeId, password)
    local src = source
    if not storeRobbed[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'This safe cannot be opened.'
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
    local correctCode = robberyCodes[storeId]
    if not correctCode then return end
    if password ~= correctCode then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Incorrect Password'
        })
        return
    end
    TriggerClientEvent('sm_storerobbery:startUntangle', src, storeId)
end)

RegisterServerEvent('sm_storerobbery:safeLoot', function(storeId)
    local src = source

    if not Config.Stores[storeId] then return end
    if not storeRobbed[storeId] then return end
        if storeSafesLooted[storeId] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Safe already looted'
        })
        return
    end
    storeSafesLooted[storeId] = true
    exports.ox_inventory:AddItem(src, 'black_money', math.random(3000, 6000))
        TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = 'You successfully looted the safe!'
    })
end)








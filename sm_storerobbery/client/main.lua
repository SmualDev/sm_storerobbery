ESX = exports["es_extended"]:getSharedObject()
local robbedStores = {}
local currentStoreId = nil
local isLockpicking = false
local animDicts = {} -- Cache loaded animation dicts
local animSets = {}  -- Cache loaded animation sets

RegisterNetEvent('sm_storerobbery:setCurrentStore', function(storeId)
    currentStoreId = storeId
end)

RegisterNetEvent('sm_storerobbery:updateStoreState', function(storeId, state)
    robbedStores[storeId] = state
end)

CreateThread(function()
    for storeId, store in pairs(Config.Stores) do
        if store.till and store.safe then
            exports.ox_target:addBoxZone({
                coords = store.till.coords,
                size = store.till.size,
                rotation = store.till.rotation,
                debug = false,
                options = {
                    {
                        name = "rob_till_" .. storeId,
                        icon = "fa-solid fa-mask",
                        label = "Rob Till",
                        canInteract = function()
                            return not robbedStores[storeId]
                        end,
                        onSelect = function()
                            TriggerServerEvent('sm_storerobbery:startRobbery', storeId)
                        end
                    }
                }
            })
            exports.ox_target:addBoxZone({
                coords = store.safe.coords,
                size = store.safe.size,
                rotation = store.safe.rotation,
                debug = false,
                options = {
                    {
                        name = "rob_safe_" .. storeId,
                        icon = "fa-solid fa-vault",
                        label = "Open Safe",
                        onSelect = function()
                            if not robbedStores[storeId] then
                                lib.notify({
                                    description = 'The till has not been robbed.',
                                    type = 'error'
                                })
                                return
                            end
                            local input = lib.inputDialog('Store Safe', {
                                { type = 'input', label = 'Enter Safe Code', required = true }
                            })
                            if not input or not input[1] or input[1] == '' then
                                lib.notify({
                                    description = 'Invalid code entered',
                                    type = 'error'
                                })
                                return
                            end
                            lib.notify({
                                description = 'Security Protocol Initiated - Verification Needed',
                                type = 'info'
                            })
                            Wait(1500)
                            TriggerServerEvent('sm_storerobbery:checkPassword', storeId, input[1])
                        end
                    }
                }
            })
        end
    end
end)

local function checkBlUI()
    local state = GetResourceState('bl_ui')
    if state ~= 'started' then
        lib.notify({
            description = 'bl_ui resource is not available',
            type = 'error'
        })
        return nil
    end
    return exports.bl_ui
end

local function requestAnimSet(set)
    if animSets[set] then return true end
    RequestAnimSet(set)
    local timeout = GetGameTimer() + 5000
    while not HasAnimSetLoaded(set) and GetGameTimer() < timeout do
        Wait(10)
    end
    animSets[set] = HasAnimSetLoaded(set)
    return animSets[set]
end

local function requestAnimDict(dict)
    if animDicts[dict] then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    animDicts[dict] = HasAnimDictLoaded(dict)
    return animDicts[dict]
end

local function performLockpick(storeId, lockpickType)
    if not currentStoreId then
        lib.notify({
            description = 'Store ID not set',
            type = 'error'
        })
        TriggerServerEvent('sm_storerobbery:lockpickFailed', storeId)
        return
    end

    if isLockpicking then
        lib.notify({
            description = 'You are already lockpicking',
            type = 'error'
        })
        return
    end

    local bl_ui = checkBlUI()
    if not bl_ui then
        TriggerServerEvent('sm_storerobbery:lockpickFailed', currentStoreId)
        currentStoreId = nil
        return
    end

    isLockpicking = true
    local iterations = (lockpickType == 'advanced') and Config.lockpickAdvancedIterations or
    Config.lockpickNormalIterations
    local difficulty = (lockpickType == 'advanced') and Config.lockpickAdvancedDifficulty or
    Config.lockpickNormalDifficulty
    local success = bl_ui:CircleProgress(iterations, difficulty)
    isLockpicking = false

    if success then
        TriggerEvent('sm_storerobbery:animationTrigger', currentStoreId)
    else
        lib.notify({
            description = 'Lockpicking Failed',
            type = 'error'
        })
        TriggerServerEvent('sm_storerobbery:lockpickFailed', currentStoreId)
        currentStoreId = nil
    end
end

RegisterNetEvent('sm_storerobbery:startLockpick', function(storeId, lockpickType)
    currentStoreId = storeId
    performLockpick(storeId, lockpickType)
end)

-- Legacy event handlers for backward compatibility
RegisterNetEvent('sm_storerobbery:lockpickNormal', function()
    performLockpick(currentStoreId, 'basic')
end)

RegisterNetEvent('sm_storerobbery:lockpickAdvanced', function()
    performLockpick(currentStoreId, 'advanced')
end)

RegisterNetEvent('sm_storerobbery:animationTrigger', function(storeId)
    if not storeId then storeId = currentStoreId end
    local store = Config.Stores[storeId]
    if not store or not store.smashCoords then
        lib.notify({
            description = 'Store not found',
            type = 'error'
        })
        TriggerServerEvent('sm_storerobbery:lockpickFailed', storeId)
        currentStoreId = nil
        return
    end

    lib.notify({
        description = 'You Have Lockpicked the Register Successfully',
        type = 'success'
    })
    TriggerEvent('sm_storerobbery:sendDispatchAlert', storeId)

    local playerPed = PlayerPedId()
    local dict = "missheist_jewel"
    local anim = "smash_case"

    local smashPos = store.smashCoords.sCoords
    local smashHeading = store.smashCoords.heading

    TaskFollowNavMeshToCoord(playerPed, smashPos.x, smashPos.y, smashPos.z, 1.0, -1, 0.2, 0, smashHeading)
    local timeout = GetGameTimer() + Config.AnimationTimeout
    local playerCoords = GetEntityCoords(playerPed)

    while GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, smashPos.x, smashPos.y, smashPos.z, true) > 0.2 and GetGameTimer() < timeout do
        playerCoords = GetEntityCoords(playerPed)
        Wait(0)
    end

    SetEntityCoords(playerPed, smashPos.x, smashPos.y, smashPos.z, false, false, false, false)
    SetEntityHeading(playerPed, smashHeading)
    FreezeEntityPosition(playerPed, true)

    local animSuccess = false
    if requestAnimDict(dict) then
        TaskPlayAnim(playerPed, dict, anim, 1.0, -1.0, -1, 49, 0, false, false, false)
        Wait(10000)
        ClearPedTasks(playerPed)
        animSuccess = true
    end

    FreezeEntityPosition(playerPed, false)
    currentStoreId = nil

    if animSuccess then
        TriggerServerEvent('sm_storerobbery:tillReward', storeId)
    else
        lib.notify({
            description = 'Animation failed, robbery cancelled',
            type = 'error'
        })
        TriggerServerEvent('sm_storerobbery:lockpickFailed', storeId)
    end
end)

RegisterNetEvent('sm_storerobbery:sendDispatchAlert', function(storeId)
    local storeData = Config.Stores[storeId]
    if not storeData then return end

    local coords = storeData.till.coords
    if type(coords) ~= "vector3" then
        coords = vector3(coords.x, coords.y, coords.z)
    end

    if Config.DispatchType == "ps" then
        pcall(function()
            exports['ps-dispatch']:CustomAlert({
                coords = coords,
                message = "Store Robbery",
                dispatchCode = "10-31",
                description = "Store Robbery at " .. storeData.label,
                radius = 1,
                sprite = 108,
                color = 1,
                scale = 1.2,
                length = 3
            })
        end)
    elseif Config.DispatchType == "cd" then
        pcall(function()
            local data = exports['cd_dispatch']:GetPlayerInfo()
            TriggerServerEvent('cd_dispatch:AddNotification', {
                job_table = { 'police' },
                coords = coords,
                title = '10-31 - Store Robbery',
                message = 'Store Robbery at ' .. storeData.label,
                flash = 0,
                unique_id = data.unique_id,
                sound = 1,
                blip = {
                    sprite = 431,
                    scale = 1.2,
                    color = 3,
                    flashes = false,
                    text = '911 - Store Robbery',
                    time = 5,
                    radius = 0
                }
            })
        end)
    elseif Config.DispatchType == "core" then
        pcall(function()
            local gender = IsPedMale(PlayerPedId()) and 'male' or 'female'
            exports['core_dispatch']:sendStoreRobbery(coords, gender)
        end)
    elseif Config.DispatchType == "wasabi" then
        pcall(function()
            exports['wasabi_dispatch']:StoreRobbery(coords)
        end)
    end
end)

RegisterNetEvent('sm_storerobbery:safeCrackAnim', function(storeId)
    if not storeId then storeId = currentStoreId end
    local store = Config.Stores[storeId]
    if not store or not store.safe then
        lib.notify({
            description = 'Store not found',
            type = 'error'
        })
        return
    end

    local playerPed = PlayerPedId()
    local safePos = store.safe.coords
    local safeHeading = store.safe.heading or store.safe.rotation or 0

    FreezeEntityPosition(playerPed, true)
    TaskFollowNavMeshToCoord(playerPed, safePos.x, safePos.y, safePos.z, 1.0, -1, 0.2, 0, safeHeading)

    local safeTimeout = GetGameTimer() + Config.SafeNavigationTimeout
    local playerCoords = GetEntityCoords(playerPed)

    while GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, safePos.x, safePos.y, safePos.z, true) > 3.0 and GetGameTimer() < safeTimeout do
        playerCoords = GetEntityCoords(playerPed)
        Wait(0)
    end

    if GetGameTimer() >= safeTimeout then
        FreezeEntityPosition(playerPed, false)
        lib.notify({
            description = 'Failed to reach safe in time',
            type = 'error'
        })
        return
    end

    SetEntityCoords(playerPed, safePos.x, safePos.y, safePos.z - 1, false, false, false, false)
    SetEntityHeading(playerPed, safeHeading)

    if requestAnimSet("move_ped_crouched") then
        SetPedMovementClipset(playerPed, "move_ped_crouched", 0.25)
    end

    local dialSuccess = false
    if requestAnimDict("mini@safe_cracking") then
        TaskPlayAnim(playerPed, "mini@safe_cracking", "dial_turn_anti_fast", 1.0, 1.0, -1, 1, 0, false, false, false)
        Wait(3500)
        ClearPedTasks(playerPed)
        dialSuccess = true
    end

    ResetPedMovementClipset(playerPed, 0.25)

    local grabSuccess = false
    if dialSuccess and requestAnimDict("anim@heists@ornate_bank@grab_cash") then
        TaskPlayAnim(playerPed, "anim@heists@ornate_bank@grab_cash", "grab", 1.0, 1.0, -1, 0, 0, false, false, false)
        Wait(10000)
        ClearPedTasks(playerPed)
        grabSuccess = true
    end

    FreezeEntityPosition(playerPed, false)

    if grabSuccess then
        TriggerServerEvent('sm_storerobbery:safeLoot', storeId)
    else
        lib.notify({
            description = 'Safe crack failed',
            type = 'error'
        })
    end
end)

RegisterNetEvent('sm_storerobbery:startUntangle', function(storeId)
    if not storeId then storeId = currentStoreId end
    if not storeId then
        lib.notify({
            description = 'Store ID not set',
            type = 'error'
        })
        return
    end

    local bl_ui = checkBlUI()
    if not bl_ui then return end

    local success = bl_ui:Untangle(3, {
        numberOfNodes = 10,
        duration = 10000,
    })

    if success then
        TriggerEvent('sm_storerobbery:safeCrackAnim', storeId)
    else
        lib.notify({
            description = 'You failed to Bypass Security Protocol',
            type = 'error'
        })
    end
end)

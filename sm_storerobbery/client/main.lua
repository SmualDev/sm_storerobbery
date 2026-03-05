
ESX = exports["es_extended"]:getSharedObject()
local robbedStores = {
}
local currentStoreId = nil
RegisterNetEvent('sm_storerobbery:setCurrentStore', function(storeId)
    currentStoreId = storeId
end)
RegisterNetEvent('sm_storerobbery:updateStoreState', function(storeId, state)
    robbedStores[storeId] = state
end)
CreateThread(function()
    for storeId, store in pairs(Config.Stores) do
        local currentStoreId = storeId
        exports.ox_target:addBoxZone({
            coords = store.till.coords,
            size = store.till.size,
            rotation = store.till.rotation,
            debug = false,
            options = {
                {
                    name = "rob_till_" .. currentStoreId,
                    icon = "fa-solid fa-mask",
                    label = "Rob Till",
                    canInteract = function()
                        return not robbedStores[currentStoreId]
                    end,
                    onSelect = function()
                        currentStoreId = currentStoreId
                        TriggerServerEvent('sm_storerobbery:startRobbery', currentStoreId)
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
                    name = "rob_safe_" .. currentStoreId,
                    icon = "fa-solid fa-vault",
                    label = "Open Safe",
                    onSelect = function()
                        if not robbedStores[currentStoreId] then
                            lib.notify({
                                description = 'The till has not been robbed.',
                                type = 'error'
                            })
                            return
                        end
                        local input = lib.inputDialog('Store Safe', {
                            { type = 'input', label = 'Enter Safe Code', required = true }
                        })
                        if not input then return end
                        lib.notify({
                            description = 'Security Protocal Initiated Verification Needed',
                            type = 'error'
                        })
                        Wait(1500)
                        TriggerServerEvent('sm_storerobbery:checkPassword', currentStoreId, input[1])
                    end
                }
            }
        })
    end
end)
RegisterNetEvent('sm_storerobbery:lockpickNormal', function()
local bl_ui = exports.bl_ui
    local success = bl_ui:CircleProgress(Config.lockpickNormalIterations, Config.lockpickNormalDifficulty)
    if success then
        TriggerEvent('sm_storerobbery:animationTrigger')
    else
lib.notify({
    description = 'Lockpicking Failed',
    type = 'error'
})
        TriggerServerEvent('sm_storerobbery:lockpickFailed', currentStoreId)
    end
end)
RegisterNetEvent('sm_storerobbery:lockpickAdvanced', function()
local bl_ui = exports.bl_ui
    local success = bl_ui:CircleProgress(Config.lockpickAdvancedIterations, Config.lockpickAdvancedDifficulty)
    if success then
        TriggerEvent('sm_storerobbery:animationTrigger')
    else
lib.notify({
    description = 'Lockpicking Failed',
    type = 'error'
})
    TriggerServerEvent('sm_storerobbery:lockpickFailed', currentStoreId)
    end
end)
RegisterNetEvent('sm_storerobbery:animationTrigger', function()
lib.notify({
    description = 'You Have Lockpicked the Register Successfully',
    type = 'success'
})
    TriggerEvent('sm_storerobbery:sendDispatchAlert', currentStoreId)
    local playerPed = PlayerPedId()
    local dict = "missheist_jewel"
    local anim = "smash_case"
    local store = Config.Stores[currentStoreId]

    local smashPos = store.smashCoords.sCoords
    local smashHeading = store.smashCoords.heading
    TaskFollowNavMeshToCoord(playerPed, smashPos.x, smashPos.y, smashPos.z, 1.0, -1, 0.2, false, smashHeading)
    local timeout = GetGameTimer() + 4000
    while GetDistanceBetweenCoords(GetEntityCoords(playerPed), smashPos.x, smashPos.y, smashPos.z, true) > 0.2 and GetGameTimer() < timeout do
        Wait(0)
    end
    SetEntityCoords(playerPed, smashPos.x, smashPos.y, smashPos.z)
    SetEntityHeading(playerPed, smashHeading)
    FreezeEntityPosition(playerPed, true)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(100)
    end

    TaskPlayAnim(playerPed, dict, anim, 1.0, -1.0, -1, 49, 0, false, false, false)
    Wait(10000)
    ClearPedTasks(playerPed)
    FreezeEntityPosition(playerPed, false)
    TriggerServerEvent('sm_storerobbery:tillReward')
end)

RegisterNetEvent('sm_storerobbery:sendDispatchAlert', function(storeId)
    local storeData = Config.Stores[storeId]
    if not storeData then 
        return 
    end
    local coords = storeData.till.coords
    if type(coords) == "table" then
        coords = vector3(coords.x, coords.y, coords.z)
    end
    if Config.DispatchType == "ps" then
        exports['ps-dispatch']:CustomAlert({
            coords = coords,
            message = "Store Robbery",
            dispatchCode = "10-31",
            description = "Store Robbery at" .. storeData.label,
            radius = 1,
            sprite = 108,
            color = 1,
            scale = 1.2,
            length = 3
        })
    elseif Config.DispatchType == "cd" then
        local data = exports['cd_dispatch']:GetPlayerInfo()
        TriggerServerEvent('cd_dispatch:AddNotification', {
            job_table = {'police',},
            coords = coords,
            title = '10-31 - Store Robbery',
            message = 'Store Robbery at' .. storeData.label,
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
               radius = 0, 
            }
        })
    elseif Config.DispatchType == "core" then
        local gender = IsPedMale(ped) or 'male' or 'female'
        exports['core_dispatch']:sendStoreRobbery(coords, gender)
    elseif Config.DispatchType == "wasabi" then
    exports['wasabi_dispatch']:StoreRobbery(coords)
    elseif Config.DispatchType == "custom" then
        print("Using Custom Dispatch")
    end
end)

RegisterNetEvent('sm_storerobbery:safeCrackAnim', function(storeId)
    local playerPed = PlayerPedId()
    local store = Config.Stores[currentStoreId]

    local safePos = store.safe.coords
    local safeHeading = store.safe.heading
    TaskFollowNavMeshToCoord(playerPed, safePos.x, safePos.y, safePos.z, 1.0, -1, 0.2, false, safeHeading)
    local timeout = GetGameTimer() + 1000
    while GetDistanceBetweenCoords(GetEntityCoords(playerPed), safePos.x, safePos.y, safePos.z, true) > 0.2 and GetGameTimer() < timeout do
        Wait(0)
    end
    RequestAnimSet("move_ped_crouched")
    while not HasAnimSetLoaded("move_ped_crouched") do Wait(0) end
    SetPedMovementClipset(ped, "move_ped_crouched", 0.25)

    local dict = "mini@safe_cracking"
    local anim = "dial_turn_anti_fast"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
    TaskPlayAnim(playerPed, dict, anim, 1.0, 1.0, -1, 1, 0, false, false, false)
    Wait(8000)
    ClearPedTasks(playerPed)
    ResetPedMovementClipset(playerPed, 0.25)
    local dict2 = "anim@heists@ornate_bank@grab_cash"
    local anim2 = "grab"

    RequestAnimDict(dict2)
    while not HasAnimDictLoaded(dict2) do Wait(0) end

    TaskPlayAnim(playerPed, dict2, anim2, 1.0, 1.0, 5000, 0, 0, false, false, false)
    Wait(5000)
    ClearPedTasks(playerPed)
    TriggerServerEvent('sm_storerobbery:safeLoot', currentStoreId)

end)

RegisterNetEvent('sm_storerobbery:startUntangle', function(storeId)
    local success = exports.bl_ui:Untangle(Config.SecurityIterations, {
        numberOfNodes = Config.SecurityNodes,
        duration = Config.SecurityDuration,
    })
    if success then
        TriggerEvent('sm_storerobbery:safeCrackAnim')
    else
        lib.notify({
            description = 'You failed to Bypass Security Protocol',
            type = 'error'
        })
    end
end)




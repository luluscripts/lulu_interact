local dui = require 'client.modules.dui'
local store = require 'client.modules.store'
local config = require 'client.modules.config'
local utils = require 'client.modules.utils'
local animation = require 'client.modules.animation'

---@type boolean
local drawLoopRunning = false

local GetEntityCoords = GetEntityCoords
local DrawSprite = DrawSprite
local SetDrawOrigin = SetDrawOrigin
local getNearbyObjects = lib.getNearbyObjects
local getNearbyPlayers = lib.getNearbyPlayers
local getNearbyVehicles = lib.getNearbyVehicles
local getNearbyPeds = lib.getNearbyPeds
local GetOffsetFromEntityInWorldCoords = GetOffsetFromEntityInWorldCoords
local GetEntityBoneIndexByName = GetEntityBoneIndexByName
local GetEntityBonePosition_2 = GetEntityBonePosition_2
local GetModelDimensions = GetModelDimensions
local NetworkGetEntityIsNetworked = NetworkGetEntityIsNetworked
local NetworkGetNetworkIdFromEntity = NetworkGetNetworkIdFromEntity
local GetEntityModel = GetEntityModel

local r, g, b, a = table.unpack(config.themeColor)


RegisterNUICallback('startHoldAnim', function(data, cb)
    local option = store.current.options?[data[1]]?[data[2]]

    cb('ok')

    if not option or not option.anim then
        return
    end

    animation.playAnim(option.anim, option.prop)
end)


local hudVisible = true

RegisterCommand('togglehud', function()
    hudVisible = not hudVisible
    
    if hudVisible then
        TriggerEvent('wais:hudv6:client:hideHud', false)
        TriggerEvent('QBCore:Notify', 'HUD Açıldı', 'success', 3000)
    else
        TriggerEvent('wais:hudv6:client:hideHud', true)
        TriggerEvent('QBCore:Notify', 'HUD Kapatıldı', 'error', 3000)
    end
end, false)


RegisterNUICallback('endHoldAnim', function(data, cb)
    animation.stopAnim()
    cb('ok')
end)

local pressed = false
lib.addKeybind({
    name = 'interact_action',
    description = 'Interact',
    defaultKey = 'E',
    onPressed = function(self)
        if GetGameTimer() > store.cooldownEndTime then
            if not next(store.current) then return end
            pressed = true
            dui.sendMessage("interact")
        end
    end,
    onReleased = function(self)
        if not pressed then return end
        pressed = false
        dui.sendMessage("release")
    end,
})


local hidePerKeybind = false

RegisterCommand('interact', function()
    hidePerKeybind = not hidePerKeybind

    if hidePerKeybind then
        table.wipe(store.nearby)
        lib.notify({
            title = 'Interact',
            description = 'Interact kapatıldı',
            type = 'warning'
        })
    else
        lib.notify({
            title = 'Interact',
            description = 'Interact açıldı',
            type = 'success'
        })
    end
end)

local modelCache, netIdCache = {}, {}

local function cachedEntityInfo(entity)
    if modelCache[entity] then
        return modelCache[entity], netIdCache[entity]
    end

    local model = GetEntityModel(entity)
    local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or nil
    modelCache[entity] = model
    netIdCache[entity] = netId
    return model, netId
end

---@param options InteractOption[]
---@param entity number
---@param distance number
---@param coords vector3
---@return nil | table<string, InteractOption[]>, number | nil, boolean | nil
local function filterValidOptions(options, entity, distance, coords)
    if not options then return nil end
    local validOptions = {}
    local totalValid = 0
    local hasGlobal = options['global'] ~= nil
    local hasNonGlobal = false

    for category, _options in pairs(options) do
        if category ~= 'global' then
            hasNonGlobal = true
        end

        local validCategoryOptions = {}

        for i = 1, #_options do
            local option = _options[i]
            local hide = false

            if not hide and not option.allowInVehicle and cache.vehicle then
                hide = true
            end


            if not hide then hide = distance > (option.distance or 2.0) end

            if not hide and option.groups then hide = not utils.hasPlayerGotGroup(option.groups) end

            if not hide and option.items then hide = not utils.hasPlayerGotItems(option.items, option.anyItem) end

            if not hide and option.canInteract then
                local success, resp = pcall(option.canInteract, entity, distance, coords, option.name)
                hide = not success or not resp
            end

            if not hide then
                validCategoryOptions[#validCategoryOptions + 1] = option
                totalValid = totalValid + 1
            end

            option.hideButton = not option.onSelect and not option.event and not option.export and not option.serverEvent and not option.command
        end

        if #validCategoryOptions > 0 then
            validOptions[category] = validCategoryOptions
        end
    end

    local hideCompletely = hasGlobal and not hasNonGlobal and totalValid == 0

    if totalValid == 0 then
        return nil, nil, hideCompletely
    end

    return validOptions, totalValid, hideCompletely
end

---@param entity number
---@param globalType string
---@return InteractOption[] | nil
local function getOptionsForEntity(entity, globalType)
    if not entity then return nil end

    if IsPedAPlayer(entity) then
        return {
            global = store.players,
        }
    end

    local model, netId = cachedEntityInfo(entity)

    local options = {
        global = (store[globalType] ~= nil and #store[globalType] > 0 and store[globalType]) or nil,
        model = (store.models[model] ~= nil and #store.models[model] > 0 and store.models[model]) or nil,
        entity = (netId and store.entities[netId] ~= nil and #store.entities[netId] > 0 and store.entities[netId]) or nil,
        localEntity = (store.localEntities[entity] ~= nil and #store.localEntities[entity] > 0 and store.localEntities[entity]) or nil,
    }

    return next(options) and options or nil
end

---@param entity number
---@param globalType string
---@return table<string, InteractOption[]> | nil
local function getBoneOptionsForEntity(entity, globalType)
    if not entity then return nil end
    local model, netId = cachedEntityInfo(entity)
    local boneOptions = {}
    local hasOptions = false

    if store.bones[globalType] then
        for boneId, options in pairs(store.bones[globalType]) do
            if #options > 0 then
                boneOptions[boneId] = boneOptions[boneId] or {}
                boneOptions[boneId].global = options
                hasOptions = true
            end
        end
    end

    if store.bones.models and store.bones.models[model] then
        for boneId, options in pairs(store.bones.models[model]) do
            if #options > 0 then
                boneOptions[boneId] = boneOptions[boneId] or {}
                boneOptions[boneId].model = options
                hasOptions = true
            end
        end
    end

    if netId and store.bones.entities and store.bones.entities[netId] then
        for boneId, options in pairs(store.bones.entities[netId]) do
            if #options > 0 then
                boneOptions[boneId] = boneOptions[boneId] or {}
                boneOptions[boneId].entity = options
                hasOptions = true
            end
        end
    end

    if not netId and store.bones.localEntities and store.bones.localEntities[entity] then
        for boneId, options in pairs(store.bones.localEntities[entity]) do
            if #options > 0 then
                boneOptions[boneId] = boneOptions[boneId] or {}
                boneOptions[boneId].localEntity = options
                hasOptions = true
            end
        end
    end

    return hasOptions and boneOptions or nil
end

---@param entity number
---@param globalType string
---@return table<string, InteractOption[]> | nil
local function getOffsetOptionsForEntity(entity, globalType)
    if not entity then return nil end
    local model, netId = cachedEntityInfo(entity)
    local offsetOptions = {}
    local hasOptions = false

    if store.offsets[globalType] then
        for offsetStr, options in pairs(store.offsets[globalType]) do
            if #options > 0 then
                offsetOptions[offsetStr] = offsetOptions[offsetStr] or {}
                offsetOptions[offsetStr].global = options
                hasOptions = true
            end
        end
    end

    if store.offsets.models and store.offsets.models[model] then
        for offsetStr, options in pairs(store.offsets.models[model]) do
            if #options > 0 then
                offsetOptions[offsetStr] = offsetOptions[offsetStr] or {}
                offsetOptions[offsetStr].model = options
                hasOptions = true
            end
        end
    end

    if netId and store.offsets.entities and store.offsets.entities[netId] then
        for offsetStr, options in pairs(store.offsets.entities[netId]) do
            if #options > 0 then
                offsetOptions[offsetStr] = offsetOptions[offsetStr] or {}
                offsetOptions[offsetStr].entity = options
                hasOptions = true
            end
        end
    end

    if not netId and store.offsets.localEntities and store.offsets.localEntities[entity] then
        for offsetStr, options in pairs(store.offsets.localEntities[entity]) do
            if #options > 0 then
                offsetOptions[offsetStr] = offsetOptions[offsetStr] or {}
                offsetOptions[offsetStr].localEntity = options
                hasOptions = true
            end
        end
    end

    return hasOptions and offsetOptions or nil
end

---@param coords vector3
---@return NearbyItem[]
local function checkNearbyEntities(coords)
    local valid = {}
    local num = 0

    local function processEntities(entities, globalType)
        for i = 1, #entities do
            local ent = entities[i]
            local entity = ent.object or ent.vehicle or ent.ped
            local model = cachedEntityInfo(entity)
            local entCoords = GetEntityCoords(entity)
            local options = getOptionsForEntity(entity, globalType)
            local boneOptions = getBoneOptionsForEntity(entity, globalType)
            local offsetOptions = getOffsetOptionsForEntity(entity, globalType)


            if options then
                num = num + 1
                valid[num] = {
                    entity = entity,
                    coords = entCoords,
                    currentDistance = #(coords - entCoords),
                    currentScreenDistance = utils.getScreenDistanceSquared(entCoords),
                    options = options
                }
            end

            if boneOptions then
                for boneId, _options in pairs(boneOptions) do
                    local boneIndex = GetEntityBoneIndexByName(entity, boneId)
                    if boneIndex ~= -1 then
                        local boneCoords = GetEntityBonePosition_2(entity, boneIndex)
                        num = num + 1
                        valid[num] = {
                            entity = entity,
                            bone = boneId,
                            coords = boneCoords,
                            currentDistance = #(coords - boneCoords),
                            currentScreenDistance = utils.getScreenDistanceSquared(boneCoords),
                            options = _options
                        }
                    end
                end
            end

            if offsetOptions then
                for offsetStr, _options in pairs(offsetOptions) do
                    local x, y, z, offsetType = utils.getCoordsAndTypeFromOffsetId(offsetStr)
                    if x and y and z and offsetType then
                        local offset = vec3(tonumber(x), tonumber(y), tonumber(z))
                        local worldPos
                        if offsetType == "offset" then
                            local min, max = GetModelDimensions(model)
                            offset = (max - min) * offset + min
                        end
                        worldPos = GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
                        num = num + 1
                        valid[num] = {
                            entity = entity,
                            offset = offsetStr,
                            coords = worldPos,
                            currentDistance = #(coords - worldPos),
                            currentScreenDistance = utils.getScreenDistanceSquared(worldPos),
                            options = _options
                        }
                    end
                end
            end
        end
    end

    processEntities(getNearbyObjects(coords, 10.0), 'objects')
    processEntities(getNearbyVehicles(coords, 10.0, true), 'vehicles')
    processEntities(getNearbyPlayers(coords, 10.0, false), 'players')
    processEntities(getNearbyPeds(coords, 10.0), 'peds')

    return valid
end

---@param coords vector3
---@param update NearbyItem[]
---@return NearbyItem[]
local function checkNearbyCoords(coords, update)
    for id, _coords in pairs(store.coordIds) do
        local dist = #(coords - _coords)
        if dist < config.maxInteractDistance then
            update[#update + 1] = {
                coords = _coords,
                currentDistance = dist,
                currentScreenDistance = utils.getScreenDistanceSquared(_coords),
                coordId = id,
                options = { coords = store.coords[id] }
            }
        end
    end
    return update
end


-- qb-core / qbx_core set this statebag on character load and clear it on logout, so interact stays off
-- on the multicharacter and spawn screens.
local function characterNotLoaded()
    if GetResourceState('qb-core') ~= 'started' and GetResourceState('qbx_core') ~= 'started' then
        return false
    end

    return not LocalPlayer.state.isLoggedIn
end

local function shouldHideInteract()
    if characterNotLoaded() or cache.vehicle or IsNuiFocused() or LocalPlayer.state.hideInteract or (lib and lib.progressActive()) or hidePerKeybind or LocalPlayer.state.invOpen then
        return true
    end
    return false
end

local activeOptions = {}

local aspectRatio = GetAspectRatio(true)

local function hasAnyEntityTargets()
    return next(store.peds) or next(store.objects) or next(store.vehicles) or next(store.players) or next(store.models) or next(store.entities) or next(store.localEntities)
end

local function hasAnyCoordTargets()
    return next(store.coordIds) ~= nil
end

local lastScanCoords
local idleSkipScans = 0
local idleNoNearbyTicks = 0

local function drawLoop()
    if drawLoopRunning then return end
    drawLoopRunning = true

    lib.requestStreamedTextureDict(config.IndicatorSprite.dict)

    local lastClosestItem, lastValidCount, lastValidOptions, lastState, lastClosestIcon, lastSentClosestId = nil, 0, nil, nil, nil, nil
    local lastMsgTime = 0
    local lastNearbyMsgTime = {}
    local smallDuiIcons = {}
    local nearbyData = {}
    local playerCoords

    local entityStartCoords = {}
    local movingEntity = {}

    CreateThread(function()
        while drawLoopRunning do
            if shouldHideInteract() then
                table.wipe(store.nearby)
                break
            end

            playerCoords = GetEntityCoords(cache.ped)
            nearbyData = {}
            for i = 1, #store.nearby do
                local item = store.nearby[i]

                -- print(json.encode(item))

                local coords = utils.getDrawCoordsForInteract(item)

                if coords then
                    if item.entity then
                        if not entityStartCoords[item.entity] then
                            entityStartCoords[item.entity] = coords
                        end

                        if coords ~= entityStartCoords[item.entity] then
                            movingEntity[item.entity] = true
                        end
                    end

                    local distance = #(playerCoords - coords)
                    local validOpts, validCount, hideCompletely = filterValidOptions(item.options, item.entity, distance, coords)
                    local id = item.bone or item.offset or item.entity or item.coordId
                    local shouldUpdate = false

                    if id == lastClosestItem then
                        if lastValidOptions then
                            shouldUpdate = not lib.table.matches(validOpts, lastValidOptions)
                        end
                    end

                    local firstIcon = nil
                    local optionsSource = validOpts or item.options
                    if optionsSource then
                        for _, opts in pairs(optionsSource) do
                            for j = 1, #opts do
                                if opts[j].icon then
                                    firstIcon = opts[j].icon
                                    break
                               end
                            end
                            if firstIcon then break end
                        end
                    end

                    nearbyData[#nearbyData + 1] = {
                        item = item,
                        coords = coords,
                        shouldUpdate = shouldUpdate,
                        hideCompletely = hideCompletely,
                        distance = distance,
                        validOpts = validOpts,
                        validCount = validCount,
                        firstIcon = firstIcon
                    }
                end
            end
            Wait(150)
        end
    end)

    local frameCount = 0
    local lastLookingAt = false

    while #store.nearby > 0 do
        Wait(0)
        local foundValid = false

        for i = 2, math.min(#nearbyData, 4) do
            local otherData = nearbyData[i]
            if otherData and otherData.coords and not otherData.hideCompletely then
                local coords = otherData.coords
                local icon = otherData.firstIcon or "fa-solid fa-hand-pointer"
                local smallDuiIdx = i - 1
                local smallDui = dui.smallDuis and dui.smallDuis[smallDuiIdx]
                if smallDui then
                    local currentTime = GetGameTimer()
                    if smallDuiIcons[smallDuiIdx] ~= icon or not lastNearbyMsgTime[smallDuiIdx] or (currentTime - lastNearbyMsgTime[smallDuiIdx] > 1500) then
                        smallDuiIcons[smallDuiIdx] = icon
                        lastNearbyMsgTime[smallDuiIdx] = currentTime
                        smallDui:sendMessage({
                            action = "setOptions",
                            value = {
                                state = "indicator",
                                icon = icon,
                                options = {}
                            }
                        })
                    end
                    SetDrawOrigin(coords.x, coords.y, coords.z)
                    DrawSprite(smallDui.dictName, smallDui.txtName, 0.0, 0.0, 0.028, 0.028 * aspectRatio, 0.0, 255, 255, 255, 220)
                    ClearDrawOrigin()
                end
            end
        end

        for k = #nearbyData, 3 do
            smallDuiIcons[k] = nil
        end

        local data = nearbyData[1]
        if data and data.coords and not data.hideCompletely then
            local item = data.item
            local coords = data.coords

            frameCount = frameCount + 1

            local success, err = pcall(function()
                local lookingAt = lastLookingAt
                if frameCount % 3 == 0 or not lastState then
                    local currentScreenDistance = utils.getScreenDistanceSquared(coords)
                    lookingAt = (currentScreenDistance < 0.012) and data.validOpts and data.validCount > 0
                    lastLookingAt = lookingAt
                end

                SetDrawOrigin(coords.x, coords.y, coords.z)
                if lookingAt then
                    DrawSprite(dui.instance.dictName, dui.instance.txtName, 0.0, 0.0, 1.0, 1.0, 0.0, 255, 255, 255, 255)
                else
                    local icon = data.firstIcon or "fa-solid fa-hand-pointer"
                    local smallDui = dui.smallDuis and dui.smallDuis[4]
                    if smallDui then
                        local currentId = item.bone or item.offset or item.entity or item.coordId
                        local currentTime = GetGameTimer()
                        if lastSentClosestId ~= currentId or lastClosestIcon ~= icon or (currentTime - lastMsgTime > 1500) then
                            lastSentClosestId = currentId
                            lastClosestIcon = icon
                            lastMsgTime = currentTime
                            smallDui:sendMessage({
                                action = "setOptions",
                                value = {
                                    state = "indicator",
                                    icon = icon,
                                    options = {}
                                }
                            })
                        end
                        DrawSprite(smallDui.dictName, smallDui.txtName, 0.0, 0.0, 0.028, 0.028 * aspectRatio, 0.0, 255, 255, 255, 220)
                    end
                end
                ClearDrawOrigin()

                local newClosestId = item.bone or item.offset or item.entity or item.coordId
                local state = lookingAt and "expanded" or "indicator"
                if lookingAt then
                    foundValid = true
                end

                if data.shouldUpdate or lastClosestItem ~= newClosestId or lastValidCount ~= data.validCount or lastState ~= state then
                    local newOptions = {}

                    if data.validOpts then
                        for _, opts in pairs(data.validOpts) do
                            for j = 1, #opts do
                                local opt = opts[j]
                                newOptions[opt] = true
                                if not activeOptions[opt] then
                                    activeOptions[opt] = true
                                    local resp = (opt.onActive or opt.whileActive) and utils.getResponse(opt)

                                    if opt.onActive then
                                        pcall(opt.onActive, resp)
                                    end

                                    if opt.whileActive then
                                        CreateThread(function()
                                            while activeOptions[opt] do
                                                pcall(opt.whileActive, resp)
                                                Wait(0)
                                            end
                                        end)
                                    end
                                end
                            end
                        end
                    end

                    if lastValidOptions then
                        for _, opts in pairs(lastValidOptions) do
                            for j = 1, #opts do
                                local opt = opts[j]

                                if opt.onInactive and not newOptions[opt] and activeOptions[opt] then
                                    pcall(opt.onInactive, utils.getResponse(opt))
                                    activeOptions[opt] = nil
                                end
                            end
                        end
                    end

                    local resetIndex = lastClosestItem ~= newClosestId
                    lastClosestItem = newClosestId
                    lastValidCount = data.validCount
                    lastValidOptions = data.validOpts
                    lastState = state

                    if lookingAt then
                        store.current = {
                            options = data.validOpts,
                            entity = item.entity,
                            distance = data.distance,
                            coords = coords,
                            index = 1,
                        }
                    else
                        store.current = {}
                    end

                    dui.sendMessage('setOptions', { 
                        options = data.validOpts or {}, 
                        resetIndex = resetIndex, 
                        state = state, 
                        icon = data.firstIcon 
                    })
                end
            end)

            if not success then
                print("^1[lulu_interact] Error in draw loop: " .. tostring(err) .. "^7")
            end
        end

        if not foundValid and next(store.current) then
            if store.current.options then
                for _, opts in pairs(store.current.options) do
                    for j = 1, #opts do
                        local opt = opts[j]

                        if opt.onInactive and activeOptions[opt] then
                            pcall(opt.onInactive, utils.getResponse(opt))
                            activeOptions[opt] = nil
                        end
                    end
                end
            end
            store.current = {}
            lastClosestItem = nil
        end
    end

    SetStreamedTextureDictAsNoLongerNeeded(config.IndicatorSprite.dict)

    drawLoopRunning = false
end

local function BuilderLoop()
    while true do
        local waitTime = 1000
        -- print(drawLoopRunning)
        if shouldHideInteract() then
            table.wipe(store.nearby)
            waitTime = 750
        else
            local hasEntityTargets = hasAnyEntityTargets()
            local hasCoordTargets = hasAnyCoordTargets()

            if not hasEntityTargets and not hasCoordTargets then
                table.wipe(store.nearby)
                waitTime = 2000
                goto continue
            end

            local coords = GetEntityCoords(cache.ped)
            local movedEnough = (not lastScanCoords) or (#(coords - lastScanCoords) > 0.75)

            if not drawLoopRunning and not movedEnough then
                idleSkipScans = idleSkipScans + 1
                if idleSkipScans < 3 then
                    waitTime = math.min(2500, 1200 + (idleNoNearbyTicks * 150))
                    goto continue
                end
                idleSkipScans = 0
            end

            lastScanCoords = coords
            local update = {}

            if hasEntityTargets then
                update = checkNearbyEntities(coords)
            end

            if hasCoordTargets then
                update = checkNearbyCoords(coords, update)
            end

            store.nearby = update

            if #store.nearby > 1 then
                table.sort(store.nearby, function(a, b)
                    return a.currentScreenDistance < b.currentScreenDistance
                end)
            end

            if #store.nearby > 0 and not drawLoopRunning then
                CreateThread(drawLoop)
                waitTime = 500
                idleNoNearbyTicks = 0
            elseif #store.nearby == 0 then
                idleNoNearbyTicks = math.min(idleNoNearbyTicks + 1, 10)
                waitTime = math.min(2500, 1000 + (idleNoNearbyTicks * 150))
            else
                idleNoNearbyTicks = 0
            end
        end
        ::continue::
        Wait(waitTime)
    end
end

RegisterNUICallback('select', function(data, cb)
    local currentTime = GetGameTimer()
    if store.current.options and currentTime > (store.cooldownEndTime or 0) then
        local option = store.current.options?[data[1]]?[data[2]]
        if option then
            if option.onSelect then
                option.onSelect(option.qtarget and store.current.entity or utils.getResponse(option))
            elseif option.export then
                exports[option.resource][option.export](nil, utils.getResponse(option))
            elseif option.event then
                TriggerEvent(option.event, utils.getResponse(option))
            elseif option.serverEvent then
                TriggerServerEvent(option.serverEvent, utils.getResponse(option, true))
            elseif option.command then
                ExecuteCommand(option.command)
            end
            local cooldown = option.cooldown or 1500
            store.cooldownEndTime = currentTime + cooldown
            if cooldown > 0 then
                dui.sendMessage('setCooldown', true)
                Wait(cooldown)
                dui.sendMessage('setCooldown', false)
            end
        end
    end
    cb(1)
end)

CreateThread(BuilderLoop)

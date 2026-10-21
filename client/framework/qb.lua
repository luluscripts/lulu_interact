local QBCore = exports['qb-core']:GetCoreObject()

local success, result = pcall(function()
    return QBCore.Functions.GetPlayerData()
end)

local playerData = success and result or {}
local utils = require 'client.modules.utils'
local playerItems = utils.getItems()

local function setPlayerItems()
    if not playerData or not playerData.items then return end

    table.wipe(playerItems)

    for _, item in pairs(playerData.items) do
        playerItems[item.name] = (playerItems[item.name] or 0) + (item.amount or 0)
    end
end

local usingOxInventory = utils.hasExport('ox_inventory.Items')

if not usingOxInventory then
    setPlayerItems()
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerData = QBCore.Functions.GetPlayerData()
    if not usingOxInventory then setPlayerItems() end
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    if source == '' then return end

    playerData = val

    if not usingOxInventory then setPlayerItems() end
end)

---@diagnostic disable-next-line: duplicate-set-field
function utils.hasPlayerGotGroup(filter)
    -- playerData is empty until a character is loaded (multicharacter / spawn screens)
    if not playerData or not playerData.citizenid then return false end

    local jobName = playerData.job and playerData.job.name
    local gangName = playerData.gang and playerData.gang.name
    local jobLevel = playerData.job and playerData.job.grade and playerData.job.grade.level or 0
    local gangLevel = playerData.gang and playerData.gang.grade and playerData.gang.grade.level or 0

    local _type = type(filter)

    if _type == 'string' then
        if jobName == filter or gangName == filter or playerData.citizenid == filter then
            return true
        end
    elseif _type == 'table' then
        local tabletype = table.type(filter)

        if tabletype == 'hash' then
            for name, grade in pairs(filter) do
                if (jobName == name and grade <= jobLevel)
                    or (gangName == name and grade <= gangLevel)
                    or playerData.citizenid == name then
                    return true
                end
            end
        elseif tabletype == 'array' then
            for i = 1, #filter do
                local name = filter[i]

                if jobName == name or gangName == name or playerData.citizenid == name then
                    return true
                end
            end
        end
    end

    return false
end

return utils
local store = require 'client.modules.store'
local config = require 'client.modules.config'

local dui = {}
local screenW, screenH = GetActualScreenResolution()
local controlsRunning = false

function dui.register()
    if dui.instance then
        pcall(function() dui.instance:remove() end)
        dui.instance = nil
    end

    dui.instance = lib.dui:new(
        {
            url = ("nui://%s/web/index.html"):format(cache.resource),
            width = screenW,
            height = screenH,
        }
    )

    while not dui.loaded do Wait(100) end

    dui.sendMessage('visible', true)
    dui.sendMessage('setColor', config.themeColor)

    -- Allocate 4 small DUIs (1-3 for nearby targets, 4 for closest target in indicator mode)
    -- Reducing from 10 to 4 reduces CEF load by 60%, preventing thread collisions and crashes.
    dui.smallDuis = {}
    for i = 1, 4 do
        dui.smallDuis[i] = lib.dui:new({
            url = ("nui://%s/web/index.html"):format(cache.resource),
            width = 512,
            height = 512,
        })
        Wait(50) -- Delay to let game engine stagger browser creations
    end

    Wait(500)
    for i = 1, 4 do
        if dui.smallDuis[i] then
            dui.smallDuis[i]:sendMessage({
                action = 'visible',
                value = true
            })
            dui.smallDuis[i]:sendMessage({
                action = 'setColor',
                value = config.themeColor
            })
        end
    end
end

RegisterNuiCallback('load', function(_, cb)
    dui.loaded = true
    Wait(1000)
    cb(1)
end)

RegisterNuiCallback('currentOption', function(data, cb)
    store.current.index = data[1]
    cb(1)
end)

function dui.sendMessage(action, value)
    if not dui.instance then return end
    dui.instance:sendMessage({
        action = action,
        value = value
    })

    if action == 'setOptions' and not controlsRunning then
        if controlsRunning then return end
        controlsRunning = true
        CreateThread(function()
            while next(store.current) do
                dui.handleDuiControls()
                Wait(0)
            end
            controlsRunning = false
        end)
    end
end

local IsControlJustPressed = IsControlJustPressed
local SendDuiMouseWheel = SendDuiMouseWheel

dui.handleDuiControls = function()
    if not dui.instance?.duiObject then return end

    local input = false

    if (IsControlJustPressed(3, 180)) then
        SendDuiMouseWheel(dui.instance.duiObject, -50, 0.0)
        input = true
    end

    if (IsControlJustPressed(3, 181)) then
        SendDuiMouseWheel(dui.instance.duiObject, 50, 0.0)
        input = true
    end

    if (IsControlJustPressed(3, 173)) then
        SendDuiMouseWheel(dui.instance.duiObject, -50, 0.0)
        input = true
    end

    if (IsControlJustPressed(3, 172)) then
        SendDuiMouseWheel(dui.instance.duiObject, 50, 0.0)
        input = true
    end

    if input then
        Wait(200)
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == cache.resource then
        if dui.instance then
            pcall(function() dui.instance:remove() end)
            dui.instance = nil
        end
        if dui.smallDuis then
            for i = 1, 4 do
                local smallDui = dui.smallDuis[i]
                if smallDui and type(smallDui) == 'table' and smallDui.remove then
                    pcall(function()
                        smallDui:remove()
                    end)
                end
            end
            dui.smallDuis = nil
        end
    end
end)

-- Register async thread to prevent startup freezes and CEF engine crashes
CreateThread(function()
    dui.register()
end)

return dui

local isTextUIOpen = false
local currentItems = {}

function ShowTextUI(items)
    if not items or #items == 0 then
        items = {{key = 'E', text = 'Open'}}
    end
    
    currentItems = items
    isTextUIOpen = true
    
    SendNUIMessage({
        action = 'showTextUI',
        items = items
    })
end

function HideTextUI()
    isTextUIOpen = false
    currentItems = {}
    
    SendNUIMessage({
        action = 'hideTextUI'
    })
end

function UpdateTextUI(items)
    if not items or #items == 0 then
        return
    end
    
    currentItems = items
    
    SendNUIMessage({
        action = 'updateTextUI',
        items = items
    })
end

function IsTextUIOpen()
    return isTextUIOpen
end

function GetCurrentItems()
    return currentItems
end

exports('ShowTextUI', ShowTextUI)
exports('HideTextUI', HideTextUI)
exports('UpdateTextUI', UpdateTextUI)
exports('IsTextUIOpen', IsTextUIOpen)
exports('GetCurrentItems', GetCurrentItems)

_G.ShowTextUI = ShowTextUI
_G.HideTextUI = HideTextUI
_G.UpdateTextUI = UpdateTextUI
_G.IsTextUIOpen = IsTextUIOpen
_G.GetCurrentItems = GetCurrentItems

-- RegisterCommand('testui', function(source, args, rawCommand)
--     local testType = args[1] or 'single'
    
--     if testType == 'single' then
--         exports['lulu_interact']:ShowTextUI({{key = 'E', text = 'Open Door'}})
        
--     elseif testType == 'multi' then
--         exports['lulu_interact']:ShowTextUI({
--             {key = 'E', text = 'Open'},
--             {key = 'F', text = 'Close'},
--             {key = 'G', text = 'Lock'},
--             {key = 'H', text = 'Unlock'}
--         })
        
--     elseif testType == 'hide' then
--         exports['lulu_interact']:HideTextUI()
        
--     elseif testType == 'update' then
--         exports['lulu_interact']:UpdateTextUI({{key = 'E', text = 'Updated Text!'}})
--     end
-- end, false)

-- RegisterCommand('testuiauto', function()
--     Citizen.CreateThread(function()
--         Wait(500)
--         exports['lulu_interact']:ShowTextUI({{key = 'E', text = 'Test 1'}})
        
--         Wait(2000)
--         exports['lulu_interact']:UpdateTextUI({
--             {key = 'E', text = 'Option 1'},
--             {key = 'F', text = 'Option 2'},
--             {key = 'G', text = 'Option 3'}
--         })
        
--         Wait(2000)
--         exports['lulu_interact']:UpdateTextUI({{key = 'E', text = 'Updated!'}})
        
--         Wait(2000)
--         exports['lulu_interact']:HideTextUI()
--     end)
-- end, false)

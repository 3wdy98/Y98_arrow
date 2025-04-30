

print('^2Arrow Mini-Game resource started^7')

RegisterServerEvent('Y98_arrow:logActivity')
AddEventHandler('Y98_arrow:logActivity', function(success, rounds)
    local src = source
    local playerName = GetPlayerName(src)
    if success then
        print(playerName .. ' successfully completed the arrow minigame with ' .. rounds .. ' rounds')
    else
        print(playerName .. ' failed the arrow minigame')
    end
end)


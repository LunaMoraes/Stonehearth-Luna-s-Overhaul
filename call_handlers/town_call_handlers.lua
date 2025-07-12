local TownCallHandlers = class()

function TownCallHandlers:get_elapsed_days(session, response)
   local town = stonehearth.town:get_town(session.player_id)
   if town then
      -- Call the monkey-patched function to get elapsed days and update saved variables
      local elapsed_days = town:get_elapsed_days()
      
      response:resolve({ elapsed_days = elapsed_days })
   else
      response:reject('no town found for player')
   end
end

return TownCallHandlers

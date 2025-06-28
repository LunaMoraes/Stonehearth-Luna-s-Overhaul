local log = radiant.log.create_logger('pet_commands')

local Commands = class()

function Commands:add_pet_command(session, response, pet_uri)
   if not pet_uri then
      response:reject('Failed: No pet URI provided.')
      return
   end

   local player_id = session.player_id
   local town = stonehearth.town:get_town(player_id)
   if not town then
      response:reject('Failed: No town for player ' .. tostring(player_id))
      return
   end

   local pet = radiant.entities.create_entity(pet_uri, { owner = player_id })
   if not pet then
      response:reject('Failed: Could not create entity ' .. pet_uri)
      return
   end

   -- Place the entity first (like the merchant does)
   local landing_location = town:get_landing_location()
   local location = radiant.terrain.find_placement_point(landing_location, 20, 30)
   radiant.terrain.place_entity(pet, location)

   -- Now add pet component and set owner (like the merchant does)
   local pet_component = pet:add_component('stonehearth:pet')
   pet_component:convert_to_pet(player_id)
   local citizens = stonehearth.population:get_population(player_id):get_citizens()
   local citizen_ids = citizens:get_keys()
   if #citizen_ids > 0 then
      local citizen_id = citizen_ids[1]
      pet_component:set_owner(citizens:get(citizen_id))
   end

   -- Add the pet utility buff for testing
   local buffs_component = pet:get_component('stonehearth:buffs')
   if buffs_component then
      log:info('Adding pet utility buff to entity: %s', tostring(pet))
      buffs_component:add_buff('luna_overhaul:buffs:pet_utility_level1')
      log:info('Pet utility buff added successfully')
   else
      log:error('Pet has no buffs component!')
   end

   return true
end

return Commands

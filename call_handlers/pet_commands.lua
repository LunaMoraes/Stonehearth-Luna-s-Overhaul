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
      --log:info('Adding pet utility buff to entity: %s', tostring(pet))
      --buffs_component:add_buff('luna_overhaul:buffs:pet_utility_level1')
      --log:info('Pet utility buff added successfully')
   else
      log:error('Pet has no buffs component!')
   end

   return true
end

function Commands:add_pet_xp_command(session, response, entity)
   -- Check if entity is provided and valid
   if not entity or not entity:is_valid() then
      response:reject('Failed: No valid entity provided')
      return
   end
   
   -- Check if the entity has a pet skill component
   local pet_skill_component = entity:get_component('luna_overhaul:pet_skill')
   if not pet_skill_component then
      response:reject('Failed: Selected entity is not a pet with skill component')
      return
   end
   
   local exp_amount = 50  -- 2 uses will level up from level 1 (needs 100 XP)
   local success = pet_skill_component:give_experience(exp_amount)
   
   if success then
      local status = pet_skill_component:get_pet_status()
      log:info('Added %d XP to pet %s. Status: Level %d, XP %d/%d, Branch: %s', 
               exp_amount, tostring(entity), status.level, status.experience, status.exp_to_next, status.branch or 'none')
      response:resolve(true)
   else
      response:reject('Failed: Could not add experience to pet')
   end
end

function Commands:pet_change_branch_command(session, response, entity)
   -- Check if entity is provided and valid
   if not entity or not entity:is_valid() then
      response:reject('Failed: No valid entity provided')
      return
   end
   
   -- Check if the entity has a pet skill component
   local pet_skill_component = entity:get_component('luna_overhaul:pet_skill')
   if not pet_skill_component then
      response:reject('Failed: Selected entity is not a pet with skill component')
      return
   end
   
   local branch_name = 'utility'
   local success = pet_skill_component:train_branch(branch_name)
   
   if success then
      local status = pet_skill_component:get_pet_status()
      log:info('Changed pet %s branch to %s. Status: Level %d, XP %d/%d', 
               tostring(entity), branch_name, status.level, status.experience, status.exp_to_next)
      response:resolve(true)
   else
      response:reject('Failed: Could not change pet branch')
   end
end

return Commands

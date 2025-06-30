local PetComponent = require 'stonehearth.components.pet.pet_component'
local LunaPetComponent = class()

local log = radiant.log.create_logger('luna_overhaul')

-- Monkey patch the convert_to_pet function to add pet_skill_component
LunaPetComponent._luna_old_convert_to_pet = PetComponent.convert_to_pet
function LunaPetComponent:convert_to_pet(player_id)
   -- Call the original function first
   self:_luna_old_convert_to_pet(player_id)
   
   -- Add the pet skill component if it doesn't exist
   if not self._entity:get_component('luna_overhaul:pet_skill') then
      self._entity:add_component('luna_overhaul:pet_skill')
      log:info('Added luna_overhaul:pet_skill_component to pet %s', self._entity)
   end
end

return LunaPetComponent

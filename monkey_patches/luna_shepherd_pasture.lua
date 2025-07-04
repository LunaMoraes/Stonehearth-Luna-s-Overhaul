local ShepherdPastureComponent = require 'stonehearth.components.shepherd_pasture.shepherd_pasture_component'
local LunaShepherdPastureComponent = class()

local log = radiant.log.create_logger('luna_overhaul')

-- We patch the original add_animal function.
local old_add_animal = ShepherdPastureComponent.add_animal
function LunaShepherdPastureComponent:add_animal(animal)
   -- First, call the original function to do its work.
   old_add_animal(self, animal)
   
   -- Then, call our new function on the town to track the animal.
   local town = stonehearth.town:get_town(self._entity)
   if town then
      town:add_pasture_animal(animal)
   end
end

-- We do the same for remove_animal.
local old_remove_animal = ShepherdPastureComponent.remove_animal
function LunaShepherdPastureComponent:remove_animal(animal_id)
   -- We need to get the animal entity before it's removed by the original function.
   local animal = self._sv.tracked_critters[animal_id] and self._sv.tracked_critters[animal_id].entity
   
   -- Call the original function.
   old_remove_animal(self, animal_id)
   
   -- Then, call our new function on the town to stop tracking the animal.
   if animal then
      local town = stonehearth.town:get_town(self._entity)
      if town then
         town:remove_pasture_animal(animal)
      end
   end
end

return LunaShepherdPastureComponent
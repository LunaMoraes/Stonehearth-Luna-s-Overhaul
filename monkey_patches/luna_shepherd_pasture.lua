local ShepherdPastureComponent = require 'stonehearth.components.shepherd_pasture.shepherd_pasture_component'
local LunaShepherdPastureComponent = class()

local log = radiant.log.create_logger('luna_overhaul')

-- Store reference to original functions we'll override
local old_add_animal = ShepherdPastureComponent.add_animal
local old_remove_animal = ShepherdPastureComponent.remove_animal
local old_reproduce = ShepherdPastureComponent._reproduce

-- Patch the base game's _reproduce function to ensure proper sequence
function LunaShepherdPastureComponent:_reproduce()
   local reproduction_uri = self._pasture_data[self._sv.pasture_type].reproduction_uri or self._sv.pasture_type
   
   -- Create the baby animal
   local animal = radiant.entities.create_entity(reproduction_uri, { owner = self._entity })
   log:info('LUNA: Baby animal %s created and being converted to pasture animal', animal:get_uri())
   
   -- Place the animal in the world FIRST - this initializes components
   local position = radiant.terrain.find_placement_point(self:get_center_point(), 0, 2)
   radiant.terrain.place_entity(animal, position, { force_iconic=false })
   
   -- NOW convert to pasture animal after placement when components are ready
   self:convert_to_pasture_animal(animal)
   
   -- Add the effect
   radiant.effects.run_effect(animal, 'stonehearth:effects:fursplosion_effect')
end

-- Simplified convert_to_pasture_animal that follows base game logic exactly
function LunaShepherdPastureComponent:convert_to_pasture_animal(animal)
   -- Add equipment and collar like the base game does
   local equipment_component = animal:add_component('stonehearth:equipment')
   local pasture_collar = radiant.entities.create_entity('stonehearth:pasture_equipment:tag')
   equipment_component:equip_item(pasture_collar)
   local shepherded_animal_component = pasture_collar:get_component('stonehearth:shepherded_animal')
   shepherded_animal_component:set_animal(animal)
   shepherded_animal_component:set_pasture(self._entity)
   
   -- Ensure required components exist before calling add_animal
   local added_components = {}
   if not animal:get_component('stonehearth:buffs') then
      animal:add_component('stonehearth:buffs')
      table.insert(added_components, 'buffs')
   end
   
   if not animal:get_component('stonehearth:commands') then
      animal:add_component('stonehearth:commands')
      table.insert(added_components, 'commands')
   end
   
   if #added_components > 0 then
      log:info('LUNA: Added missing components to %s: %s', animal:get_uri(), table.concat(added_components, ', '))
   end
   
   -- Now call add_animal with components guaranteed to exist
   self:add_animal(animal)
end

-- We patch the original add_animal function to add town tracking
function LunaShepherdPastureComponent:add_animal(animal)
   -- First, call the original function to do its work.
   old_add_animal(self, animal)
   
   -- Add to town tracking if components are ready (they should be after our fix)
   local buffs = animal:get_component('stonehearth:buffs')
   local commands = animal:get_component('stonehearth:commands')
   
   if buffs and commands then
      local town = stonehearth.town:get_town(self._entity)
      if town then
         town:add_pasture_animal(animal)
         log:info('LUNA: Added %s to town livestock tracking', animal:get_uri())
      end
   else
      log:warning('LUNA: Animal %s missing components, not added to town tracking', animal:get_uri())
   end
end

-- Remove animals from town tracking when they're removed from pasture
function LunaShepherdPastureComponent:remove_animal(animal_id)
   -- Get the animal entity before it's removed by the original function
   local animal = self._sv.tracked_critters[animal_id] and self._sv.tracked_critters[animal_id].entity
   
   -- Call the original function
   old_remove_animal(self, animal_id)
   
   -- Remove from town tracking
   if animal then
      local town = stonehearth.town:get_town(self._entity)
      if town then
         town:remove_pasture_animal(animal)
      end
   end
end

return LunaShepherdPastureComponent
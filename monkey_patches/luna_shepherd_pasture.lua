local ShepherdPastureComponent = require 'stonehearth.components.shepherd_pasture.shepherd_pasture_component'
local LunaShepherdPastureComponent = class()

local log = radiant.log.create_logger('luna_overhaul')

-- Store reference to original functions we'll override
local old_add_animal = ShepherdPastureComponent.add_animal
local old_remove_animal = ShepherdPastureComponent.remove_animal
local old_reproduce = ShepherdPastureComponent._reproduce
local old_post_creation_setup = ShepherdPastureComponent.post_creation_setup
local old_activate = ShepherdPastureComponent.activate

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

   -- Check for auto-butcher after converting animal
   log:debug('LUNA: About to call _check_auto_butcher from convert_to_pasture_animal')
   self:_check_auto_butcher()
end

-- We patch the original add_animal function to add town tracking
function LunaShepherdPastureComponent:add_animal(animal)
   log:debug('LUNA: add_animal() called for %s', animal:get_uri())
   
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

   -- Check for auto-butcher after adding animal
   log:debug('LUNA: About to call _check_auto_butcher from add_animal')
   self:_check_auto_butcher()
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
   
   -- Remove from queued slaughters if it was queued
   if self._sv._queued_slaughters then
      self._sv._queued_slaughters[animal_id] = nil
   end
end

-- Auto-butcher functionality
function LunaShepherdPastureComponent:activate()
   -- Call the original activate function
   old_activate(self)
   
   -- Initialize auto_butcher setting for existing pastures that don't have it yet
   log:debug('LUNA: activate() called, current auto_butcher value: %s', tostring(self._sv.auto_butcher))
   if self._sv.auto_butcher == nil then
      log:debug('LUNA: Initializing auto_butcher to false in activate()')
      self._sv.auto_butcher = false
      self.__saved_variables:mark_changed()
   else
      log:debug('LUNA: auto_butcher already set to: %s', tostring(self._sv.auto_butcher))
   end
end

function LunaShepherdPastureComponent:post_creation_setup()
   -- Call the original post_creation_setup if it exists
   if old_post_creation_setup then
      old_post_creation_setup(self)
   end
   
   -- Initialize auto_butcher setting for new pastures
   log:debug('LUNA: post_creation_setup() called, initializing auto_butcher to false')
   self._sv.auto_butcher = false
   self.__saved_variables:mark_changed()
end

function LunaShepherdPastureComponent:set_auto_butcher_enabled(enabled)
   log:debug('LUNA: Setting auto_butcher to %s for pasture %s', enabled, self._entity:get_uri())
   if self._sv.auto_butcher ~= enabled then
      self._sv.auto_butcher = enabled
      self.__saved_variables:mark_changed()
      log:debug('LUNA: auto_butcher setting saved and marked as changed')
   end
end

function LunaShepherdPastureComponent:_check_auto_butcher()
   log:debug('LUNA: Checking auto-butchering for pasture %s', self._entity:get_uri())
   if not self._sv.auto_butcher then
      return
   end

   local current_population = self._sv.num_critters
   local max_population = self:get_max_animals()

   -- Check if we're at 2/3 capacity (rounded up)
   local threshold = math.ceil(max_population * 2 / 3)

   if current_population >= threshold then
      self:_butcher_adult_animal()
   end
end

function LunaShepherdPastureComponent:_butcher_adult_animal()
   local adult_animals = {}

   -- Find all adult animals in the pasture that can be slaughtered
   for animal_id, data in pairs(self._sv.tracked_critters) do
      local animal = data.entity
      if animal and animal:is_valid() then
         -- Check if animal is not young by looking at evolve_data
         local evolve_data = animal:get_component('stonehearth:evolve_data')
         local is_young = false
         if evolve_data then
            local current_stage = evolve_data:get_current_stage()
            is_young = (current_stage == 'young')
         end

         -- Don't slaughter young animals or animals that are already queued for slaughter
         if not is_young and not (self._sv._queued_slaughters and self._sv._queued_slaughters[animal_id]) then
            -- Also don't slaughter animals that are currently following a shepherd
            local equipment_component = animal:get_component('stonehearth:equipment')
            local pasture_tag = equipment_component and equipment_component:has_item_type('stonehearth:pasture_equipment:tag')
            local shepherded_component = pasture_tag and pasture_tag:get_component('stonehearth:shepherded_animal')
            if not (shepherded_component and shepherded_component:get_following()) then
               table.insert(adult_animals, animal)
            end
         end
      end
   end

   -- If we have adult animals, pick one randomly to butcher
   if #adult_animals > 0 then
      local animal_to_butcher = adult_animals[math.random(#adult_animals)]
      log:info('LUNA: Auto-butchering adult animal %s due to 2/3 capacity reached', animal_to_butcher:get_uri())

      -- Use ACE's slaughter logic
      local resource_component = animal_to_butcher:get_component('stonehearth:resource_node')
      if resource_component and resource_component:is_harvestable() then
         -- Initialize queued slaughters table if it doesn't exist
         if not self._sv._queued_slaughters then
            self._sv._queued_slaughters = {}
         end
         
         -- Mark this animal as queued for slaughter
         self._sv._queued_slaughters[animal_to_butcher:get_id()] = true
         
         -- Check if we have an output component (like ACE does)
         local output = self._entity:get_component('stonehearth_ace:output')
         if output and output:has_any_input(true) then
            -- If there's an output component with inputs, spawn the resource immediately
            resource_component:spawn_resource(nil, radiant.entities.get_world_location(animal_to_butcher), radiant.entities.get_player_id(self._entity), false)
         else
            -- Otherwise, request harvest normally (shepherd will come to slaughter)
            resource_component:request_harvest(self._entity:get_player_id())
         end
         
         self.__saved_variables:mark_changed()
      end
   end
end

return LunaShepherdPastureComponent
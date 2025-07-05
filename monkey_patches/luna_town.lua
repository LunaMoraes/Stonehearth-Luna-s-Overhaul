local Town = require 'stonehearth.services.server.town.town'
local LunaTown = class()

local log = radiant.log.create_logger('luna_overhaul')

-- This function will be called by the UI to get the list of animals.
function LunaTown:get_pasture_animals()
   if not self._pasture_animals then
      if not self._sv.pasture_animals then
         self._sv.pasture_animals = {}
      end
      self._pasture_animals = self._sv.pasture_animals
   end
   return self._pasture_animals
end

-- This function will be called by pastures when a new animal is added.
function LunaTown:add_pasture_animal(animal)
   if not self._pasture_animals then
      self._pasture_animals = {}
   end
   log:info('LUNA DEBUG: Adding pasture animal %s (URI: %s) to town tracker', tostring(animal), animal:get_uri())
   
   -- Let's check the animal's components when we add it to town tracking
   local buffs = animal:get_component('stonehearth:buffs')
   local commands = animal:get_component('stonehearth:commands')
   local ai = animal:get_component('stonehearth:ai')
   
   log:info('LUNA DEBUG: Town add - Animal %s has buffs: %s, commands: %s, ai: %s', 
      tostring(animal), tostring(buffs), tostring(commands), tostring(ai))
   
   self._pasture_animals[animal:get_id()] = animal
   self:_save_pasture_animals_sv()
   
   log:info('LUNA DEBUG: Town tracking updated, total animals: %d', radiant.size(self._pasture_animals))
end

-- This function will be called by pastures when an animal is removed.
function LunaTown:remove_pasture_animal(animal)
   if self._pasture_animals and animal then
      log:info('Removing pasture animal ' .. tostring(animal) .. ' from town tracker')
      self._pasture_animals[animal:get_id()] = nil
      self:_save_pasture_animals_sv()
   end
end

-- This function saves the animal list to the game's save file.
function LunaTown:_save_pasture_animals_sv()
   if not self._sv.pasture_animals then
      self._sv.pasture_animals = {}
   end
   self._sv.pasture_animals = self._pasture_animals
   self.__saved_variables:mark_changed()
end

-- We patch the original 'activate' function to ensure our table exists when the town loads.
local old_activate = Town.activate
function LunaTown:activate(...)
   -- Initialize our table from saved variables, or create it if it doesn't exist.
   if not self._sv.pasture_animals then
      self._sv.pasture_animals = {}
   end
   self._pasture_animals = self._sv.pasture_animals
   
   -- Call the original activate function.
   old_activate(self, ...)
end

return LunaTown
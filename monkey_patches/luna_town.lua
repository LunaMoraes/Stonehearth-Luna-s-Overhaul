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
   
   log:info('[luna_overhaul] Town tracking updated, total animals: %d', radiant.size(self._pasture_animals))
end

-- This function will be called by pastures when an animal is removed.
function LunaTown:remove_pasture_animal(animal)
   if self._pasture_animals and animal then
      log:info('[luna_overhaul] Removing pasture animal ' .. tostring(animal) .. ' from town tracker')
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
   
   -- Initialize elapsed_days for UI tracing
   self._sv.elapsed_days = stonehearth.calendar:get_elapsed_days()
   self.__saved_variables:mark_changed()
   
   -- Call the original activate function.
   old_activate(self, ...)
end

-- Add a getter function that updates elapsed days whenever called
function LunaTown:get_elapsed_days()
   local current_days = stonehearth.calendar:get_elapsed_days()
   log:debug('[luna_overhaul] Elapsed days requested, current value: %d', current_days)
   -- Update saved variables so UI trace picks it up
   if self._sv.elapsed_days ~= current_days then
      self._sv.elapsed_days = current_days
      self.__saved_variables:mark_changed()
   end
   return current_days
end

-- Patch get_persistence_data to update elapsed_days whenever it's called
-- This function gets called periodically by various game systems
local luna_ace_old_get_persistence_data = Town.get_persistence_data
function LunaTown:get_persistence_data()
   -- Update elapsed_days before calling the original function
   local current_days = stonehearth.calendar:get_elapsed_days()
   if self._sv.elapsed_days ~= current_days then
      self._sv.elapsed_days = current_days
      self.__saved_variables:mark_changed()
      log:info('[luna_overhaul] Updated elapsed_days to %d in get_persistence_data', current_days)
   end
   
   -- Call the original function to get all the data from ACE
   local data = luna_ace_old_get_persistence_data(self)
   return data
end

return LunaTown
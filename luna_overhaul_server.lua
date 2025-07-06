local luna_overhaul = {}
local patches_applied = false

-- Monkey patching function
local function monkey_patching()
   if patches_applied then
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey patches already applied, skipping')
      return
   end
   
   -- Patch for pet component
   local pet_monkey_see = require('monkey_patches.pet_component_patch')
   local pet_monkey_do = radiant.mods.require('stonehearth.components.pet.pet_component')
   if pet_monkey_see and pet_monkey_do then
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching pet_component to add pet_skill_component')
      radiant.mixin(pet_monkey_do, pet_monkey_see)
   else
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server ***FAILED*** to monkey-patch pet_component')
   end

   -- Patch for shepherd class
   local shepherd_monkey_see = require('monkey_patches.luna_shepherd')
   local shepherd_monkey_do = radiant.mods.require('stonehearth.jobs.shepherd.shepherd')
   if shepherd_monkey_see and shepherd_monkey_do then
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching AceShepherdClass')
      radiant.mixin(shepherd_monkey_do, shepherd_monkey_see)
   else
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server ***FAILED*** to monkey-patch AceShepherdClass')
   end

   -- Patch for town component
   local town_monkey_see = require('monkey_patches.luna_town')
   local town_monkey_do = radiant.mods.require('stonehearth.services.server.town.town')
   if town_monkey_see and town_monkey_do then
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching Town to add pasture animal tracking')
      radiant.mixin(town_monkey_do, town_monkey_see)
   else
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server ***FAILED*** to monkey-patch Town')
   end

   -- Patch for shepherd pasture component
   local pasture_monkey_see = require('monkey_patches.luna_shepherd_pasture')
   local pasture_monkey_do = radiant.mods.require('stonehearth.components.shepherd_pasture.shepherd_pasture_component')
   if pasture_monkey_see and pasture_monkey_do then
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching ShepherdPastureComponent to notify town')
      radiant.mixin(pasture_monkey_do, pasture_monkey_see)
   else
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server ***FAILED*** to monkey-patch ShepherdPastureComponent')
   end

   patches_applied = true
end

function luna_overhaul:_on_init()
   radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server initialized')
end

function luna_overhaul:_on_required_loaded()
   radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server required_loaded called')
   monkey_patching()
   radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching complete via ACE event')
end

-- Register event listeners (same pattern as ACE)
radiant.events.listen(luna_overhaul, 'radiant:init', luna_overhaul, luna_overhaul._on_init)
radiant.events.listen(radiant, 'stonehearth_ace:server:required_loaded', luna_overhaul, luna_overhaul._on_required_loaded)

return luna_overhaul
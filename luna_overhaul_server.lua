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
   local shepherd_monkey_see = require('monkey_patches.shepherd_class_patch')
   local shepherd_monkey_do = radiant.mods.require('stonehearth_ace.jobs.shepherd')
   if shepherd_monkey_see and shepherd_monkey_do then
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching AceShepherdClass')
      radiant.mixin(shepherd_monkey_do, shepherd_monkey_see)
   else
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server ***FAILED*** to monkey-patch AceShepherdClass')
   end

   patches_applied = true
end

function luna_overhaul:_on_init()
   radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server initialized')
end

function luna_overhaul:_on_required_loaded()
   radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server required_loaded called')
   
   -- Always set up the listener for the ACE event in case it hasn't fired yet
   radiant.events.listen_once(radiant, 'stonehearth_ace:server:required_loaded', function()
      radiant.log.write_('luna_overhaul', 0, 'ACE required_loaded event received, now applying Luna pet patches...')
      monkey_patching()
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching complete via ACE event')
   end)
   
   -- Check if ACE has already finished loading by trying to access ACE-specific functionality
   -- If stonehearth_ace table exists and has been initialized, ACE has already loaded
   local ace_loaded = false
   if stonehearth_ace and stonehearth_ace._sv then
      ace_loaded = true
   end
   
   if ace_loaded then
      radiant.log.write_('luna_overhaul', 0, 'ACE appears to have already loaded, applying Luna pet patches immediately...')
      monkey_patching()
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching complete (immediate)')
   else
      radiant.log.write_('luna_overhaul', 0, 'ACE not yet fully loaded, waiting for ACE required_loaded event...')
   end
end

-- Register event listeners (same pattern as ACE)
radiant.events.listen(luna_overhaul, 'radiant:init', luna_overhaul, luna_overhaul._on_init)
radiant.events.listen(radiant, 'radiant:required_loaded', luna_overhaul, luna_overhaul._on_required_loaded)

return luna_overhaul

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
   local shepherd_monkey_see = require('monkey_patches.ace_shepherd')
   local shepherd_monkey_do = radiant.mods.require('stonehearth.jobs.shepherd.shepherd')
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
   
   -- We will now ONLY apply patches when we receive the official event from ACE.
   -- This prevents the race condition and ensures all ACE modules are available.
   radiant.events.listen_once(radiant, 'stonehearth_ace:server:required_loaded', function()
      radiant.log.write_('luna_overhaul', 0, 'ACE required_loaded event received, now applying Luna patches...')
      monkey_patching()
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching complete via ACE event')
   end)
end

-- Register event listeners (same pattern as ACE)
radiant.events.listen(luna_overhaul, 'radiant:init', luna_overhaul, luna_overhaul._on_init)
radiant.events.listen(radiant, 'radiant:required_loaded', luna_overhaul, luna_overhaul._on_required_loaded)

return luna_overhaul

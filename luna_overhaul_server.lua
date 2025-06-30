local luna_overhaul = {}
local patches_applied = false

-- Monkey patching function
local function monkey_patching()
   if patches_applied then
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey patches already applied, skipping')
      return
   end
   
   local monkey_see = require('monkey_patches.pet_component_patch')
   local monkey_do = radiant.mods.require('stonehearth.components.pet.pet_component')
   if monkey_see and monkey_do then
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching pet_component to add pet_skill_component')
      radiant.mixin(monkey_do, monkey_see)
      patches_applied = true
   else
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server ***FAILED*** to monkey-patch pet_component')
   end
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

-- Register command event listeners
radiant.events.listen(radiant, 'luna_overhaul_choose_training_branch', function(args)
   local entity = args.entity
   if not entity then
      return
   end
   
   -- Just trigger the event on the entity - the pet_skill_component will handle it
   radiant.events.trigger(entity, 'luna_overhaul_choose_training_branch')
end)

return luna_overhaul

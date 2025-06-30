local luna_overhaul = {}

-- Wait for ACE to be loaded before we apply our monkey patches
local function monkey_patching()
   local monkey_see = require('monkey_patches.pet_component_patch')
   local monkey_do = radiant.mods.require('stonehearth.components.pet.pet_component')
   if monkey_see and monkey_do then
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching pet_component to add pet_skill_component')
      radiant.mixin(monkey_do, monkey_see)
   else
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server ***FAILED*** to monkey-patch pet_component')
   end
end

function luna_overhaul:_on_init()
   radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server initialized')
end

function luna_overhaul:_on_required_loaded()
   radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server required_loaded called')
   
   -- Wait for ACE to finish loading before applying our patches
   if radiant.events then
      radiant.events.listen_once(radiant, 'stonehearth_ace:server:required_loaded', function()
         radiant.log.write_('luna_overhaul', 0, 'ACE required_loaded event received, now applying Luna pet patches...')
         monkey_patching()
         radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching complete')
      end)
   else
      -- Fallback in case ACE isn't loaded
      radiant.log.write_('luna_overhaul', 0, 'ACE events not available, applying patches immediately')
      monkey_patching()
   end
end

-- Register event listeners
radiant.events.listen(luna_overhaul, 'radiant:init', luna_overhaul, luna_overhaul._on_init)
radiant.events.listen(radiant, 'radiant:required_loaded', luna_overhaul, luna_overhaul._on_required_loaded)

return luna_overhaul

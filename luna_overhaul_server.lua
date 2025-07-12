local luna_overhaul = {}
local patches_applied = false

local monkey_patches = {
   pet_component_patch = 'stonehearth.components.pet.pet_component',
   luna_shepherd = 'stonehearth.jobs.shepherd.shepherd',
   luna_town = 'stonehearth.services.server.town.town',
   luna_shepherd_pasture = 'stonehearth.components.shepherd_pasture.shepherd_pasture_component',
   luna_training_dummy = 'stonehearth_ace.ai.actions.training.train_find_best_training_dummy_trivial_action',
   luna_train_attack_adjacent = 'stonehearth_ace.ai.actions.training.train_attack_adjacent_action',
}

-- Monkey patching function
local function monkey_patching()
   if patches_applied then
      radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey patches already applied, skipping')
      return
   end
   
   --for each patch, require the monkey patch module and the target component
   for patch_name, target_component in pairs(monkey_patches) do
      local monkey_see = require('monkey_patches.' .. patch_name)
      local monkey_do = radiant.mods.require(target_component)
      if monkey_see and monkey_do then
         radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server monkey-patching ' .. patch_name)
         radiant.mixin(monkey_do, monkey_see)
      else
         radiant.log.write_('luna_overhaul', 0, 'Luna Overhaul server ***FAILED*** to monkey-patch ' .. patch_name)
      end
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
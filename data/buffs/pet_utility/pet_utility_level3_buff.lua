local log = radiant.log.create_logger('pet_buff_script')

local PetUtilityLevel3Buff = class()

-- Add logging to verify the script is loaded
log:info('Pet utility level 3 buff script loaded')

function PetUtilityLevel3Buff:on_buff_added(entity, buff)
   log:info('Pet utility level 3 buff script: on_buff_added called for entity %s', tostring(entity))
   
   -- Manually trigger the pet skill component to update owner buffs as a backup
   local pet_skill_component = entity:get_component('luna_overhaul:pet_skill')
   if pet_skill_component then
      log:info('Pet utility level 3 buff script: Found pet skill component, triggering buff update')
      pet_skill_component:_on_buff_added(buff:get_uri())
   else
      log:warning('Pet utility level 3 buff script: Pet skill component not found!')
   end
   
   log:info('Pet utility level 3 buff script: Pet skill component should already be present')
end

function PetUtilityLevel3Buff:on_buff_removed(entity, buff)
   log:info('Pet utility level 3 buff script: on_buff_removed called for entity %s', tostring(entity))
   -- The pet skill component will handle cleaning up modifiers when buffs are removed
end

return PetUtilityLevel3Buff

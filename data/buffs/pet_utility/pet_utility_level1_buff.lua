local log = radiant.log.create_logger('pet_buff_script')

local PetUtilityLevel1Buff = class()

-- Add logging to verify the script is loaded
log:info('Pet utility level 1 buff script loaded')

function PetUtilityLevel1Buff:on_buff_added(entity, buff)
   log:info('Pet utility buff script: on_buff_added called for entity %s', tostring(entity))
   
   -- The pet skill component should already exist via monkey patch
   local pet_skill_component = entity:get_component('luna_overhaul:pet_skill')
   if pet_skill_component then
      log:info('Pet utility buff script: Found pet skill component, triggering buff update')
      pet_skill_component:_on_buff_added(buff:get_uri())
   else
      log:error('Pet utility buff script: Pet skill component not found! This should not happen - check monkey patch.')
   end
end

function PetUtilityLevel1Buff:on_buff_removed(entity, buff)
   log:info('Pet utility buff script: on_buff_removed called for entity %s', tostring(entity))
   -- The pet skill component will handle cleaning up modifiers when buffs are removed
end

return PetUtilityLevel1Buff

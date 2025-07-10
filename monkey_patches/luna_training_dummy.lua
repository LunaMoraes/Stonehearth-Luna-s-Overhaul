-- This file monkey-patches the TRIVIAL training dummy action.
-- Its purpose is to validate that an already-assigned training target is still valid.
-- It now uses the same robust checking logic as the REGULAR search action and correctly handles failure to prevent AI loops.

local LunaFindBestTrainingDummy = class()
local log = radiant.log.create_logger('luna_overhaul')

-- Helper function to check if entity can train with target using roles
-- This logic MUST mirror the logic in the REGULAR action's override.
local function can_entity_train_with_target_roles(entity, target)
   local job_comp = entity:get_component('stonehearth:job')
   if not job_comp then return false end
   
   local job_uri = job_comp:get_job_uri()
   local job_level = job_comp:get_current_job_level()
   local training_dummy = target:get_component('stonehearth_ace:training_dummy')
   local log_prefix = 'Luna Training Dummy TRIVIAL'
   
   if not (training_dummy and training_dummy:get_enabled() and target:get_component('stonehearth:expendable_resources'):get_value('health') > 0) then
      log:info('%s: Target %s is invalid (damaged or disabled).', log_prefix, target)
      return false
   end
   

   -- Check 1: Base job URI
   local base_level = training_dummy:can_train_entity_level(job_uri)
   if base_level and base_level >= job_level then
      log:info('%s:  Check 1 PASSED. Target %s ACCEPTED for base job <%s>', log_prefix, target, job_uri)
      return true
   end
   
   -- If base job fails, check roles.
   local roles = job_comp:get_roles()
   if roles and next(roles) then
      for role_name, _ in pairs(roles) do
         
         -- Check 2: Composite URI
         local composite_uri = job_uri .. ':' .. role_name
         local composite_level = training_dummy:can_train_entity_level(composite_uri)
         if composite_level and composite_level >= job_level then
            log:info('%s:     Check 2 PASSED. Target %s ACCEPTED for composite role <%s>', log_prefix, target, composite_uri)
            return true
         end

         -- Check 3: Derived base job URI from role name
         local base_role_name = role_name:gsub('_job$', '')
         if base_role_name ~= role_name then
            local derived_job_uri = 'stonehearth:jobs:' .. base_role_name
            local derived_level = training_dummy:can_train_entity_level(derived_job_uri)
            if derived_level and derived_level >= job_level then
               log:info('%s:     Check 3 PASSED. Target %s ACCEPTED for derived job <%s> from role <%s>', log_prefix, target, derived_job_uri, role_name)
               return true
            end
         end
      end
   else
   end

   log:info('%s:  All checks failed. Target %s REJECTED for entity %s', log_prefix, target, entity)
   return false
end

-- Override the start_thinking method for the TRIVIAL action
function LunaFindBestTrainingDummy:start_thinking(ai, entity, args)
   local log_prefix = 'Luna Training Dummy TRIVIAL'
   log:info('%s: start_thinking called for entity %s', log_prefix, entity)
   
   local job_comp = entity:get_component('stonehearth:job')
   local target = job_comp:get_training_target()

   if target and target:is_valid() then
      -- An existing target was found. We MUST validate it.
      if can_entity_train_with_target_roles(entity, target) then
         -- The target is still valid, so we report success.
         log:info('%s: Existing target %s is still valid. SUCCESS.', log_prefix, target)
         ai:set_think_output({dummy = target})
      else
         -- The target is no longer valid. We do NOTHING.
         -- By not providing output, the action fails implicitly and allows the AI
         -- to run the lower-priority REGULAR search action.
         log:info('%s: Existing target %s is no longer valid. Failing implicitly to allow new search.', log_prefix, target)
      end
   end
   -- If no target is found, we do NOTHING. The action fails implicitly.
end

return LunaFindBestTrainingDummy

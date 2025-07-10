-- This file is an override for stonehearth_ace/ai/actions/training/train_find_best_training_dummy_action.lua
-- It replaces the original search logic with one that is compatible with role-based training.

-- We keep the structure almost identical to the original file to ensure compatibility.
local FindBestTrainingDummy = class()
local log = radiant.log.create_logger('luna_overhaul') -- Add our logger

-- These properties are required by the compound action factory and are identical to the original file.
FindBestTrainingDummy.name = 'train'
FindBestTrainingDummy.status_text_key = 'stonehearth_ace:ai.actions.status_text.train'
FindBestTrainingDummy.does = 'stonehearth_ace:find_training_dummy'
FindBestTrainingDummy.args = {}
FindBestTrainingDummy.priority = 0.5

-- This is the core of our change. We replace the original helper function with our own logic.
local function find_training_dummy(entity)
   local player_id = radiant.entities.get_work_player_id(entity)
   
   -- Get job info for logging purposes only
   local job_comp = entity:get_component('stonehearth:job')
   if not job_comp then
      log:error('Luna Training Dummy REGULAR (OVERRIDE): Entity %s has no job component!', entity)
      return stonehearth.ai:filter_from_key('stonehearth_ace:training_dummy:', '', function() return false end)
   end
   
   local job_uri = job_comp:get_job_uri()
   local job_level = job_comp:get_current_job_level()
   local log_prefix = 'Luna Training Dummy REGULAR (OVERRIDE)'
   
   
   -- Add debug info about the job component itself
   local job_info = job_comp:get_job_info()

   -- CRITICAL FIX: Store all the entity data we need AT THE TIME OF SEARCH, not in the filter
   local searching_entity_id = entity:get_id()
   local searching_job_uri = job_uri
   local searching_job_level = job_level
   local searching_roles = job_comp:get_roles()
   
      log_prefix, searching_entity_id, searching_job_uri, searching_job_level, 
      radiant.util.table_tostring(searching_roles))

   -- We use a generic key to get all dummies, then filter in Lua.
   return stonehearth.ai:filter_from_key('stonehearth_ace:training_dummy:', '',
      function(target)
         if player_id ~= target:get_player_id() then
            return false
         end

         local training_dummy = target:get_component('stonehearth_ace:training_dummy')
         if not (training_dummy and training_dummy:get_enabled() and target:get_component('stonehearth:expendable_resources'):get_value('health') > 0) then
            return false
         end
         
         -- Use the STORED data from the searching entity, not any current entity state
            log_prefix, target, searching_entity_id, searching_job_uri, searching_job_level)

         -- Check 1: Base job URI (the original ACE logic).
         local base_level = training_dummy:can_train_entity_level(searching_job_uri)
         if base_level and base_level >= searching_job_level then
            log:info('%s:  Check 1 PASSED. Target %s ACCEPTED for base job <%s>', log_prefix, target, searching_job_uri)
            return true
         end
         
         -- If base job fails, check roles using STORED roles data.
         if searching_roles and next(searching_roles) then
            log:info('%s:  Entity has roles, proceeding to check them.', log_prefix)
            for role_name, role_data in pairs(searching_roles) do
               
               -- Check 2: Composite URI (e.g., "stonehearth:jobs:cleric:combat")
               local composite_uri = searching_job_uri .. ':' .. role_name
               local composite_level = training_dummy:can_train_entity_level(composite_uri)
               if composite_level and composite_level >= searching_job_level then
                  log:info('%s:     Check 2 PASSED. Target %s ACCEPTED for composite role <%s>', log_prefix, target, composite_uri)
                  return true
               end
   
               -- Check 3: Derived base job URI from role name (e.g., "footman_job" -> "stonehearth:jobs:footman")
               local base_role_name = role_name:gsub('_job$', '')
               if base_role_name ~= role_name then
                  local derived_job_uri = 'stonehearth:jobs:' .. base_role_name
                  local derived_level = training_dummy:can_train_entity_level(derived_job_uri)
                  if derived_level and derived_level >= searching_job_level then
                     log:info('%s:     Check 3 PASSED. Target %s ACCEPTED for derived job <%s> from role <%s>', log_prefix, target, derived_job_uri, role_name)
                     return true
                  end
               end
            end
         else
         end

         log:info('%s:  All checks failed. Target %s REJECTED for SEARCHING entity %s', log_prefix, target, searching_entity_id)
         return false
      end)
end

-- This function remains identical to the original.
function FindBestTrainingDummy:start_thinking(ai, entity, args)
   ai:set_think_output({
      filter_fn = find_training_dummy(entity)
   })
end

-- This function is not used in the final action chain, but we keep it for fidelity.
local function _should_abort(source, training_enabled)
   return not training_enabled
end

-- This final block is now identical to the original file.
local ai = stonehearth.ai
return ai:create_compound_action(FindBestTrainingDummy)
      :execute('stonehearth:abort_on_event_triggered', {
         source = ai.ENTITY,
         event_name = 'stonehearth:work_order:build:work_player_id_changed',
      })
      :execute('stonehearth:find_best_reachable_entity_by_type', {
         filter_fn = ai.BACK(2).filter_fn,
         description = 'finding training dummy (luna overhaul)',
      })
      :set_think_output({
         dummy = ai.PREV.item
      })

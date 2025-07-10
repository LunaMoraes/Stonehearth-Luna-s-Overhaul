-- This file monkey-patches the ACE train_attack_adjacent_action.lua
-- to use the same role-based training logic as our search actions.

local LunaTrainAttackAdjacent = class()
local log = radiant.log.create_logger('luna_overhaul')

-- Helper function to check if entity can train with target using roles
-- This logic MUST mirror the logic in the search actions.
local function can_entity_train_with_target_roles(entity, target)
   local job_comp = entity:get_component('stonehearth:job')
   if not job_comp then return false end
   
   local job_uri = job_comp:get_job_uri()
   local job_level = job_comp:get_current_job_level()
   local training_dummy = target:get_component('stonehearth_ace:training_dummy')
   local log_prefix = 'Luna Training Attack Adjacent'
   
   if not training_dummy then return false end
   
   -- Check 1: Base job URI
   local base_level = training_dummy:can_train_entity_level(job_uri)
   if base_level and base_level >= job_level then
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
            return true
         end
         -- Check 3: Derived base job URI from role name
         local base_role_name = role_name:gsub('_job$', '')
         if base_role_name ~= role_name then
            local derived_job_uri = 'stonehearth:jobs:' .. base_role_name
            local derived_level = training_dummy:can_train_entity_level(derived_job_uri)
            if derived_level and derived_level >= job_level then
               return true
            end
         end
      end
   else
   end

   return false
end

-- Override the _check_conditions method to use role-based logic
function LunaTrainAttackAdjacent:_check_conditions(ai, entity, args)
   -- make sure the target is a training dummy
   local dummy = args.target and args.target:is_valid() and args.target:get_component('stonehearth_ace:training_dummy')
   if not dummy or not dummy:get_enabled() then
      return 'target is not a valid/enabled training dummy'
   end

   local health = args.target:get_component('stonehearth:expendable_resources'):get_value('health')
   if not health or health <= 0 then
      return 'training dummy target is already dead'
   end

   local job = entity:get_component('stonehearth:job')
   if not job:is_trainable() then
      return 'entity cannot train'
   end

   if not job:get_training_enabled() then
      return 'training is disabled or unavailable for this entity'
   end

   -- LUNA CHANGE: Use role-based training logic instead of just base job URI
   if not can_entity_train_with_target_roles(entity, args.target) then
      return 'this dummy can\'t train this entity (role-based check failed)'
   end

   local weapon = stonehearth.combat:get_main_weapon(entity)
   local weapon_data = weapon and radiant.entities.get_entity_data(weapon, 'stonehearth:combat:weapon_data')
   if not weapon_data then
      return 'entity has no weapon equipped'
   end

   return nil
end

return LunaTrainAttackAdjacent

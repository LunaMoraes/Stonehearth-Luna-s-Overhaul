local log = radiant.log.create_logger('pet_skill')

local PetSkillComponent = class()

function PetSkillComponent:activate()
   log:info('Pet skill component activated for entity: %s', tostring(self._entity))
   
   -- Initialize saved variables properly
   if not self._sv.current_owner then
      self._sv.current_owner = nil
   end
   
   -- Initialize pet skill/level system (mimicking job component)
   if not self._sv.current_branch then
      self._sv.current_branch = nil  -- No branch initially
   end
   if not self._sv.current_level then
      self._sv.current_level = 1  -- Always start at level 1
   end
   if not self._sv.current_exp then
      self._sv.current_exp = 0  -- Current experience points
   end
   if not self._sv.exp_to_next_level then
      self._sv.exp_to_next_level = self:_calculate_exp_to_next_level()
   end
   
   -- Listen for when this pet gets a new owner
   self._adoption_listener = radiant.events.listen(self._entity, 'stonehearth:pets:adopted', function(args)
      self:_on_owner_changed(args.owner)
   end)
   
   -- Listen for when buffs are added/removed from this pet
   self._buff_added_listener = radiant.events.listen(self._entity, 'stonehearth:buff_added', function(args)
      self:_on_buff_added(args.buff_uri)
   end)
   
   self._buff_removed_listener = radiant.events.listen(self._entity, 'stonehearth:buff_removed', function(args)
      self:_on_buff_removed(args.buff_uri)
   end)
   
   log:info('Pet skill component: Event listeners set up')
   
   -- Check for existing skill buffs and current owner on activation
   log:info('Checking for existing buffs and owner on activation')
   self:_update_owner_buffs()
end

function PetSkillComponent:destroy()
   self:_remove_all_owner_buffs()
   
   if self._adoption_listener then
      self._adoption_listener:destroy()
      self._adoption_listener = nil
   end
   
   if self._buff_added_listener then
      self._buff_added_listener:destroy()
      self._buff_added_listener = nil
   end
   
   if self._buff_removed_listener then
      self._buff_removed_listener:destroy()
      self._buff_removed_listener = nil
   end
end

function PetSkillComponent:_on_owner_changed(new_owner)
   -- Get the old owner before updating
   local old_owner = self._sv.current_owner
   
   -- Remove buffs from the old owner specifically
   if old_owner and old_owner:is_valid() then
      log:info('Removing buffs from old owner: %s', tostring(old_owner))
      self:_remove_owner_buffs_from_entity(old_owner)
   else
      log:info('No valid old owner to remove buffs from')
   end
   
   -- Update current owner and apply buffs if we have skill buffs
   self._sv.current_owner = new_owner
   self.__saved_variables:mark_changed()
   
   log:info('Pet owner changed to: %s', new_owner and tostring(new_owner) or 'nil')
   
   if new_owner then
      self:_update_owner_buffs()
   end
end

function PetSkillComponent:_on_buff_added(buff_uri)
   log:info('Pet buff added: %s', tostring(buff_uri or 'nil'))
   if self:_is_skill_buff(buff_uri) then
      log:info('Skill buff detected: %s', buff_uri)
      
      local buff_branch = self:_get_buff_branch(buff_uri)
      local buff_level = self:_get_buff_level(buff_uri)
      
      if buff_branch and buff_level then
         -- Check if this is a manual level application (from our leveling system)
         local expected_buff = self:_get_level_buff_uri(self._sv.current_branch, self._sv.current_level)
         if buff_uri == expected_buff then
            log:info('Skill buff matches current branch/level, updating owner buffs')
            self:_update_owner_buffs(buff_uri)
         else
            -- This is an external buff addition - could be initial branch setting
            log:info('External skill buff detected, checking if we need to set/change branch')
            if not self._sv.current_branch or self._sv.current_branch ~= buff_branch then
               log:info('Setting pet branch to %s and level to %d', buff_branch, buff_level)
               -- Set branch and level based on the buff
               self._sv.current_branch = buff_branch
               self._sv.current_level = buff_level
               self._sv.current_exp = 0  -- Reset exp when manually setting level
               self._sv.exp_to_next_level = self:_calculate_exp_to_next_level()
               self.__saved_variables:mark_changed()
            end
            
            -- Remove other level buffs from the same branch and update owner buffs
            self:_remove_other_skill_buffs(buff_uri)
            self:_update_owner_buffs(buff_uri)
         end
      end
   end
end

function PetSkillComponent:_on_buff_removed(buff_uri)
   log:info('Pet buff removed: %s', tostring(buff_uri or 'nil'))
   if self:_is_skill_buff(buff_uri) then
      log:info('Skill buff removed, updating owner buffs')
      -- For removal, we need to remove the specific owner buff immediately
      self:_remove_specific_owner_buff(buff_uri)
   end
end

function PetSkillComponent:_is_skill_buff(buff_uri)
   -- Define which buffs provide owner benefits (organized by branch)
   local skill_buffs = {
      -- Utility branch
      ['luna_overhaul:buffs:pet_utility_level1'] = 'utility',
      ['luna_overhaul:buffs:pet_utility_level2'] = 'utility',
      ['luna_overhaul:buffs:pet_utility_level3'] = 'utility',
      -- Add more branches here as needed
      -- ['luna_overhaul:buffs:pet_combat_level1'] = 'combat',
      -- ['luna_overhaul:buffs:pet_combat_level2'] = 'combat',
      -- ['luna_overhaul:buffs:pet_combat_level3'] = 'combat',
   }
   
   return skill_buffs[buff_uri] ~= nil
end

function PetSkillComponent:_get_buff_branch(buff_uri)
   -- Get the branch name for a skill buff
   local skill_buffs = {
      ['luna_overhaul:buffs:pet_utility_level1'] = 'utility',
      ['luna_overhaul:buffs:pet_utility_level2'] = 'utility',
      ['luna_overhaul:buffs:pet_utility_level3'] = 'utility',
      -- Add more branches here
   }
   
   return skill_buffs[buff_uri]
end

function PetSkillComponent:_get_buff_level(buff_uri)
   -- Extract level from buff URI
   local level_mapping = {
      ['luna_overhaul:buffs:pet_utility_level1'] = 1,
      ['luna_overhaul:buffs:pet_utility_level2'] = 2,
      ['luna_overhaul:buffs:pet_utility_level3'] = 3,
      -- Add more mappings here
   }
   
   return level_mapping[buff_uri]
end

function PetSkillComponent:_get_owner_buff_for_skill(buff_uri)
   -- Map pet skill buffs to their corresponding owner buffs
   local owner_buffs = {
      ['luna_overhaul:buffs:pet_utility_level1'] = 'luna_overhaul:buffs:pet_utility_owner_level1',
      ['luna_overhaul:buffs:pet_utility_level2'] = 'luna_overhaul:buffs:pet_utility_owner_level2',
      ['luna_overhaul:buffs:pet_utility_level3'] = 'luna_overhaul:buffs:pet_utility_owner_level3',
      -- Add more mappings here as needed
   }
   
   return owner_buffs[buff_uri]
end

function PetSkillComponent:_update_owner_buffs(specific_buff_uri)
   -- Get the current owner
   local owner = self:_get_current_owner()
   if not owner or not owner:is_valid() then
      log:info('No valid owner found, skipping buff update')
      return
   end
   
   log:info('Updating buffs for owner: %s', tostring(owner))
   
   -- Check what skill buffs this pet has and apply corresponding owner buffs
   local buffs_component = self._entity:get_component('stonehearth:buffs')
   if not buffs_component then
      log:warning('Pet has no buffs component')
      return
   end
   
   local owner_buffs_component = owner:get_component('stonehearth:buffs')
   if not owner_buffs_component then
      log:warning('Owner has no buffs component')
      return
   end
   
   local applied_any_buff = false
   
   -- If we have a specific buff URI (from buff_added event), try to apply it directly first
   if specific_buff_uri and self:_is_skill_buff(specific_buff_uri) then
      local owner_buff_uri = self:_get_owner_buff_for_skill(specific_buff_uri)
      if owner_buff_uri then
         log:info('Applying specific owner buff: %s (from event: %s)', owner_buff_uri, specific_buff_uri)
         owner_buffs_component:add_buff(owner_buff_uri)
         applied_any_buff = true
      end
   end
   
   -- Also check all existing buffs (in case the event-based approach missed something)
   for buff_uri, buff_data in pairs(buffs_component:get_buffs()) do
      log:debug('Checking pet buff: %s', buff_uri)
      if self:_is_skill_buff(buff_uri) then
         local owner_buff_uri = self:_get_owner_buff_for_skill(buff_uri)
         if owner_buff_uri and not owner_buffs_component:has_buff(owner_buff_uri) then
            log:info('Applying owner buff: %s', owner_buff_uri)
            owner_buffs_component:add_buff(owner_buff_uri)
            applied_any_buff = true
         end
      end
   end
   
   if not applied_any_buff then
      log:info('No new skill buffs found on pet, no owner buffs applied')
   end
end

function PetSkillComponent:_remove_all_owner_buffs()
   local owner = self:_get_current_owner()
   if owner and owner:is_valid() then
      self:_remove_owner_buffs_from_entity(owner)
   else
      log:debug('No valid current owner to remove buffs from')
   end
end

function PetSkillComponent:_remove_owner_buffs_from_entity(owner_entity)
   if not owner_entity or not owner_entity:is_valid() then
      log:debug('No valid owner entity to remove buffs from')
      return
   end
   
   local owner_buffs_component = owner_entity:get_component('stonehearth:buffs')
   if not owner_buffs_component then
      log:debug('Owner entity has no buffs component for removal')
      return
   end
   
   -- Only remove owner buffs that correspond to this specific pet's skill buffs
   local buffs_component = self._entity:get_component('stonehearth:buffs')
   if not buffs_component then
      log:debug('Pet has no buffs component, nothing to remove from owner')
      return
   end
   
   -- Check what skill buffs this pet has and remove only the corresponding owner buffs
   -- BUT first check if other pets owned by the same person still provide the same benefit
   for buff_uri, buff_data in pairs(buffs_component:get_buffs()) do
      if self:_is_skill_buff(buff_uri) then
         local owner_buff_uri = self:_get_owner_buff_for_skill(buff_uri)
         if owner_buff_uri and owner_buffs_component:has_buff(owner_buff_uri) then
            -- Check if any other pets owned by this person still have the same skill buff
            if not self:_owner_has_other_pets_with_skill(owner_entity, buff_uri) then
               log:info('Removing owner buff: %s from entity: %s (from pet skill: %s, no other pets provide this)', 
                        owner_buff_uri, tostring(owner_entity), buff_uri)
               owner_buffs_component:remove_buff(owner_buff_uri)
            else
               log:info('Keeping owner buff: %s on entity: %s (other pets still provide skill: %s)', 
                        owner_buff_uri, tostring(owner_entity), buff_uri)
            end
         end
      end
   end
end

function PetSkillComponent:_owner_has_other_pets_with_skill(owner_entity, skill_buff_uri)
   if not owner_entity or not owner_entity:is_valid() then
      return false
   end
   
   -- Get all pets owned by this entity
   local pet_component = owner_entity:get_component('stonehearth:pet_owner')
   if not pet_component then
      log:debug('Owner has no pet_owner component')
      return false
   end
   
   local owned_pets = pet_component:get_pets()
   if not owned_pets then
      log:debug('Owner has no pets')
      return false
   end
   
   -- Check each pet (except this one) to see if they have the same skill buff
   for pet_id, pet_entity in pairs(owned_pets) do
      if pet_entity and pet_entity:is_valid() and pet_entity ~= self._entity then
         local pet_buffs_component = pet_entity:get_component('stonehearth:buffs')
         if pet_buffs_component and pet_buffs_component:has_buff(skill_buff_uri) then
            -- Found another pet with the same skill buff
            log:debug('Found other pet %s with skill buff %s', tostring(pet_entity), skill_buff_uri)
            return true
         end
      end
   end
   
   return false
end

function PetSkillComponent:_get_current_owner()
   -- Try to get owner from saved variables first
   if self._sv.current_owner and self._sv.current_owner:is_valid() then
      return self._sv.current_owner
   end
   
   -- Fall back to getting owner from pet component
   local pet_component = self._entity:get_component('stonehearth:pet')
   if pet_component then
      local owner = pet_component:get_owner()
      if owner and owner:is_valid() then
         self._sv.current_owner = owner
         self.__saved_variables:mark_changed()
         return owner
      end
   end
   
   return nil
end

function PetSkillComponent:_remove_specific_owner_buff(buff_uri)
   local owner = self:_get_current_owner()
   if not owner or not owner:is_valid() then
      log:debug('No valid owner found for specific buff removal')
      return
   end
   
   local owner_buffs_component = owner:get_component('stonehearth:buffs')
   if not owner_buffs_component then
      log:debug('Owner has no buffs component for specific removal')
      return
   end
   
   if self:_is_skill_buff(buff_uri) then
      local owner_buff_uri = self:_get_owner_buff_for_skill(buff_uri)
      if owner_buff_uri then
         -- Check if any other pets owned by this person still have the same skill buff
         if not self:_owner_has_other_pets_with_skill(owner, buff_uri) then
            if owner_buffs_component:has_buff(owner_buff_uri) then
               log:info('Removing specific owner buff: %s (from pet skill: %s)', owner_buff_uri, buff_uri)
               owner_buffs_component:remove_buff(owner_buff_uri)
            end
         else
            log:info('Keeping owner buff: %s (other pets still provide skill: %s)', owner_buff_uri, buff_uri)
         end
      end
   end
end

function PetSkillComponent:_remove_other_skill_buffs(new_buff_uri)
   -- When a pet gets a new skill buff, remove all other skill buffs
   -- This handles leveling up and branch changes
   local buffs_component = self._entity:get_component('stonehearth:buffs')
   if not buffs_component then
      log:debug('Pet has no buffs component for skill buff cleanup')
      return
   end
   
   local buffs_to_remove = {}
   
   -- Collect all skill buffs that are not the new one
   for buff_uri, buff_data in pairs(buffs_component:get_buffs()) do
      if self:_is_skill_buff(buff_uri) and buff_uri ~= new_buff_uri then
         table.insert(buffs_to_remove, buff_uri)
      end
   end
   
   -- Remove the old skill buffs (this will automatically trigger _on_buff_removed for each)
   for _, buff_uri in ipairs(buffs_to_remove) do
      log:info('Removing old skill buff: %s (replaced by: %s)', buff_uri, new_buff_uri)
      buffs_component:remove_buff(buff_uri)
      -- Owner buff cleanup will happen automatically via _on_buff_removed event
   end
end

-- ================== PET SKILL LEVELING SYSTEM ==================
-- Mimicking the job component's experience system

function PetSkillComponent:get_current_level()
   return self._sv.current_level or 1
end

function PetSkillComponent:get_current_exp()
   return self._sv.current_exp or 0
end

function PetSkillComponent:get_exp_to_next_level()
   return self._sv.exp_to_next_level or 0
end

function PetSkillComponent:get_current_branch()
   return self._sv.current_branch
end

function PetSkillComponent:can_level_up()
   return self._sv.current_level and self._sv.current_level < 3  -- Max level 3
end

-- Calculate experience needed for next level (mimicking job component)
function PetSkillComponent:_calculate_exp_to_next_level()
   local curr_level = self._sv.current_level or 1
   -- Use a similar equation to humans but smaller scale for pets
   -- Human equation: curr_level * 125 + 135
   -- Pet equation: curr_level * 50 + 50 (easier to level)
   local exp_required = curr_level * 50 + 50
   return exp_required
end

-- Add experience to the pet (mimicking job component's add_exp)
function PetSkillComponent:add_exp(value)
   if not self:can_level_up() then
      log:info('Pet %s is already at max level (%d)', tostring(self._entity), self._sv.current_level)
      return
   end
   
   if not self._sv.current_branch then
      log:warning('Pet %s has no branch set, cannot gain experience', tostring(self._entity))
      return
   end
   
   log:info('Adding %d experience to pet %s (current: %d/%d, level %d)', 
            value, tostring(self._entity), self._sv.current_exp, self._sv.exp_to_next_level, self._sv.current_level)
   
   self._sv.current_exp = self._sv.current_exp + value
   
   -- Check for level ups (can level multiple times with large exp gains)
   while self._sv.current_exp >= self._sv.exp_to_next_level and self:can_level_up() do
      self._sv.current_exp = self._sv.current_exp - self._sv.exp_to_next_level
      self:_level_up()
   end
   
   self.__saved_variables:mark_changed()
end

-- Level up the pet (mimicking job component's level_up)
function PetSkillComponent:_level_up()
   local old_level = self._sv.current_level
   self._sv.current_level = self._sv.current_level + 1
   self._sv.exp_to_next_level = self:_calculate_exp_to_next_level()
   
   log:info('Pet %s leveled up! %d -> %d (branch: %s)', 
            tostring(self._entity), old_level, self._sv.current_level, self._sv.current_branch or 'none')
   
   -- Apply the new level buff
   self:_apply_level_buff()
   
   -- TODO: Add level up announcement/effects similar to humans
   self.__saved_variables:mark_changed()
end

-- Set or change the pet's skill branch
function PetSkillComponent:set_branch(branch_name)
   local old_branch = self._sv.current_branch
   
   if old_branch == branch_name then
      log:info('Pet %s is already in branch %s', tostring(self._entity), branch_name)
      return
   end
   
   log:info('Pet %s changing branch from %s to %s', 
            tostring(self._entity), old_branch or 'none', branch_name)
   
   -- Remove old branch buff if switching branches
   if old_branch and old_branch ~= branch_name then
      -- Remove only the specific buff this pet had in the old branch
      local old_buff_uri = self:_get_level_buff_uri(old_branch, self._sv.current_level)
      if old_buff_uri then
         local owner = self:_get_current_owner()
         if owner and owner:is_valid() then
            -- Only remove the buff if no other pet provides it
            if not self:_owner_has_other_pets_with_skill(owner, old_buff_uri) then
               local buffs_component = self._entity:get_component('stonehearth:buffs')
               if buffs_component and buffs_component:has_buff(old_buff_uri) then
                  log:info('Removing old branch buff: %s (no other pets provide this)', old_buff_uri)
                  buffs_component:remove_buff(old_buff_uri)
               end
            else
               log:info('Keeping old branch buff: %s (other pets still provide this)', old_buff_uri)
            end
         end
      end
      -- Reset to level 1 when changing branches
      self._sv.current_level = 1
      self._sv.current_exp = 0
      log:info('Pet level reset to 1 due to branch change')
   end
   
   -- Set new branch
   self._sv.current_branch = branch_name
   self._sv.exp_to_next_level = self:_calculate_exp_to_next_level()
   
   -- Apply new branch buff
   self:_apply_level_buff()
   
   self.__saved_variables:mark_changed()
end

-- Apply the current level buff based on branch and level
function PetSkillComponent:_apply_level_buff()
   if not self._sv.current_branch then
      log:warning('Cannot apply level buff: no branch set')
      return
   end
   
   local buff_uri = self:_get_level_buff_uri(self._sv.current_branch, self._sv.current_level)
   if not buff_uri then
      log:warning('No buff found for branch %s level %d', self._sv.current_branch, self._sv.current_level)
      return
   end
   
   local buffs_component = self._entity:get_component('stonehearth:buffs')
   if buffs_component then
      -- Remove old skill buffs from this pet (but use the smart removal that checks other pets)
      self:_remove_other_skill_buffs(buff_uri)
      
      log:info('Applying level buff: %s (branch: %s, level: %d)', 
               buff_uri, self._sv.current_branch, self._sv.current_level)
      buffs_component:add_buff(buff_uri)
   end
end

-- Remove the current level buff
function PetSkillComponent:_remove_current_level_buff()
   if not self._sv.current_branch then
      return
   end
   
   local buff_uri = self:_get_level_buff_uri(self._sv.current_branch, self._sv.current_level)
   if not buff_uri then
      return
   end
   
   local buffs_component = self._entity:get_component('stonehearth:buffs')
   if buffs_component and buffs_component:has_buff(buff_uri) then
      log:info('Removing level buff: %s', buff_uri)
      buffs_component:remove_buff(buff_uri)
   end
end

-- Get the buff URI for a specific branch and level
function PetSkillComponent:_get_level_buff_uri(branch, level)
   local buff_mapping = {
      ['utility'] = {
         [1] = 'luna_overhaul:buffs:pet_utility_level1',
         [2] = 'luna_overhaul:buffs:pet_utility_level2',
         [3] = 'luna_overhaul:buffs:pet_utility_level3',
      },
      -- Add more branches here as needed
      -- ['combat'] = {
      --    [1] = 'luna_overhaul:buffs:pet_combat_level1',
      --    [2] = 'luna_overhaul:buffs:pet_combat_level2',
      --    [3] = 'luna_overhaul:buffs:pet_combat_level3',
      -- },
   }
   
   return buff_mapping[branch] and buff_mapping[branch][level]
end

-- ================== END PET SKILL LEVELING SYSTEM ==================

-- ================== PUBLIC FUNCTIONS FOR PET LEVELING ==================

-- Public function to give experience to a pet
function PetSkillComponent:give_experience(amount)
   if not amount or amount <= 0 then
      log:warning('Invalid experience amount: %s', tostring(amount))
      return false
   end
   
   self:add_exp(amount)
   return true
end

-- Public function to set a pet's branch (for initial training or branch changes)
function PetSkillComponent:train_branch(branch_name)
   if not branch_name or branch_name == '' then
      log:warning('Invalid branch name: %s', tostring(branch_name))
      return false
   end
   
   -- Check if branch exists in our mapping
   local test_buff = self:_get_level_buff_uri(branch_name, 1)
   if not test_buff then
      log:warning('Unknown branch: %s', branch_name)
      return false
   end
   
   self:set_branch(branch_name)
   return true
end

-- Public function to get pet's current status
function PetSkillComponent:get_pet_status()
   return {
      branch = self._sv.current_branch,
      level = self._sv.current_level,
      experience = self._sv.current_exp,
      exp_to_next = self._sv.exp_to_next_level,
      can_level_up = self:can_level_up()
   }
end

-- Public function to reset pet (for debugging/admin)
function PetSkillComponent:reset_pet()
   log:info('Resetting pet %s', tostring(self._entity))
   
   -- Remove current buffs
   self:_remove_current_level_buff()
   
   -- Reset all data
   self._sv.current_branch = nil
   self._sv.current_level = 1
   self._sv.current_exp = 0
   self._sv.exp_to_next_level = self:_calculate_exp_to_next_level()
   
   self.__saved_variables:mark_changed()
   return true
end

-- ================== END PUBLIC FUNCTIONS ==================

return PetSkillComponent

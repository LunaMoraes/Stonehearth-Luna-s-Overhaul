local log = radiant.log.create_logger('pet_skill')

local PetSkillComponent = class()

--[[
   NEW SKILL BRANCH CONFIGURATION:
   To add a new skill branch, simply add its name to the 'branches' list below.
   The SKILL_DATA table will be generated automatically based on this list
   and the naming convention of your buff files.
--]]
local BRANCH_CONFIG = {
   branches = { 'utility', 'combat', 'therapist' },
   max_level = 3
}

-- This table is now built dynamically.
local SKILL_DATA = {}

-- This function builds the SKILL_DATA table programmatically.
-- It runs once when the script is first loaded.
local function _build_skill_data()
   -- Ensure this only runs once.
   if next(SKILL_DATA) then return end

   log:info('Building SKILL_DATA table dynamically...')
   for _, branch_name in ipairs(BRANCH_CONFIG.branches) do
      for level = 1, BRANCH_CONFIG.max_level do
         -- This assumes your buff files follow the pattern:
         -- pet buff: "luna_overhaul:buffs:pet_<branch_name>_level<level>"
         -- owner buff: "luna_overhaul:buffs:pet_<branch_name>_owner_level<level>"
         local pet_buff_uri = string.format('luna_overhaul:buffs:pet_%s_level%d', branch_name, level)
         local owner_buff_uri = string.format('luna_overhaul:buffs:pet_%s_owner_level%d', branch_name, level)

         SKILL_DATA[pet_buff_uri] = {
            branch = branch_name,
            level = level,
            owner_buff = owner_buff_uri
         }
      end
   end
   log:info('SKILL_DATA table built successfully.')
end

_build_skill_data()


-- ================== COMPONENT LIFECYCLE ==================
-- This component manages pet skills, including buffs, experience, and leveling.
-- =========================================================

function PetSkillComponent:activate()
   log:info('Pet skill component activated for entity: %s', tostring(self._entity))
   
   -- Initialize saved variables. Using 'or' is a concise way to set defaults.
   self._sv.current_owner = self._sv.current_owner or nil
   self._sv.current_branch = self._sv.current_branch or nil
   self._sv.current_level = self._sv.current_level or 1
   self._sv.current_exp = self._sv.current_exp or 0
   self._sv.exp_to_next_level = self._sv.exp_to_next_level or self:_calculate_exp_to_next_level()
   
   -- Set up event listeners
   self._adoption_listener = radiant.events.listen(self._entity, 'stonehearth:pets:adopted', function(args)
      self:_on_owner_changed(args.owner)
   end)
   self._buff_added_listener = radiant.events.listen(self._entity, 'stonehearth:buff_added', function(args)
      self:_on_buff_added(args.buff_uri)
   end)
   self._buff_removed_listener = radiant.events.listen(self._entity, 'stonehearth:buff_removed', function(args)
      self:_on_buff_removed(args.buff_uri)
   end)
   self._eat_food_listener = radiant.events.listen(self._entity, 'stonehearth:eat_food', self, self._on_pet_ate_food)
   
   log:info('Pet skill component: Event listeners set up')
   
   -- Sync buffs on activation
   self:_sync_owner_buffs()
end

function PetSkillComponent:destroy()
   -- When this component is destroyed, its buffs are removed from the pet,
   -- which fires the 'stonehearth:buff_removed' event.
   -- That event triggers _sync_owner_buffs, correctly updating the owner.
   -- We just need to clean up our listeners here.
   if self._adoption_listener then self._adoption_listener:destroy() end
   if self._buff_added_listener then self._buff_added_listener:destroy() end
   if self._buff_removed_listener then self._buff_removed_listener:destroy() end
   if self._eat_food_listener then self._eat_food_listener:destroy() end
end

-- ================== EVENT HANDLERS ==================

function PetSkillComponent:_on_owner_changed(new_owner)
   -- When owner changes, the old owner needs to be updated.
   -- The sync function will handle this if called on the old owner.
   local old_owner = self._sv.current_owner
   
   self._sv.current_owner = new_owner
   self.__saved_variables:mark_changed()
   log:info('Pet owner changed to: %s', new_owner and tostring(new_owner) or 'nil')

   -- Sync buffs for the old owner (if they existed)
   if old_owner and old_owner:is_valid() then
      self:_sync_owner_buffs(old_owner)
   end
   -- Sync buffs for the new owner
   if new_owner and new_owner:is_valid() then
      self:_sync_owner_buffs(new_owner)
   end
end

function PetSkillComponent:_on_buff_added(buff_uri)
   log:info('Pet buff added event fired with URI: %s', tostring(buff_uri or 'nil'))
   -- Any time a buff is added to a pet, we run a sync.
   -- This is the most reliable way to handle buff changes, especially since
   -- the buff_uri from the event can sometimes be nil. The _sync_owner_buffs function
   -- is smart enough to determine the correct state by checking all of the pet's current buffs.
   self:_sync_owner_buffs()
end

function PetSkillComponent:_on_buff_removed(buff_uri)
   log:info('Pet buff removed event fired with URI: %s', tostring(buff_uri or 'nil'))
   -- Any time a skill buff is removed, run a full sync.
   -- This is more reliable than trying to figure out which buff was removed,
   -- especially if the event payload is nil.
   self:_sync_owner_buffs()
end

function PetSkillComponent:_on_pet_ate_food(eat_event_data)
   local FOOD_EAT_XP = 15
   
   if not self._sv.current_branch then
      log:info('Pet %s has no branch yet, no XP awarded for eating', tostring(self._entity))
      return
   end
   
   local owner = self:_get_current_owner()
   if not owner or not owner:is_valid() then
      log:info('Pet %s has no valid owner, no XP awarded for eating', tostring(self._entity))
      return
   end
   
   log:info('Entity %s ate food: %s, awarding %d XP', tostring(self._entity), eat_event_data.food_name or 'unknown food', FOOD_EAT_XP)
   self:give_experience(FOOD_EAT_XP)
end

-- ================== BUFF MANAGEMENT (REFACTORED) ==================

function PetSkillComponent:_sync_owner_buffs(optional_owner)
   -- This function is the single source of truth for managing owner buffs.
   -- It checks all pets for a given owner and ensures the owner has the correct set of buffs.
   local owner = optional_owner or self:_get_current_owner()
   if not owner or not owner:is_valid() then
      log:debug('No valid owner found, skipping buff sync.')
      return
   end

   log:info('Syncing buffs for owner: %s', tostring(owner))
   local owner_buffs_component = owner:get_component('stonehearth:buffs')
   if not owner_buffs_component then
      log:warning('Owner is missing buffs component.')
      return
   end

   -- 1. Build a set of all owner buffs that SHOULD be active based on ALL of the owner's pets.
   local required_owner_buffs = {}
   local pet_owner_component = owner:get_component('stonehearth:pet_owner')
   if pet_owner_component then
      local all_pets = pet_owner_component:get_pets()
      for _, pet_entity in pairs(all_pets) do
         if pet_entity and pet_entity:is_valid() then
            local pet_buffs_comp = pet_entity:get_component('stonehearth:buffs')
            if pet_buffs_comp then
               for pet_buff_uri, _ in pairs(pet_buffs_comp:get_buffs()) do
                  local skill_info = SKILL_DATA[pet_buff_uri]
                  if skill_info and skill_info.owner_buff then
                     required_owner_buffs[skill_info.owner_buff] = true -- Use as a set for quick lookup
                  end
               end
            end
         end
      end
   end

   -- 2. Build a list of all skill-related owner buffs that are CURRENTLY on the owner.
   local current_skill_owner_buffs = {}
   for _, skill_info in pairs(SKILL_DATA) do
      if skill_info.owner_buff and owner_buffs_component:has_buff(skill_info.owner_buff) then
         table.insert(current_skill_owner_buffs, skill_info.owner_buff)
      end
   end

   -- 3. Remove any current buffs that are NOT in the required set.
   for _, owner_buff_uri in ipairs(current_skill_owner_buffs) do
      if not required_owner_buffs[owner_buff_uri] then
         log:info('Sync: Removing stale owner buff: %s', owner_buff_uri)
         owner_buffs_component:remove_buff(owner_buff_uri)
      end
   end
   
   -- 4. Add any required buffs that the owner doesn't already have.
   for owner_buff_uri, _ in pairs(required_owner_buffs) do
      if not owner_buffs_component:has_buff(owner_buff_uri) then
         log:info('Sync: Applying required owner buff: %s', owner_buff_uri)
         owner_buffs_component:add_buff(owner_buff_uri)
      end
   end
end

function PetSkillComponent:_get_current_owner()
   if self._sv.current_owner and self._sv.current_owner:is_valid() then
      return self._sv.current_owner
   end
   
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

-- ================== PET SKILL LEVELING SYSTEM ==================

function PetSkillComponent:_calculate_exp_to_next_level()
   local curr_level = self._sv.current_level or 1
   -- Pet equation: curr_level * 50 + 50 (easier to level than humans)
   return curr_level * 50 + 50
end

function PetSkillComponent:_level_up()
   local old_level = self._sv.current_level
   self._sv.current_level = self._sv.current_level + 1
   self._sv.exp_to_next_level = self:_calculate_exp_to_next_level()
   
   log:info('Pet %s leveled up! %d -> %d (branch: %s)', 
            tostring(self._entity), old_level, self._sv.current_level, self._sv.current_branch or 'none')
   
   self:_apply_level_buff()
   
   -- TODO: Add level up announcement/effects
   self.__saved_variables:mark_changed()
end

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
      -- Remove other skill buffs from this pet. The subsequent buff removal event
      -- will trigger a sync for the owner.
      local buffs_to_remove = {}
      for existing_buff_uri, _ in pairs(buffs_component:get_buffs()) do
         if SKILL_DATA[existing_buff_uri] and existing_buff_uri ~= buff_uri then
            table.insert(buffs_to_remove, existing_buff_uri)
         end
      end
      for _, buff_to_remove in ipairs(buffs_to_remove) do
         log:info('Removing old skill buff: %s (replaced by: %s)', buff_to_remove, buff_uri)
         buffs_component:remove_buff(buff_to_remove)
      end
      
      -- Add the new skill buff to the pet. The subsequent buff added event
      -- will trigger a sync for the owner.
      log:info('Applying level buff to pet: %s (branch: %s, level: %d)', 
               buff_uri, self._sv.current_branch, self._sv.current_level)
      buffs_component:add_buff(buff_uri)
   end
end

function PetSkillComponent:_get_level_buff_uri(branch, level)
   for uri, data in pairs(SKILL_DATA) do
      if data.branch == branch and data.level == level then
         return uri
      end
   end
   log:warning('Could not find buff URI for branch %s at level %d', branch, level)
   return nil
end

-- ================== PUBLIC API FUNCTIONS ==================

function PetSkillComponent:get_pet_status()
   return {
      branch = self._sv.current_branch,
      level = self._sv.current_level,
      experience = self._sv.current_exp,
      exp_to_next = self._sv.exp_to_next_level,
      can_level_up = self:can_level_up()
   }
end

function PetSkillComponent:can_level_up()
   return (self._sv.current_level or 1) < 3  -- Max level 3
end

function PetSkillComponent:give_experience(amount)
   if not amount or amount <= 0 then return false end
   if not self:can_level_up() then return false end
   if not self._sv.current_branch then
      log:warning('Pet %s has no branch set, cannot gain experience', tostring(self._entity))
      return false
   end
   
   log:info('Adding %d experience to pet %s (current: %d/%d, level %d)', 
            amount, tostring(self._entity), self._sv.current_exp, self._sv.exp_to_next_level, self._sv.current_level)
   
   self._sv.current_exp = self._sv.current_exp + amount
   
   while self._sv.current_exp >= self._sv.exp_to_next_level and self:can_level_up() do
      self._sv.current_exp = self._sv.current_exp - self._sv.exp_to_next_level
      self:_level_up()
   end
   
   self.__saved_variables:mark_changed()
   return true
end

function PetSkillComponent:train_branch(branch_name)
   if not branch_name or branch_name == '' then return false end
   if self._sv.current_branch == branch_name then return true end -- No change needed
   
   -- Check if branch is valid by seeing if a level 1 buff exists for it
   if not self:_get_level_buff_uri(branch_name, 1) then
      log:warning('Attempted to train unknown branch: %s', branch_name)
      return false
   end

   log:info('Pet %s training new branch: %s', tostring(self._entity), branch_name)
   
   self:set_branch(branch_name)
   return true
end

function PetSkillComponent:set_branch(branch_name)
   -- This is now an internal function called by train_branch
   local old_branch = self._sv.current_branch
   
   log:info('Pet %s changing branch from %s to %s', tostring(self._entity), old_branch or 'none', branch_name)
   
   -- Set new branch and reset level/exp
   self._sv.current_branch = branch_name
   self._sv.current_level = 1
   self._sv.current_exp = 0
   self._sv.exp_to_next_level = self:_calculate_exp_to_next_level()
   
   -- Apply the new level 1 buff, which will handle removing any old ones.
   self:_apply_level_buff()
   
   self.__saved_variables:mark_changed()
end

function PetSkillComponent:reset_pet()
   log:info('Resetting pet %s', tostring(self._entity))
   
   local current_buff = self:_get_level_buff_uri(self._sv.current_branch, self._sv.current_level)
   if current_buff then
      local buffs_component = self._entity:get_component('stonehearth:buffs')
      if buffs_component then
         buffs_component:remove_buff(current_buff)
      end
   end
   
   self._sv.current_branch = nil
   self._sv.current_level = 1
   self._sv.current_exp = 0
   self._sv.exp_to_next_level = self:_calculate_exp_to_next_level()
   
   self.__saved_variables:mark_changed()
   return true
end

return PetSkillComponent

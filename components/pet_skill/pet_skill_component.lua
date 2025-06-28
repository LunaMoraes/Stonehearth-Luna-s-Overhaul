local log = radiant.log.create_logger('pet_skill')

local PetSkillComponent = class()

function PetSkillComponent:activate()
   log:info('Pet skill component activated for entity: %s', tostring(self._entity))
   
   -- Initialize saved variables properly
   if not self._sv.current_owner then
      self._sv.current_owner = nil
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
      log:info('Skill buff detected, updating owner buffs')
      self:_update_owner_buffs()
   end
end

function PetSkillComponent:_on_buff_removed(buff_uri)
   log:info('Pet buff removed: %s', tostring(buff_uri or 'nil'))
   if self:_is_skill_buff(buff_uri) then
      log:info('Skill buff removed, updating owner buffs')
      self:_update_owner_buffs()
   end
end

function PetSkillComponent:_is_skill_buff(buff_uri)
   -- Define which buffs provide owner benefits
   local skill_buffs = {
      ['luna_overhaul:buffs:pet_utility_level1'] = true,
      -- Add more skill buffs here as needed
   }
   
   return skill_buffs[buff_uri] == true
end

function PetSkillComponent:_get_owner_buff_for_skill(buff_uri)
   -- Map pet skill buffs to their corresponding owner buffs
   local owner_buffs = {
      ['luna_overhaul:buffs:pet_utility_level1'] = 'luna_overhaul:buffs:pet_utility_owner_level1',
      -- Add more mappings here as needed
   }
   
   return owner_buffs[buff_uri]
end

function PetSkillComponent:_update_owner_buffs()
   -- First, remove any existing owner buffs
   self:_remove_all_owner_buffs()
   
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
   -- Apply owner buffs for each skill buff the pet has
   for buff_uri, buff_data in pairs(buffs_component:get_buffs()) do
      log:debug('Checking pet buff: %s', buff_uri)
      if self:_is_skill_buff(buff_uri) then
         local owner_buff_uri = self:_get_owner_buff_for_skill(buff_uri)
         if owner_buff_uri then
            log:info('Applying owner buff: %s', owner_buff_uri)
            owner_buffs_component:add_buff(owner_buff_uri)
            applied_any_buff = true
         else
            log:warning('No owner buff mapping found for: %s', buff_uri)
         end
      end
   end
   
   if not applied_any_buff then
      log:info('No skill buffs found on pet, no owner buffs applied')
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
   
   -- Remove all owner buffs that this pet might have applied
   local owner_buff_uris = {
      'luna_overhaul:buffs:pet_utility_owner_level1',
      -- Add more owner buff URIs here as needed
   }
   
   for _, buff_uri in ipairs(owner_buff_uris) do
      if owner_buffs_component:has_buff(buff_uri) then
         log:info('Removing owner buff: %s from entity: %s', buff_uri, tostring(owner_entity))
         owner_buffs_component:remove_buff(buff_uri)
      end
   end
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

return PetSkillComponent

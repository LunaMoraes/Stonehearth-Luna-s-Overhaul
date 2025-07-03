-- This patch modifies the ACE-patched Shepherd class.
-- We require the base game's shepherd class, which we know has already been modified by ACE
-- because our server script waits for the 'stonehearth_ace:server:required_loaded' event.
local LunaShepherdClass = class()

local log = radiant.log.create_logger('luna_overhaul')

-- This function completely REPLACES the original modify_renewable_harvest
function LunaShepherdClass:modify_renewable_harvest(entity, uris)
   if not next(uris) then
      return
   end

   -- if we harvested a pasture animal, check for our bonus perks
   local equipment_component = entity:get_component('stonehearth:equipment')
   if equipment_component and equipment_component:has_item_type('stonehearth:pasture_equipment:tag') then
      local bonus = 0
      -- Check for the bigger perk first
      if self:has_perk('shepherd_extra_bonuses') then
         bonus = 4
      elseif self:has_perk('shepherd_small_extra_bonuses') then
         bonus = 2
      end

      if bonus > 0 then
         -- add the bonus to the quantity of the first quality of the first uri
         local qualities = uris[next(uris)]
         local quality = next(qualities)
         qualities[quality] = qualities[quality] + bonus
         log:info('Applied shepherd bonus of %d to harvest from %s', bonus, tostring(entity))
      end
   end
end

return LunaShepherdClass

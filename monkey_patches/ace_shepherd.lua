local AceShepherdClass = radiant.mods.require('stonehearth_ace.jobs.shepherd')
local LunaShepherdClass = class()

local log = radiant.log.create_logger('luna_overhaul')

-- Increase sheperd yield, as it is too low in vanilla
LunaShepherdClass._luna_old_modify_renewable_harvest = AceShepherdClass.modify_renewable_harvest
function LunaShepherdClass:modify_renewable_harvest(entity, uris)
   if not next(uris) then
      return
   end

   -- if we harvested a pasture animal and have the perk to produce extra items, apply that bonus
   local bonus = 0
   if self:has_perk('shepherd_extra_bonuses') then
      bonus = 4
   elseif self:has_perk('shepherd_small_extra_bonuses') then
      bonus = 2
   end

   if bonus > 0 then
      local equipment_component = entity:get_component('stonehearth:equipment')
      if equipment_component and equipment_component:has_item_type('stonehearth:pasture_equipment:tag') then
         -- just add the bonus to the quantity of the first quality of the first uri
         local qualities = uris[next(uris)]
         local quality = next(qualities)
         qualities[quality] = qualities[quality] + bonus
         log:info('Applied shepherd bonus of %d to harvest from %s', bonus, tostring(entity))
      end
   end
end

return LunaShepherdClass

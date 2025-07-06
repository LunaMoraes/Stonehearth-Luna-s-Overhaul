local validator = radiant.validator
local PastureCallHandler = class()
local log = radiant.log.create_logger('luna_overhaul')

function PastureCallHandler:set_pasture_auto_butcher(session, response, pasture, enabled)
   validator.expect_argument_types({'Entity', 'boolean'}, pasture, enabled)
   log:debug('LUNA: Call handler received set_pasture_auto_butcher: pasture=%s, enabled=%s', pasture:get_uri(), enabled)
   
   if session.player_id ~= pasture:get_player_id() then
      log:error('LUNA: Player %s does not own pasture %s', session.player_id, pasture:get_uri())
      return false
   end
   
   local pasture_component = pasture:get_component('stonehearth:shepherd_pasture')
   if not pasture_component then
      log:error('LUNA: Entity is not a pasture: %s', pasture:get_uri())
      return false
   end
   
   log:debug('LUNA: Calling set_auto_butcher_enabled on pasture component')
   pasture_component:set_auto_butcher_enabled(enabled)
   return true
end

return PastureCallHandler

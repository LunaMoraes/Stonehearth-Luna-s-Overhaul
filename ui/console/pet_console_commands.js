$(document).ready(function(){
   var selected;

   // Listen for selection changes to update our selected variable
   $(top).on("radiant_selection_changed.unit_frame", function (_, data) {
      selected = data.selected_entity;
   });

   radiant.console.register('add_pet', {
      call: function(cmdobj, fn, args) {
         return radiant.call('luna_overhaul:add_pet_command', args._[0]);
      },
      description: "Add a pet to your town. Usage: add_pet <pet_uri> (e.g., add_pet stonehearth:pets:kitten)"
   });

   radiant.console.register('add_pet_xp', {
      call: function(cmdobj, fn, args) {
         if (selected) {
            return radiant.call('luna_overhaul:add_pet_xp_command', selected);
         }
         return false;
      },
      description: "Give 50 XP to the selected pet (2 uses = level up from level 1). Usage: add_pet_xp"
   });

   radiant.console.register('check_buffs', {
      call: function(cmdobj, fn, args) {
         if (selected) {
            return radiant.call('luna_overhaul:check_entity_buffs_command', selected);
         }
         return false;
      },
      description: "Check all active buffs on the selected entity and prints them to the log. Usage: check_buffs"
   });

   radiant.console.register('pet_change_branch', {
      call: function(cmdobj, fn, args) {
         if (selected) {
            return radiant.call('luna_overhaul:pet_change_branch_command', selected);
         }
         return false;
      },
      description: "Change the selected pet's branch to 'utility' (resets level to 1). Usage: pet_change_branch"
   });
});

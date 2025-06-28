$(document).ready(function(){
   radiant.console.register('add_pet', {
      call: function(cmdobj, fn, args) {
         return radiant.call('luna_overhaul:add_pet_command', args._[0]);
      },
      description: "Add a pet to your town. Usage: add_pet <pet_uri> (e.g., add_pet stonehearth:pets:kitten)"
   });
});

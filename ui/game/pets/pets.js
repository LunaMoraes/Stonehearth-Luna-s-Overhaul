let pets_list = [];
let mainView = null;
let petsLastSortKey = null;
let petsLastSortDirection = 1;

App.StonehearthAcePetsView = App.View.extend({
   templateName: 'petsView',
   uriProperty: 'model',
   classNames: ['flex', 'exclusive'],
   closeOnEsc: true,
   skipInvisibleUpdates: true,
   hideOnCreate: false,
   components: {
      'stonehearth:unit_info': {},
      'stonehearth:attributes' : {},
      'stonehearth:expendable_resources' : {},
      'stonehearth:pet' : {},
      'luna_overhaul:pet_skill': {}
   },

   init: function() {
      var self = this;
      this._super();
      mainView = this;
      
      //Trace town pets on init
      this._traceTownPets();
      
   },

   dismiss: function() {
      this.hide();
   },

   hide: function() {
      var self = this;

      if (!self.$()) return;

      var index = App.stonehearth.modalStack.indexOf(self)
      if (index > -1) {
         App.stonehearth.modalStack.splice(index, 1);
      }
      this._super();
   },

   show: function() {
      this._super();
      App.stonehearth.modalStack.push(this);
      
      // Force refresh of all pet data when menu is opened
      this._forceRefreshPetData();
   },

   willDestroyElement: function() {
      var self = this;
      
      if (self._petTraces) {
         self._petTraces.destroy();
         self._petTraces = null;
      }

      self.$().off('click');
      self.$().find('.tooltipstered').tooltipster('destroy');

      this._super();
   },
   
   _traceTownPets: function() {
      var playerId = App.stonehearthClient.getPlayerId()
      var self = this;
      radiant.call_obj('stonehearth.town', 'get_town_entity_command', playerId)
         .done(function (response) {
            var components = {
               town_pets: {
                 '*': {
                     'stonehearth:commands': {
                        'commands': {},
                     },
                     'stonehearth:pet': {},
                     'stonehearth:unit_info': {},
                     "stonehearth:ai": {
                        "status_text_data": {},
                     },
                     'stonehearth:buffs' : {
                        'buffs' : {
                           '*' : {}
                        }
                     },
                     'stonehearth:expendable_resources': {},
                     'luna_overhaul:pet_skill': {},
                  },
               },
            };
            var town = response.town;
            self._petTraces = new StonehearthDataTrace(town, components)
               .progress(function (response) {
                  if (self.isDestroying || self.isDestroyed) {
                     return;
                  }
                  var town_pets = response.town_pets || {};
                  
                  // Check if there are no pets
                  if (Object.keys(town_pets).length === 0) {
                     self.set('pets_list', []);
                     pets_list = [];
                     self.set('town_pets', {});
                     self.set('selected', null);
                     return;
                  }
                  
                  // Check if pets list has changed (only skip update if identical)
                  // Commenting out this check to force updates after pet release
                  /*
                  if (self.get('pets_list') && self.get('pets_list').length > 0) {
                     var townNew = JSON.stringify(town_pets);
                     var townOld = JSON.stringify(self.get('town_pets'));
                     if (townOld === townNew) {
                        return; // No changes, skip update
                     }
                  }
                  */
                  
                  // Process pets (always rebuild the list)
                  self.set('pets_list', []);
                  pets_list = []; // Clear the global array
                  var list_keys = Object.keys(town_pets);
                  var pet_object = {};
                  
                  for (var i = 0; i < list_keys.length; i++){
                        //Get pet object and add to list
                        pet_object = town_pets[list_keys[i]];
                        
                        // Check if this pet still has a valid pet component and owner
                        if (!pet_object || !pet_object['stonehearth:pet']) {
                           continue;
                        }
                        
                        // Check if the pet component indicates it's still a pet
                        var pet_comp = pet_object['stonehearth:pet'];
                        if (!pet_comp.is_pet || pet_comp.is_pet === false) {
                           continue;
                        }
                        
                        // Check if pet has an owner
                        if (!pet_comp.owner_display_name && !pet_comp.owner_custom_name) {
                           continue;
                        }
                        
                        pets_list.push(pet_object);
                     }
                     
                     // Now process the filtered pets list
                     for (var i = 0; i < pets_list.length; i++){
                        //Get health, hunger, social and sleepiness percentages
                        var health_percentage = Math.round(((pets_list[i]['stonehearth:expendable_resources'].resource_percentages.health)*100)*10)/10;
                        var hunger_percentage = Math.round(100-(Math.round(((pets_list[i]['stonehearth:expendable_resources'].resource_percentages.calories)*100)*10)/10)/10);
                        var social_percentage = Math.round(((pets_list[i]['stonehearth:expendable_resources'].resource_percentages.social_satisfaction)*100)*10)/10;
                        var sleepiness_percentage = Math.round(((pets_list[i]['stonehearth:expendable_resources'].resource_percentages.sleepiness)*100)*10)/10;
                        pets_list[i].health = String(health_percentage)
                        pets_list[i].hunger = String(hunger_percentage)
                        pets_list[i].social = String(social_percentage)
                        pets_list[i].sleepiness = String(sleepiness_percentage)
                        //Get pet status
                        pets_list[i].activity = pets_list[i]['stonehearth:ai'].status_text_key
                        //Get pet Buffs
                        var buff_keys = Object.keys(pets_list[i]['stonehearth:buffs'].buffs);
                        var buff_list = [];
                        for (var j = 0; j < buff_keys.length; j++){
                           
                           buff_list[j] = pets_list[i]['stonehearth:buffs'].buffs[buff_keys[j]];
                           
                        }
                        pets_list[i].buffs = buff_list;

                        //Get pet commands
                        var command_keys = Object.keys(pets_list[i]['stonehearth:commands'].commands);
                        var command_list = [];
                        for (var j = 0; j < command_keys.length; j++){
                           
                           command_list[j] = pets_list[i]['stonehearth:commands'].commands[command_keys[j]];
                           
                        }
                        //console.log(command_list[0].display_name)
                        pets_list[i].available_commands = command_list;
                                             
                     }
                     
                     //Set pet list and selected pet + portrait for the first time
                     self.set('pets_list', pets_list);
                     
                     // Apply initial sorting
                     if (petsLastSortKey) {
                        self.set('sortKey', petsLastSortKey);
                        self.set('sortDirection', petsLastSortDirection || 1);
                        self._sortPetsList();
                     }
                     
                     self.set('town_pets', town_pets);
                     if (!self.get('selected') && pets_list[0]) {
                        self.set('selected', pets_list[0]);
                        self.set('selected_index', pets_list[0]);
                        var uri = pets_list[0].__self;
                        var portrait_url = '/r/get_portrait/?type=headshot&animation=idle_breathe.json&entity=' + uri + '&cache_buster=' + Math.random();
                        self.$('#selectedPortrait').css('background-image', 'url(' + portrait_url + ')');  
                     }       
                     
                     //debugger
                     return;
                  
               })
               .fail(function(e) {
                  console.log(e);
               });

      });
   },
   
   didInsertElement: function() {
      var self = this;
      self._super();
      

      this.$().draggable({ handle: '.title' });

      //not functional yet
      self.$().on('click', '.listTitle', function() {
         var newSortKey = $(this).attr('data-sort-key');
         if (newSortKey) {
            if (newSortKey == self.get('sortKey')) {
               self.set('sortDirection', -(self.get('sortDirection') || 1));
            } else {
               self.set('sortKey', newSortKey);
               self.set('sortDirection', 1);
            }

            petsLastSortKey = newSortKey;
            petsLastSortDirection = self.get('sortDirection');
            
            // Apply sorting to pets list
            self._sortPetsList();
         }
      });

      if (self.hideOnCreate) {
         self.hide();
      }
      //Change pet selection on click
      self.$('#petTable').on('click', 'tr', function () {
         if(pets_list.length > 0){ //check if any pets are available to select
            if(!$(this).hasClass('selected')) {
               $('#petTable tr').removeClass('selected');
               $(this).addClass('selected');
               self.set('selected', pets_list[$(this).index()]);
               self.set('selected_index', $(this).index());
            }
            //Re-select portrait
            var uri = pets_list[$(this).index()].__self;
            var portrait_url = '/r/get_portrait/?type=headshot&animation=idle_breathe.json&entity=' + uri + '&cache_buster=' + Math.random();
            self.$('#selectedPortrait').css('background-image', 'url(' + portrait_url + ')');
            //Focus on entity and open pet sheet
            radiant.call('stonehearth:camera_look_at_entity', uri);
            radiant.call('stonehearth:select_entity', uri);
            radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:focus' });
         }
      });
   },
   
   _sortPetsList: function() {
      var self = this;
      var sortKey = self.get('sortKey');
      var sortDirection = self.get('sortDirection') || 1;
      
      if (!pets_list || pets_list.length === 0) {
         return;
      }
      
      pets_list.sort(function(a, b) {
         var aValue, bValue;
         
         switch(sortKey) {
            case 'name':
               aValue = a['stonehearth:unit_info'] && a['stonehearth:unit_info'].custom_name || '';
               bValue = b['stonehearth:unit_info'] && b['stonehearth:unit_info'].custom_name || '';
               return sortDirection * aValue.localeCompare(bValue);
               
            case 'activity':
               aValue = a.activity || '';
               bValue = b.activity || '';
               return sortDirection * aValue.localeCompare(bValue);
               
            case 'health':
               aValue = parseFloat(a.health) || 0;
               bValue = parseFloat(b.health) || 0;
               return sortDirection * (aValue - bValue);
               
            case 'hunger':
               aValue = parseFloat(a.hunger) || 0;
               bValue = parseFloat(b.hunger) || 0;
               return sortDirection * (aValue - bValue);
               
            case 'social':
               aValue = parseFloat(a.social) || 0;
               bValue = parseFloat(b.social) || 0;
               return sortDirection * (aValue - bValue);
               
            case 'sleepiness':
               aValue = parseFloat(a.sleepiness) || 0;
               bValue = parseFloat(b.sleepiness) || 0;
               return sortDirection * (aValue - bValue);
               
            default:
               return 0;
         }
      });
      
      // Update the pets_list property to trigger UI refresh
      self.set('pets_list', []);
      Ember.run.next(function() {
         self.set('pets_list', pets_list);
      });
   },
   
   _updatePetSkillAttributes: function() {
      var self = this;
      var existingSelected = self.get('selected');

      if (existingSelected && existingSelected['luna_overhaul:pet_skill']) {
         var petSkillData = existingSelected['luna_overhaul:pet_skill'];
         var currentLevel = petSkillData.current_level || 1;
         var currentExp = petSkillData.current_exp || 0;
         var expToNext = petSkillData.exp_to_next_level || 50;
         var currentBranch = petSkillData.current_branch;
         
         // Calculate percentage (prevent division by zero)
         var expPercent = expToNext > 0 ? Math.floor((currentExp / expToNext) * 100) : 0;
         var expLabel = 'Lvl ' + currentLevel;
         
         // Set branch label
         var branchLabel = '';
         if (currentBranch) {
            switch (currentBranch) {
               case 'utility':
                  branchLabel = i18n.t('luna_overhaul:ui.game.pet_manager.branches.utility');
                  break;
               // Add more branches as needed
               default:
                  branchLabel = currentBranch;
            }
         } else {
            branchLabel = i18n.t('luna_overhaul:ui.game.pet_manager.no_branch');
         }

         self.set('pet_exp_bar_style', 'width: ' + expPercent + '%');
         self.set('pet_exp_bar_label', expLabel);
         self.set('pet_branch_label', branchLabel);
      } else {
         // No pet skill component or no selected pet
         self.set('pet_exp_bar_style', 'width: 0%');
         self.set('pet_exp_bar_label', 'Lvl 1');
         self.set('pet_branch_label', i18n.t('luna_overhaul:ui.game.pet_manager.no_branch'));
      }
   }.observes('selected.luna_overhaul:pet_skill'),

   actions: {
      doCommand: function(command) {
         var self = this;
         var pet_data = self.get('selected');
         var pet_id = pet_data.__self;
         var player_id = pet_data.player_id;
         
         // Special handling for release pet command
         if (command.name == 'release_pet') {
            // Show confirmation dialog like stonehearth_ace does
            App.gameView.addView(App.StonehearthConfirmView, {
               title : i18n.t('stonehearth:ui.game.pet_character_sheet.release_pet_confirm_dialog.title'),
               message : i18n.t('stonehearth:ui.game.pet_character_sheet.release_pet_confirm_dialog.message'),
               buttons : [
                  {
                     id: 'accept',
                     label: i18n.t('stonehearth:ui.game.pet_character_sheet.release_pet_confirm_dialog.accept'),
                     click: function() {
                        // Call the release function directly when confirmed
                        radiant.call('stonehearth:release_pet', pet_id);
                        
                        // Set up a delayed refresh since the promise might not work reliably
                        setTimeout(function() {
                           // Force a complete refresh after the pet is released
                           if (self._petTraces) {
                              self._petTraces.destroy();
                              self._petTraces = null;
                           }
                           
                           // Clear existing data to force a fresh reload
                           self.set('pets_list', null);
                           self.set('town_pets', null);
                           self.set('selected', null);
                           pets_list = [];
                           
                           // Refresh the pets list
                           self._traceTownPets();
                        }, 500); // Wait 500ms for server to process the release
                     }
                  },
                  {
                     id: 'cancel',
                     label: i18n.t('stonehearth:ui.game.pet_character_sheet.release_pet_confirm_dialog.cancel')
                  }
               ]
            });
         } else {
            // For all other commands, use the normal doCommand
            App.stonehearthClient.doCommand(pet_id, player_id, command);
         }
      }
   },
   
   _forceRefreshPetData: function() {
      var self = this;
      
      // Destroy existing traces to force fresh data
      if (self._petTraces) {
         self._petTraces.destroy();
         self._petTraces = null;
      }
      
      // Clear existing data
      self.set('pets_list', []);
      self.set('town_pets', {});
      self.set('selected', null);
      pets_list = [];
      
      // Re-initialize the pet traces
      self._traceTownPets();
      
      // Trigger pet skill attribute update after a brief delay to ensure data is loaded
      setTimeout(function() {
         self._updatePetSkillAttributes();
      }, 100);
   },
});

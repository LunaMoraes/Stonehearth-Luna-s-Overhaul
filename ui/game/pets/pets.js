let pets_list = [];
let mainView = null;
let petsLastSortKey = null;
let petsLastSortDirection = 1;

// Helper function from citizens.js to determine which of the 8 heart segments to use
var getOctile = function(percentage) {
   // return 0-8
   return Math.round(percentage * 8);
};

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
      'luna_overhaul:pet_skill': {},
      // Simplified components, removed incapacitation
      "stonehearth:buffs": {
         "buffs_by_category": {}
      }
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
   
   // This function is a simplified version of _updateHealth in citizens.js
   _updatePetHealthData: function(pet_data) {
      var self = this;
      var currentHealth = pet_data['stonehearth:expendable_resources'].resources.health;
      if (currentHealth == null) {
         return;
      }

      currentHealth = Math.ceil(currentHealth);
      var maxHealth = Math.ceil(pet_data['stonehearth:attributes'].attributes.max_health.effective_value);
      var percentHealth = currentHealth / maxHealth;

      var poisonBuffs = pet_data['stonehearth:buffs'].buffs_by_category.poison;
      var isPoisoned = poisonBuffs && Object.keys(poisonBuffs).length > 0;
      
      var icon;
      
      if (currentHealth <= 0) {
         icon = "heart_empty";
      } else if (currentHealth >= maxHealth) {
         icon = "heart_full"
      } else {
         icon = `heart_${getOctile(percentHealth)}_8`;
      }

      var value = percentHealth;
      
      if (isPoisoned) {
         icon = "poisoned/" + icon;
      }

      // The final path to the image asset in the stonehearth_ace mod
      icon = "/stonehearth_ace/ui/game/citizens/images/health/" + icon + ".png";

      // Attach the calculated health data to the pet object
      pet_data.health_data = {
         icon: icon,
         value: value,
         isPoisoned: isPoisoned,
      };
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
                        },
                        "buffs_by_category": {} // for poison check
                     },
                     'stonehearth:expendable_resources': {},
                     'luna_overhaul:pet_skill': {},
                     'stonehearth:attributes': {},
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
                        var current_pet = pets_list[i];
                        //Get health, hunger, social and sleepiness percentages
                        var hunger_percentage = Math.round(100-(Math.round(((current_pet['stonehearth:expendable_resources'].resource_percentages.calories)*100)*10)/10)/10);
                        var social_percentage = Math.round(((current_pet['stonehearth:expendable_resources'].resource_percentages.social_satisfaction)*100)*10)/10;
                        var sleepiness_percentage = Math.round(((current_pet['stonehearth:expendable_resources'].resource_percentages.sleepiness)*100)*10)/10;
                        
                        // NEW: Calculate health data object instead of just percentage
                        self._updatePetHealthData(current_pet);

                        current_pet.hunger = String(hunger_percentage)
                        current_pet.social = String(social_percentage)
                        current_pet.sleepiness = String(sleepiness_percentage)
                        //Get pet status
                        current_pet.activity = current_pet['stonehearth:ai'].status_text_key
                        //Get pet Buffs
                        var buff_keys = Object.keys(current_pet['stonehearth:buffs'].buffs);
                        var buff_list = [];
                        for (var j = 0; j < buff_keys.length; j++){
                           
                           buff_list[j] = current_pet['stonehearth:buffs'].buffs[buff_keys[j]];
                           
                        }
                        current_pet.buffs = buff_list;

                        //Get pet commands
                        var command_keys = Object.keys(current_pet['stonehearth:commands'].commands);
                        var command_list = [];
                        for (var j = 0; j < command_keys.length; j++){
                           
                           command_list[j] = current_pet['stonehearth:commands'].commands[command_keys[j]];
                           
                        }
                        current_pet.available_commands = command_list;
                                             
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
            var selectedPet = pets_list[$(this).index()];
            if(!$(this).hasClass('selected')) {
               $('#petTable tr').removeClass('selected');
               $(this).addClass('selected');
               self.set('selected', selectedPet);
               self.set('selected_index', $(this).index());
            }
            //Re-select portrait
            var uri = selectedPet.__self;
            var portrait_url = '/r/get_portrait/?type=headshot&animation=idle_breathe.json&entity=' + uri + '&cache_buster=' + Math.random();
            self.$('#selectedPortrait').css('background-image', 'url(' + portrait_url + ')');
            //Focus on entity and open pet sheet
            radiant.call('stonehearth:camera_look_at_entity', uri);
            radiant.call('stonehearth:select_entity', uri);
            radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:focus' });

            // Update health tooltip for the selected row
            var healthData = selectedPet.health_data;
            if (healthData) {
               App.tooltipHelper.createDynamicTooltip($(this).find('.petHealth'), function () {
                  var value = Math.floor(100 * healthData.value);
                  var tooltipKey;
                  if (healthData.isPoisoned) {
                     tooltipKey = 'poisoned';
                  } else if (healthData.value <= 0) {
                     tooltipKey = 'dying'; // Using 'dying' tooltip for dead pets
                  } else {
                     tooltipKey = value >= 100 ? 'healthy' : 'hurt';
                  }

                  var i18nData = {value: value};
                  var healthString = App.tooltipHelper.createTooltip(
                     i18n.t(`stonehearth_ace:ui.game.citizens.health_tooltips.${tooltipKey}_title`, i18nData),
                     i18n.t(`stonehearth_ace:ui.game.citizens.health_tooltips.${tooltipKey}_description`, i18nData));
                  return $(healthString);
               });
            }
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
               // Sort by the numeric health value, not the icon path
               aValue = (a.health_data && a.health_data.value) || 0;
               bValue = (b.health_data && b.health_data.value) || 0;
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
            // Dynamically construct the i18n key to get the localized branch name.
            // This uses the same localization keys as the command buttons for consistency.
            var branch_i18n_key = 'luna_overhaul:data.commands.choose_training_branch.' + currentBranch + '_branch_name';
            branchLabel = i18n.t(branch_i18n_key);
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

$(document).ready(function() {
   // Listen for the event fired by our command
   $(top).on('luna_overhaul:choose_training_branch', function (_, e) {
      var petUri = e.entity;
      var allBranches = ["utility", "combat", "therapist"];
      
      // Since we can't directly access the component data here without another async call,
      // we'll rely on the currently selected pet in the main view.
      var petManagerView = mainView;
      if (!petManagerView || petManagerView.isDestroyed) {
         return;
      }

      var selectedPet = petManagerView.get('selected');
      if (!selectedPet || selectedPet.__self !== petUri) {
         // If the event is for a pet that isn't selected, we can't reliably get its branch.
         // This is a fallback, but ideally the UI only allows this for the selected pet.
         console.log("Choose branch command fired for a non-selected pet. This might not work as expected.");
         return;
      }
      
      var petSkillData = selectedPet['luna_overhaul:pet_skill'];
      var currentBranch = petSkillData ? petSkillData.current_branch : null;
      
      var availableBranches = allBranches.filter(function(branch) {
         return branch !== currentBranch;
      });
      
      var dialogButtons = [];

      availableBranches.forEach(function(branchName) {
         var i18n_key = 'luna_overhaul:data.commands.choose_training_branch.' + branchName + '_branch_name';
         var branchButton = {
            id: branchName,
            label: i18n.t(i18n_key),
            click: function() {
               // Call the server to change the branch
               radiant.call('luna_overhaul:pet_change_branch_command', petUri, branchName)
                  .done(function(response) {
                     // This part only runs AFTER the server confirms the change was successful.
                     // Refresh pet data in the pet manager view
                     if (petManagerView && !petManagerView.isDestroyed) {
                        petManagerView._forceRefreshPetData();
                     }
                  });
            }
         };
         dialogButtons.push(branchButton);
      });

      dialogButtons.push({
         id: 'cancel',
         label: i18n.t('stonehearth:ui.game.common.cancel')
      });

      App.gameView.addView(App.StonehearthConfirmView, {
         title : i18n.t('luna_overhaul:data.commands.choose_training_branch.display_name'),
         message : i18n.t('luna_overhaul:data.commands.choose_training_branch.description'),
         buttons : dialogButtons,
         class: 'choose-branch-dialog' // Add a custom class for styling
      });
   });
});
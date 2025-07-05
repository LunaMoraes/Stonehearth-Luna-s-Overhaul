// Helper function from citizens.js to determine which of the 8 heart segments to use
var getOctile = function(percentage) {
   // return 0-8
   return Math.round(percentage * 8);
};

let g_livestock_list = [];
let g_livestockMainView = null;
let g_livestockLastSortKey = null;
let g_livestockLastSortDirection = 1;

App.LunaOverhaulLivestockView = App.View.extend({
   templateName: 'livestockView',
   uriProperty: 'model',
   classNames: ['flex', 'exclusive'],
   closeOnEsc: true,
   skipInvisibleUpdates: true,
   hideOnCreate: false,
   components: {
      'stonehearth:unit_info': {},
      'stonehearth:ai': {},
      'stonehearth:expendable_resources' : {},
      'stonehearth:attributes' : {},
      "stonehearth:buffs": {
         "buffs": {
            '*': {}
         }
      },
      'stonehearth:commands': {
         'commands': {},
      }
   },

   init: function() {
      var self = this;
      this._super();
      g_livestockMainView = this;
      this._traceTownLivestock();
   },

   dismiss: function() {
      this.hide();
   },

   hide: function() {
      var self = this;
      if (!self.$()) return;
      var index = App.stonehearth.modalStack.indexOf(self);
      if (index > -1) {
         App.stonehearth.modalStack.splice(index, 1);
      }
      this._super();
   },

   show: function() {
      this._super();
      App.stonehearth.modalStack.push(this);
      this._forceRefreshLivestockData();
   },

   willDestroyElement: function() {
      var self = this;
      if (self._livestockTraces) {
         self._livestockTraces.destroy();
         self._livestockTraces = null;
      }
      self.$().off('click');
      self.$().find('.tooltipstered').tooltipster('destroy');
      this._super();
   },

   _traceTownLivestock: function() {
      var playerId = App.stonehearthClient.getPlayerId();
      var self = this;
      radiant.call_obj('stonehearth.town', 'get_town_entity_command', playerId)
         .done(function (response) {
            var components = {
               pasture_animals: {
                  '*': self.components
               }
            };
            self._livestockTraces = new StonehearthDataTrace(response.town, components)
               .progress(function (response) {
                  if (self.isDestroying || self.isDestroyed) return;

                  var pasture_animals = response.pasture_animals || {};
                  g_livestock_list = radiant.map_to_array(pasture_animals);

                  g_livestock_list.forEach(function(animal) {
                     var resources = animal['stonehearth:expendable_resources'];
                     if (resources && resources.resource_percentages) {
                        animal.hunger = Math.round(100 - (resources.resource_percentages.calories * 100));
                        animal.social = Math.round(resources.resource_percentages.social_satisfaction * 100);
                     } else {
                        animal.hunger = 0;
                        animal.social = 0;
                     }

                     animal.buffs = radiant.map_to_array(animal['stonehearth:buffs'].buffs);
                     animal.available_commands = radiant.map_to_array(animal['stonehearth:commands'].commands);

                     // Set activity status
                     animal.activity = animal['stonehearth:ai'].status_text_key;

                     // Handle animal name - livestock don't have custom names, use catalog data            
                     // Try to get display name from unit_info first
                     if (animal['stonehearth:unit_info'] && animal['stonehearth:unit_info'].display_name) {
                        animal.display_name = i18n.t(animal['stonehearth:unit_info'].display_name, {self: animal});
                     } else {
                        // Fallback: try to get localized name from catalog using URI
                        try {
                           var catalogData = App.catalog.getCatalogData(animal.uri);
                           if (catalogData && catalogData.display_name) {
                              animal.display_name = i18n.t(catalogData.display_name);
                           } else {
                              // Last fallback: extract name from URI and make it readable
                              var uriParts = animal.uri.split(':');
                              if (uriParts.length >= 2) {
                                 // Convert "rabbit:pasture" to "Rabbit"
                                 animal.display_name = uriParts[uriParts.length - 2].charAt(0).toUpperCase() + 
                                                     uriParts[uriParts.length - 2].slice(1);
                              } else {
                                 animal.display_name = "Unknown Animal";
                              }
                           }
                        } catch (e) {
                           // Fallback to URI parsing
                           var uriParts = animal.uri.split(':');
                           if (uriParts.length >= 2) {
                              animal.display_name = uriParts[uriParts.length - 2].charAt(0).toUpperCase() + 
                                                  uriParts[uriParts.length - 2].slice(1);
                           } else {
                              animal.display_name = "Unknown Animal";
                           }
                        }
                     }

                     // Health data processing
                     self._updateLivestockHealthData(animal);
                  });

                  self.set('livestock_list', g_livestock_list);
                  
                  if (g_livestockLastSortKey) {
                     self._sortLivestockList();
                  }
                  
                  if (!self.get('selected') && g_livestock_list.length > 0) {
                     self.set('selected', g_livestock_list[0]);
                     
                     // Add visual selection and portrait after render
                     Ember.run.scheduleOnce('afterRender', function() {
                        self.$('#livestockTable tr.livestockRow:first').addClass('selected');
                        
                        // Set portrait after DOM is ready
                        var uri = g_livestock_list[0].__self;
                        var portrait_url = '/r/get_portrait/?type=headshot&animation=idle_breathe.json&entity=' + uri + '&cache_buster=' + Math.random();
                        self.$('#selectedPortrait').css('background-image', 'url(' + portrait_url + ')');
                     });
                  } else if (g_livestock_list.length == 0) {
                     self.set('selected', null);
                  }
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
            g_livestockLastSortKey = newSortKey;
            g_livestockLastSortDirection = self.get('sortDirection');
            self._sortLivestockList();
         }
      });

      if (self.hideOnCreate) {
         self.hide();
      }

      self.$('#livestockTable').on('click', 'tr.livestockRow', function () {
         var index = $(this).index();
         if(g_livestock_list.length > 0 && g_livestock_list[index]){
            var selectedLivestock = g_livestock_list[index];
            self.set('selected', selectedLivestock);
            
            self.$('tr.livestockRow').removeClass('selected');
            $(this).addClass('selected');

            var uri = selectedLivestock.__self;
            var portrait_url = '/r/get_portrait/?type=headshot&animation=idle_breathe.json&entity=' + uri + '&cache_buster=' + Math.random();
            self.$('#selectedPortrait').css('background-image', 'url(' + portrait_url + ')');
            radiant.call('stonehearth:camera_look_at_entity', uri);
            radiant.call('stonehearth:select_entity', uri);
            radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:focus' });
         }
      });
   },
   
   _sortLivestockList: function() {
      var self = this;
      var sortKey = self.get('sortKey');
      var sortDirection = self.get('sortDirection') || 1;
      
      if (!g_livestock_list || g_livestock_list.length === 0) return;
      
      g_livestock_list.sort(function(a, b) {
         var aValue, bValue;
         switch(sortKey) {
            case 'name':
               aValue = a.display_name || '';
               bValue = b.display_name || '';
               return sortDirection * aValue.localeCompare(bValue);
            case 'hunger':
               aValue = a.hunger || 0;
               bValue = b.hunger || 0;
               return sortDirection * (aValue - bValue);
            case 'social':
               aValue = a.social || 0;
               bValue = b.social || 0;
               return sortDirection * (aValue - bValue);
            default: return 0;
         }
      });
      
      self.set('livestock_list', []);
      Ember.run.next(function() {
         self.set('livestock_list', g_livestock_list);
      });
   },

   // This function is adapted from pets.js _updatePetHealthData
   _updateLivestockHealthData: function(animal_data) {
      var self = this;
      var currentHealth = animal_data['stonehearth:expendable_resources'].resources.health;
      if (currentHealth == null) {
         return;
      }

      currentHealth = Math.ceil(currentHealth);
      var maxHealth = Math.ceil(animal_data['stonehearth:attributes'].attributes.max_health.effective_value);
      var percentHealth = currentHealth / maxHealth;

      // Safely check for poison buffs - newly born animals might not have buffs fully initialized
      var isPoisoned = false;
      var buffs_component = animal_data['stonehearth:buffs'];
      if (buffs_component && buffs_component.buffs_by_category && buffs_component.buffs_by_category.poison) {
         var poisonBuffs = buffs_component.buffs_by_category.poison;
         isPoisoned = poisonBuffs && Object.keys(poisonBuffs).length > 0;
      }
      
      var icon;
      
      if (currentHealth <= 0) {
         icon = "heart_empty";
      } else if (currentHealth >= maxHealth) {
         icon = "heart_full"
      } else {
         // Using getOctile function - this should be available globally
         icon = `heart_${getOctile(percentHealth)}_8`;
      }

      var value = percentHealth;
      
      if (isPoisoned) {
         icon = "poisoned/" + icon;
      }

      // The final path to the image asset in the stonehearth_ace mod
      icon = "/stonehearth_ace/ui/game/citizens/images/health/" + icon + ".png";

      // Attach the calculated health data to the animal object
      animal_data.health_data = {
         icon: icon,
         value: value,
         isPoisoned: isPoisoned,
      };
   },

   actions: {
      doCommand: function(command) {
         var self = this;
         var livestock_data = self.get('selected');
         var livestock_id = livestock_data.__self;
         var player_id = App.stonehearthClient.getPlayerId();
         App.stonehearthClient.doCommand(livestock_id, player_id, command);
      }
   },
   
   _forceRefreshLivestockData: function() {
      var self = this;
      if (self._livestockTraces) {
         self._livestockTraces.destroy();
         self._livestockTraces = null;
      }
      self.set('livestock_list', []);
      self.set('selected', null);
      g_livestock_list = [];
      self._traceTownLivestock();
   },
});
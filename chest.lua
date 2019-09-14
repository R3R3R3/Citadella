local function has_locked_chest_privilege(pos, player)
   local pname = player:get_player_name()
   local reinf = ct.get_reinforcement(pos)
   if not reinf then
      return true
   end

   local player_id = pm.get_player_by_name(pname).id
   local player_groups = pm.get_groups_for_player(player_id)
   local reinf_ctgroup_id = reinf.ctgroup_id
   local reinf_id_in_group_ids = false

   for _, group in ipairs(player_groups) do
      if reinf_ctgroup_id == group.id then
         reinf_id_in_group_ids = true
         break
      end
   end

   if reinf_id_in_group_ids then
      return true
   else
      minetest.chat_send_player(pname, "Chest is locked!")
      return false
   end
end


minetest.register_craft({
      type = "fuel",
      recipe = "citadella:chest",
      burntime = 30,
})


minetest.register_craft({
      output = "citadella:chest",
      recipe = {
         {'default:wood', 'default:wood', 'default:wood'},
         {'default:wood', ''            , 'default:wood'},
         {'default:wood', 'default:wood', 'default:wood'},
      }
})

local open = "size[8,10]"..
	-- default.gui_bg ..
	-- default.gui_bg_img ..
	-- default.gui_slots ..
	"list[current_name;main;0,0.3;8,4;]"..
	"list[current_player;main;0,4.85;8,1;]" ..
	"list[current_player;main;0,6.08;8,3;8]" ..
	"listring[current_name;main]" ..
	"listring[current_player;main]" ..
	"button[3,9;2,1;open;Close]" -- ..
	-- default.get_hotbar_bg(0,4.85)

local closed = "size[2,1]"..
	"button[0,0;2,1;open;Open]"

minetest.register_node(
   "citadella:chest",
   {
      description = "Citadella's standard chest",
      tiles ={"default_chest.png^[sheet:2x2:0,0", "default_chest.png^[sheet:2x2:0,0",
              "default_chest.png^[sheet:2x2:1,0", "default_chest.png^[sheet:2x2:1,0",
              "default_chest.png^[sheet:2x2:1,0", "default_chest.png^[sheet:2x2:1,1"},
      paramtype2 = "facedir",
      groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
      legacy_facedir_simple = true,
      is_ground_content = false,
      sounds = default.node_sound_wood_defaults(),
      on_construct = function(pos)
         local meta = minetest.get_meta(pos)
         meta:set_string("formspec", open)
         -- meta:set_string("infotext", "Locked chest")
         -- meta:set_string("owner", "")
         local inv = meta:get_inventory()
         inv:set_size("main", 8*4)
      end,
      can_dig = function(pos,player)
         local meta = minetest.get_meta(pos);
         local inv = meta:get_inventory()
         return inv:is_empty("main")
      end,
      allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
         local meta = minetest.get_meta(pos)
         if not has_locked_chest_privilege(pos, player) then
            minetest.log("action", player:get_player_name()..
                            " tried to access a locked chest belonging to "..
                            meta:get_string("owner").." at "..
                            minetest.pos_to_string(pos))
            return 0
         end
         return count
      end,
      allow_metadata_inventory_put = function(pos, listname, index, stack, player)
         local meta = minetest.get_meta(pos)
         if not has_locked_chest_privilege(pos, player) then
            minetest.log("action", player:get_player_name()..
                            " tried to access a locked chest belonging to "..
                            meta:get_string("owner").." at "..
                            minetest.pos_to_string(pos))
            return 0
         end
         return stack:get_count()
      end,
      allow_metadata_inventory_take = function(pos, listname, index, stack, player)
         local meta = minetest.get_meta(pos)
         if not has_locked_chest_privilege(pos, player) then
            minetest.log("action", player:get_player_name()..
                            " tried to access a locked chest belonging to "..
                            meta:get_string("owner").." at "..
                            minetest.pos_to_string(pos))
            return 0
         end
         return stack:get_count()
      end,
      on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
         minetest.log("action", player:get_player_name()..
                         " moves stuff in locked chest at "..minetest.pos_to_string(pos))
      end,
      on_metadata_inventory_put = function(pos, listname, index, stack, player)
         minetest.log("action", player:get_player_name()..
                         " moves stuff to locked chest at "..minetest.pos_to_string(pos))
      end,
      on_metadata_inventory_take = function(pos, listname, index, stack, player)
         minetest.log("action", player:get_player_name()..
                         " takes stuff from locked chest at "..minetest.pos_to_string(pos))
      end,

      on_receive_fields = function(pos, formname, fields, sender)
         local meta = minetest.get_meta(pos)

         if has_locked_chest_privilege(pos, sender) then
            if fields.open == "Open" then
               meta:set_string("formspec", open)
            else
               meta:set_string("formspec", closed)
            end
         end
      end,
})

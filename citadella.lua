
local stone_limit = tonumber(minetest.settings:get("stone_limit")) or 25
local iron_limit = tonumber(minetest.settings:get("iron_limit")) or 250
local diamond_limit = tonumber(minetest.settings:get("diamond_limit")) or 1800

ct.resource_limits = {
   ["default:stone"]   = stone_limit,
   ["default:iron"]    = iron_limit,
   ["default:diamond"] = diamond_limit
}

ct.PLAYER_MODE_NORMAL = "normal"
ct.PLAYER_MODE_REINFORCE = "reinforce"
ct.PLAYER_MODE_BYPASS = "bypass"
ct.PLAYER_MODE_FORTIFY = "fortify"
ct.PLAYER_MODE_INFO = "info"

-- Mapping of Player -> Citadel mode
-- XXX: couldn't get player:set_properties working so this could be nicer
ct.player_modes = {}
ct.player_current_reinf_group = {}
ct.player_fortify_material = {}

local function set_parameterized_mode(name, param, mode)
   local player = minetest.get_player_by_name(name)
   if not player then
      return false
   end
   local pname = player:get_player_name()
   local current_pmode = ct.player_modes[pname]
   if current_pmode == nil or current_pmode ~= mode then
      local player = pm.get_player_by_name(pname)
      local ctgroup = pm.get_group_by_name(param)
      if not ctgroup then
         minetest.chat_send_player(
            pname,
            "Group '" .. param .. "' does not exist."
         )
         return false
      end
      local player_group = pm.get_player_group(player.id, ctgroup.id)
      if not player_group then
         minetest.chat_send_player(
            pname,
            "You are not on group '" .. param .. "'."
         )
         return false
      end
      ct.player_modes[pname] = mode
      ct.player_current_reinf_group[pname] = ctgroup
      minetest.chat_send_player(
         pname,
         "Citadella mode: " .. ct.player_modes[pname] ..
            " (group: '" .. ctgroup.name .. "')"
      )
   else
      ct.player_modes[pname] = ct.PLAYER_MODE_NORMAL
      minetest.chat_send_player(
         pname,
         "Citadella mode: " .. ct.player_modes[pname]
      )
   end
   return true
end


minetest.register_chatcommand("ctr", {
   params = "<group>",
   description = "Citadella reinforce with material",
   func = function(name, param)
      set_parameterized_mode(name, param, ct.PLAYER_MODE_REINFORCE)
   end
})


minetest.register_chatcommand("ctf", {
   params = "",
   description = "Citadella fortify mode",
   func = function(name, param)
      local player = minetest.get_player_by_name(name)
      if not player then
         return false
      end
      local pname = player:get_player_name()
      local item = player:get_wielded_item()
      local item_name = item:get_name()
      local resource_limit = ct.resource_limits[item_name]
      if resource_limit then
         ct.player_fortify_material[pname] = item_name
         set_parameterized_mode(pname, param, ct.PLAYER_MODE_FORTIFY)
         return true
      else
         local valid_materials = pmutils.table_keyvals(ct.resource_limits)
         minetest.chat_send_player(
            pname,
            "Error: " .. item_name .. " is not a valid reinforcement material ("
               .. table.concat(valid_materials, ", ") .. ")."
         )
         return false
      end
   end
})


local function set_simple_mode(name, mode)
   local player = minetest.get_player_by_name(name)
   if not player then
      return false
   end
   local pname = player:get_player_name()
   local current_pmode = ct.player_modes[pname]
   if mode == ct.PLAYER_MODE_NORMAL then
      ct.player_modes[pname] = mode
   elseif current_pmode == nil or current_pmode ~= mode then
      ct.player_modes[pname] = mode
   else -- Toggle
      ct.player_modes[pname] = ct.PLAYER_MODE_NORMAL
   end
   minetest.chat_send_player(pname, "Citadella mode: " .. ct.player_modes[pname])
end


minetest.register_chatcommand("ctb", {
   params = "",
   description = "Citadella bypass owned reinforcements",
   func = function(name, param)
      if param ~= "" then
         minetest.chat_send_player(name, "Error: Usage: /ctb")
      else
         set_simple_mode(name, ct.PLAYER_MODE_BYPASS)
      end
   end
})


minetest.register_chatcommand("cto", {
   params = "",
   description = "Citadella reset player mode",
   func = function(name, param)
      if param ~= "" then
         minetest.chat_send_player(name, "Error: Usage: /cto")
      else
         set_simple_mode(name, ct.PLAYER_MODE_NORMAL)
      end
   end
})


minetest.register_chatcommand("cti", {
   params = "",
   description = "Citadella information mode",
   func = function(name, param)
      if param ~= "" then
         minetest.chat_send_player(name, "Error: Usage: /cti")
      else
         set_simple_mode(name, ct.PLAYER_MODE_INFO)
      end
   end
})


minetest.register_chatcommand("test", {
   params = "",
   description = "R3's test command",
   func = function(name, param)
      local player = minetest.get_player_by_name(name)
      if not player then
         return false
      end
      local pname = player:get_player_name()
      pm.register_player(param)
      return true
   end
})

-- XXX: documents say this isn't recommended, use node definition callbacks instead
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
      local pname = placer:get_player_name()
      -- If we're in /ctf mode
      if ct.player_modes[pname] == ct.PLAYER_MODE_FORTIFY then
         local current_reinf_group = ct.player_current_reinf_group[pname]
         local current_reinf_material = ct.player_fortify_material[pname]

         local required_item = ItemStack({
               name = current_reinf_material,
               count = 1
         });

         local inv = placer:get_inventory()

         -- Ensure player has the required item to create the reinforcemnt
         if inv:contains_item("main", required_item) then
            local resource_limit = ct.resource_limits[current_reinf_material]

            ct.register_reinforcement(pos, current_reinf_group.id,
                                      current_reinf_material, resource_limit)

            minetest.chat_send_player(
               pname,
               "Reinforced placed block (" .. vtos(pos) .. ") with "
                  .. current_reinf_material .. " (" .. tostring(resource_limit)
                  .. ") (group: '" .. current_reinf_group.name .. "')."
            )

            inv:remove_item("main", required_item)
         else
            minetest.chat_send_player(
               pname,
               "Inventory has no more " .. current_reinf_material .. "."
            )
            set_simple_mode(pname, ct.PLAYER_MODE_NORMAL)
         end
      end
end)


minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
      local pname = puncher:get_player_name()
      -- If we're in /ctr mode
      if ct.player_modes[pname] == ct.PLAYER_MODE_REINFORCE then
         local current_reinf_group = ct.player_current_reinf_group[pname]
         local item = puncher:get_wielded_item()
         -- If we punch something with a reinforcement item
         local item_name = item:get_name()
         local resource_limit = ct.resource_limits[item_name]
         if resource_limit then
            local reinf = ct.get_reinforcement(pos)
            if not reinf then
               -- Remove item from player's wielded stack
               item:take_item()
               puncher:set_wielded_item(item)
               -- Set node's reinforcement value to the default for this material
               ct.register_reinforcement(
                  pos, current_reinf_group.id, item_name, resource_limit
               )
               minetest.chat_send_player(
                  pname,
                  "Reinforced block ("..vtos(pos)..") with " .. item_name ..
                     " (" .. tostring(resource_limit) .. ") (group: '" ..
                     current_reinf_group.name .. "')."
               )
            else
               minetest.chat_send_player(pname, "Block is already reinforced: " .. reinf.material ..
                                            " (" .. tostring(reinf.value) .. ")")
            end
         end
      elseif ct.player_modes[pname] == ct.PLAYER_MODE_INFO then
         local reinf = ct.get_reinforcement(pos)
         if reinf then
            -- TODO: this code keeps getting duplicated...
            local player_id = pm.get_player_by_name(pname).id
            local player_groups = pm.get_groups_for_player(player_id)
            local reinf_ctgroup_id = reinf.ctgroup_id
            local group_name = nil

            for _, group in ipairs(player_groups) do
               if reinf_ctgroup_id == group.id then
                  group_name = group.name
                  break
               end
            end

            local group_string = ""
            if group_name then
               group_string = " on group '" .. group_name .. "'"
            end

            minetest.chat_send_player(
               pname,
               "Block (" .. vtos(pos) ..") is reinforced" .. group_string
                  ..  " with " .. reinf.material
                  .. " (" .. tostring(reinf.value) .. "/"
                  .. tostring(ct.resource_limits[reinf.material]) .. ")."
            )
         end
      end
end)


-- TODO: don't completely clobber other plugin's protection
local is_protected_fn = minetest.is_protected

-- BLOCK-BREAKING, /ctb
function minetest.is_protected(pos, pname, action)
   if action ~= minetest.DIG_ACTION then
      return false
   end
   local reinf = ct.get_reinforcement(pos)
   if not reinf then
      return false
   end
   -- Handle people with protection_bypass privilege
   local privs = minetest.get_player_privs(pname)
   if privs.protection_bypass then
      local c = minetest.colorize
      minetest.chat_send_player(
         pname,
         c("#e00",
           "WARNING: you have privilege: protection_bypass. "
              .. "Block's reinforcement was bypassed!")
      )
      ct.modify_reinforcement(pos, 0)
      return false
   end

   if ct.player_modes[pname] == ct.PLAYER_MODE_BYPASS then
      -- Figure out if player is in the block's reinf group
      -- TODO: this code keeps getting duplicated...
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
         local refund_item_name = reinf.material
         local refund_item = ItemStack({
               name = refund_item_name,
               count = 1
         })
         -- set reinforcement value to zero
         ct.modify_reinforcement(pos, 0)

         local player = minetest.get_player_by_name(pname)
         local inv = player:get_inventory()
         if inv:room_for_item("main", refund_item) then
            inv:add_item("main", refund_item)
            minetest.chat_send_player(
               pname,
               refund_item_name .. " refunded from bypassed reinforcement."
            )
         else
            minetest.chat_send_player(
               pname,
               "Warning: no inventory space for refunded reinforcement "
                  .. "material" .. refund_item_name
            )
         end

         return false
      else
         minetest.chat_send_player(pname, "You can't bypass this!")
         return true
      end
   else
      -- Decrement reinforcement
      local remaining = ct.modify_reinforcement(pos, reinf.value - 1)
      if remaining > 0 then
         minetest.chat_send_player(
            pname,
            "Block reinforcement remaining: " .. tostring(remaining)
         )
         return true
      else
         return false
      end
   end

end

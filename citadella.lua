local db = ...

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

-- Stringifies a vector V, frequently used as a table key
--[[ USE dump(tab) TO STRINGIFY A TABLE ]]--
local function vtos(v)
   return tostring(v.x) .. ", " .. tostring(v.y) .. ", " .. tostring(v.z)
end


-- Mapping of Player -> Citadel mode
-- XXX: couldn't get player:set_properties working so this could be nicer
ct.player_modes = {}

-- Convert this to DB
ct.reinforced_nodes = {}

function ct.register_reinforcement(pos, player_name, item_name)
   -- Effectively a stub for the DB functionality
   local value = ct.resource_limits[item_name]
   ct.reinforced_nodes[vtos(pos)] = { group = player, player_name = player_name, value = value, material = item_name }
   -- res = assert(
   --    db:execute(
   --       string.format([[
   --        INSERT INTO reinforcement
   --        VALUES (%d, %d, %d, %d, '%s', '%s', NULL)]],
   --          pos.x, pos.y, pos.z,
   --          value,
   --          db:escape(item_name),
   --          db:escape(player_name))))
end


function ct.remove_reinforcement(pos)
   -- Effectively a stub for the DB functionality
   ct.reinforced_nodes[vtos(pos)] = nil
end


function ct.modify_reinforcement(pos, delta)
   local value = ct.reinforced_nodes[vtos(pos)].value
   if value < 1 then
      ct.remove_reinforcement(pos)
      return 0
   else
      ct.reinforced_nodes[vtos(pos)].value = value + delta
      return ct.reinforced_nodes[vtos(pos)].value
   end
end


function ct.get_reinforcement(pos)
   -- Effectively a stub for the DB functionality
   return ct.reinforced_nodes[vtos(pos)]
end


minetest.register_chatcommand("ctr", {
   params = "",
   description = "Citadella reinforce with material",
   func = function(name, param)
      local player = minetest.get_player_by_name(name)
      if not player then
         return false
      end
      local pname = player:get_player_name()
      local current_pmode = ct.player_modes[pname]
      if current_pmode == nil or current_pmode ~= ct.PLAYER_MODE_REINFORCE then
         ct.player_modes[pname] = ct.PLAYER_MODE_REINFORCE
      else
         ct.player_modes[pname] = ct.PLAYER_MODE_NORMAL
      end
      minetest.chat_send_player(pname, "Citadella mode: " .. ct.player_modes[pname])
      return true
   end
})

-- gross duplicated code
minetest.register_chatcommand("ctb", {
   params = "",
   description = "Citadella bypass owned reinforcements",
   func = function(name, param)
      local player = minetest.get_player_by_name(name)
      if not player then
         return false
      end
      local pname = player:get_player_name()
      local current_pmode = ct.player_modes[pname]
      if current_pmode == nil or current_pmode ~= ct.PLAYER_MODE_BYPASS then
         ct.player_modes[pname] = ct.PLAYER_MODE_BYPASS
      else
         ct.player_modes[pname] = ct.PLAYER_MODE_NORMAL
      end
      minetest.chat_send_player(pname, "Citadella mode: " .. ct.player_modes[pname])
      return true
   end
})

-- gross duplicated code, but less so
minetest.register_chatcommand("cto", {
   params = "",
   description = "Citadella reset player mode",
   func = function(name, param)
      local player = minetest.get_player_by_name(name)
      if not player then
         return false
      end
      local pname = player:get_player_name()
      ct.player_modes[pname] = ct.PLAYER_MODE_NORMAL
      return true
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


-- TODO: CTF
-- XXX: documents say this isn't recommended, use node definition callbacks instead
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)

end)


-- /CTR block reinforce functionality
minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
      local pname = puncher:get_player_name()
      -- If we're in /ctr mode
      if ct.player_modes[pname] == ct.PLAYER_MODE_REINFORCE then
         local item = puncher:get_wielded_item()
         -- If we punch something with a reinforcement item
         local item_name = item:get_name()
         local resource_limit = ct.resource_limits[item_name]
         if resource_limit ~= nil then
            local reinf = ct.get_reinforcement(pos)
            if reinf == nil then
               -- Remove item from player's wielded stack
               item:take_item()
               puncher:set_wielded_item(item)
               -- Set node's reinforcement value to the default for this material
               ct.register_reinforcement(pos, pname, item_name)
               minetest.chat_send_player(
                  pname,
                  "Reinforced block ("..vtos(pos)..") with " .. item_name ..
                     " (" .. tostring(resource_limit) .. ")"
               )
            else
               minetest.chat_send_player(pname, "Block is already reinforced: " .. reinf.material ..
                                            " (" .. tostring(reinf.value) .. ")")
            end
         end
      end
end)


-- TODO: don't completely clobber other plugin's protection
local is_protected_fn = minetest.is_protected

-- BLOCK-BREAKING, /ctb
function minetest.is_protected(pos, pname)
   local reinf = ct.get_reinforcement(pos)
   if reinf then
      if ct.player_modes[pname] == ct.PLAYER_MODE_BYPASS
      and reinf.player_name == pname then
         ct.remove_reinforcement(pos)
         -- TODO: player may want the reinforcement material back :)
         return false
      else
         -- Decrement reinforcement
         local remaining = ct.modify_reinforcement(pos, -1)
         if remaining > 0 then
            minetest.chat_send_player(
               pname,
               "Block reinforcement remaining: " .. tostring(remaining)
            )
         end
         return true
      end
   end
end

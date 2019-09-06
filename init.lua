
local stone_limit = tonumber(minetest.settings:get("stone_limit")) or 25
local iron_limit = tonumber(minetest.settings:get("iron_limit")) or 250
local diamond_limit = tonumber(minetest.settings:get("diamond_limit")) or 1800

--[[

init.lua

Entrypoint to this plugin.

--]]

do
   local modpath = minetest.get_modpath(minetest.get_current_modname())
   dofile(modpath .. "/db.lua")
   dofile(modpath .. "/playermanager.lua")
end

local resource_limits = {
   ["default:stone"]   = stone_limit,
   ["default:iron"]    = iron_limit,
   ["default:diamond"] = diamond_limit
}

local PLAYER_MODE_NORMAL = "normal"
local PLAYER_MODE_REINFORCE = "reinforce"
local PLAYER_MODE_BYPASS = "bypass"

minetest.debug("Citadella initialised")


-- Stringifies a vector V, frequently used as a table key
--[[ USE dump(tab) TO STRINGIFY A TABLE ]]--
local function vtos(v)
   return tostring(v.x) .. ", " .. tostring(v.y) .. ", " .. tostring(v.z)
end


-- Mapping of Player -> Citadel mode
-- XXX: couldn't get player:set_properties working so this could be nicer
local player_modes = {}

-- Convert this to DB
local reinforced_nodes = {}


local function register_reinforcement(pos, player_name, item_name)
   -- Effectively a stub for the DB functionality
   local value = resource_limits[item_name]
   -- reinforced_nodes[vtos(pos)] = { group = player, player_name = player_name, value = value, material = item_name }
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


local function remove_reinforcement(pos)
   -- Effectively a stub for the DB functionality
   reinforced_nodes[vtos(pos)] = nil
end


local function modify_reinforcement(pos, delta)
   local value = reinforced_nodes[vtos(pos)].value
   if value < 1 then
      remove_reinforcement(pos)
      return 0
   else
      reinforced_nodes[vtos(pos)].value = value + delta
      return reinforced_nodes[vtos(pos)].value
   end
end


local function get_reinforcement(pos)
   -- Effectively a stub for the DB functionality
   return reinforced_nodes[vtos(pos)]
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
            local current_pmode = player_modes[pname]
            if current_pmode == nil or current_pmode ~= PLAYER_MODE_REINFORCE then
               player_modes[pname] = PLAYER_MODE_REINFORCE
            else
               player_modes[pname] = PLAYER_MODE_NORMAL
            end
            minetest.chat_send_player(pname, "Citadella mode: " .. player_modes[pname])
            return true
          end,
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
            local current_pmode = player_modes[pname]
            if current_pmode == nil or current_pmode ~= PLAYER_MODE_BYPASS then
               player_modes[pname] = PLAYER_MODE_BYPASS
            else
               player_modes[pname] = PLAYER_MODE_NORMAL
            end
            minetest.chat_send_player(pname, "Citadella mode: " .. player_modes[pname])
            return true
          end,
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
            player_modes[pname] = PLAYER_MODE_NORMAL
            return true
          end,
})

-- TODO: CTF
-- XXX: documents say this isn't recommended, use node definition callbacks instead
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)

end)


-- /CTR block reinforce functionality
minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
      local pname = puncher:get_player_name()
      -- If we're in /ctr mode
      if player_modes[pname] == PLAYER_MODE_REINFORCE then
         local item = puncher:get_wielded_item()
         -- If we punch something with a reinforcement item
         local item_name = item:get_name()
         local resource_limit = resource_limits[item_name]
         if resource_limit ~= nil then
            local reinf = get_reinforcement(pos)
            if reinf == nil then
               -- Remove item from player's wielded stack
               item:take_item()
               puncher:set_wielded_item(item)
               -- Set node's reinforcement value to the default for this material
               register_reinforcement(pos, pname, item_name)
               minetest.chat_send_player(pname, "Reinforced block (" .. vtos(pos) .. ") with " ..
                                            item_name .. " (" .. tostring(resource_limit) .. ")")
            else
               minetest.chat_send_player(pname, "Block is already reinforced: " .. reinf.material ..
                                            " (" .. tostring(reinf.value) .. ")")
            end
         end
      end
end)


-- BLOCK-BREAKING, /ctb
function minetest.is_protected(pos, pname)
   local reinf = get_reinforcement(pos)
   if reinf ~= nil then
      if player_modes[pname] == PLAYER_MODE_BYPASS
      and reinf.player_name == pname then
         remove_reinforcement(pos)
         -- TODO: player may want the reinforcement material back :)
         return false
      else
         -- Decrement reinforcement
         local remaining = modify_reinforcement(pos, -1)
         if remaining > 0 then
            minetest.chat_send_player(pname, "Block reinforcement remaining: " .. tostring(remaining))
         end
         return true
      end
   end
end

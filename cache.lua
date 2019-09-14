
-- Implementation of a reinforcement cache

local chunk_size = 16

local function coord_chunk(n)
   return math.floor(n / chunk_size) * chunk_size
end

local function get_pos_chunk(pos)
   return vector.new(
      coord_chunk(pos.x),
      coord_chunk(pos.y),
      coord_chunk(pos.z)
   )
end

--[[
cache:
  chunk coords --> block coords --> reinforcement
]]--

local chunk_reinf_cache = {}
local cache_chunk_expiry = 10 -- debug, can be set to 60+

function ct.try_flush_cache()
   local current_time = os.time(os.date("!*t"))
   for key, chunk in pairs(chunk_reinf_cache) do
      if (chunk.time_added + cache_chunk_expiry) < current_time then
         -- minetest.chat_send_all("Flushing chunk (" .. key .. ") to db:")
         for _, reinf in pairs(chunk.reinforcements) do
            local value = reinf.value
            local x, y, z = reinf.x, reinf.y, reinf.z
            if reinf.new then
               -- minetest.chat_send_all("  Registered: (" .. ptos(x, y, z) .. ")")
               ctdb.register_reinforcement(
                  vector.new(x, y, z),
                  reinf.ctgroup_id,
                  reinf.material
               )
               reinf.new = false
            end
            if value == 0 then
               -- minetest.chat_send_all("  Removed: (" .. ptos(x, y, z) .. ")")
               ctdb.remove_reinforcement(x, y, z)
            else
               -- minetest.chat_send_all("  Updated: (" .. ptos(x, y, z) .. ")")
               ctdb.update_reinforcement(
                  vector.new(x, y, z),
                  value
               )
            end
         end
         chunk_reinf_cache[key] = nil
      end
   end
end


function ct.chunk_ensure_cached(pos)
   local vchunk_start = get_pos_chunk(pos)
   local vchunk_end = vector.add(vchunk_start, chunk_size)

   local chunk_reinf = chunk_reinf_cache[vtos(vchunk_start)]
   if not chunk_reinf then
      ctdb.get_reinforcements_for_cache(
         chunk_reinf_cache,
         vchunk_start,
         vchunk_end
      )
   end
end


function ct.get_reinforcement(pos)
   ct.try_flush_cache()
   ct.chunk_ensure_cached(pos)
   local vchunk_start = get_pos_chunk(pos)
   local chunk_reinf = chunk_reinf_cache[vtos(vchunk_start)] or
      error("chunk didn't load into cache!!")
   return chunk_reinf.reinforcements[vtos(pos)]
end


function ct.modify_reinforcement(pos, delta)
   local reinf = ct.get_reinforcement(pos)
   reinf.value = reinf.value + delta
   return reinf.value
end


function ct.register_reinforcement(pos, ctgroup_id, item_name, resource_limit)
   local reinf = ct.get_reinforcement(pos)
   if not reinf then
      local vchunk = get_pos_chunk(pos)
      chunk_reinf_cache[vtos(vchunk)].reinforcements[vtos(pos)] = {
         x = pos.x, y = pos.y, z = pos.z,
         value = resource_limit,
         material = item_name,
         ctgroup_id = ctgroup_id,
         new = true
      }
   end
end

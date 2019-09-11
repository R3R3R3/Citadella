
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

function ct.get_reinforcement(pos)
   local vchunk_start = get_pos_chunk(pos)
   local vchunk_end = vector.add(vchunk_start, chunk_size)
   local chunk_reinf = chunk_reinf_cache[vtos(vchunk_start)]
   if not chunk_reinf then
      ctdb.get_reinforcements_for_cache(
         chunk_reinf_cache,
         vchunk_start,
         vchunk_end
      )
      chunk_reinf = chunk_reinf_cache[vtos(vchunk_start)] or
         error("chunk didn't load into cache!!")
   end
   return chunk_reinf.reinforcements[vtos(pos)]
end

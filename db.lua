--[[

Database connection functionality via PostgreSQL.

`luarocks install luasql-postgres`

]]--

-- TODO: other mods shouldn't be able to hijack our database connection

local ie = minetest.request_insecure_environment() or
   error("Mod requires decreased security settings in minetest.conf")

local driver = ie.require("luasql.postgres")
local db = nil
local env = nil

local function prep_db()
   env = assert (driver.postgres())
   -- connect to data source
   db = assert (env:connect("citadella", "mt"))


   -- group table, named ctgroup because heck quoted table names
   res = assert (db:execute[[
     CREATE TABLE IF NOT EXISTS ctgroup (
         id VARCHAR(32) NOT NULL,
         name VARCHAR(16) NOT NULL,
         description VARCHAR(128),
         creation_date TIMESTAMP NOT NULL,
         PRIMARY KEY (id),
         UNIQUE (name)
     )]])

   -- create reinforcements table
   res = assert (db:execute[[
     CREATE TABLE IF NOT EXISTS reinforcement (
         x INTEGER NOT NULL,
         y INTEGER NOT NULL,
         z INTEGER NOT NULL,
         value INTEGER NOT NULL,
         material VARCHAR(50) NOT NULL,
         ctgroup_id VARCHAR(32) REFERENCES ctgroup(id),
         PRIMARY KEY (x, y, z)
     )]])

   -- player table
   res = assert (db:execute[[
     CREATE TABLE IF NOT EXISTS player (
         id VARCHAR(32) NOT NULL,
         name VARCHAR(16) NOT NULL,
         join_date TIMESTAMP NOT NULL,
         PRIMARY KEY (id),
         UNIQUE (name)
     )]])

   -- maps players to groups/groups to players
   -- TODO: sort of permissions, keep basic for now
   res = assert (db:execute[[
     CREATE TABLE IF NOT EXISTS player_ctgroup (
         player_id varchar(32) REFERENCES player(id),
         ctgroup_id varchar(32) REFERENCES ctgroup(id),
         permission varchar(32) NOT NULL,
         PRIMARY KEY (player_id, ctgroup_id)
     )]])
end


prep_db()


minetest.register_on_shutdown(function()
   db:close()
   env:close()
end)

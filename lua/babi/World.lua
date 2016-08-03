-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local List = require 'pl.List'
local tablex = require 'pl.tablex'

local babi = require 'babi._env'
local actions = require 'babi.actions'
local utilities = require 'babi.utilities'

local World = torch.class('babi.World', babi)

function World:__init(entities, world_actions)
    self.entities = entities or {}
    if not self.entities['god'] then
        self:create_entity('god', {is_god = true})
    end
    self.actions = world_actions or actions
end

function World:god()
    return self.entities['god']
end

-- Load world from text file
function World:load(fname)
    local f = assert(io.open(fname))
    while true do
        local line = f:read('*l')
        if not line then break end
        if line ~= '' and line:sub(1, 1) ~= '#' then
            self:perform_command('god ' .. line)
        end
    end
end

-- Perform a textual command of the form 'john eat apple'
function World:perform_command(command)
    local function parse(actor, action, ...)
        actor = self.entities[actor] or error('actor not found', 2)
        local args = {}
        for _, arg in ipairs{...} do
            -- Try and resolve as entity, otherwise keep the string
            args[#args + 1] = self.entities[arg] or arg
        end
        return actor, action, args
    end
    local actor, action, args = parse(unpack(utilities.split(command)))
    self:perform_action(action, actor, unpack(args))
end

function World:perform_action(action, actor, ...)
    local clause = babi.Clause(self, true, actor, actions[action], ...)
    clause:perform()
end

-- Create a new entity in the world
function World:create_entity(id, properties, name)
    name = name or id
    if self.entities[id] then
        error('id already exists', 2)
    end
    self.entities[id] = babi.Entity(name, properties)
    return self.entities[id]
end

-- Some helper functions to retrieve entities
function World:get(predicate)
    return List(tablex.filter(
        tablex.values(self.entities), predicate
    ))
end

function World:get_actors()
    return List(tablex.filter(
        tablex.values(self.entities),
        function(entity) return entity.is_actor and entity.is_god end
    ))
end

function World:get_locations()
    return List(tablex.filter(
        tablex.values(self.entities),
        function(entity) return entity.is_location end
    ))
end

function World:get_objects()
    return List(tablex.filter(
        tablex.values(self.entities),
        function(entity) return entity.is_thing and entity.is_gettable end
    ))
end

return World

-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.


local class = require 'class'

local Set = require 'pl.Set'

local actions = require 'babi.actions'
local Task = require 'babi.Task'
local World = require 'babi.World'
local Question = require 'babi.Question'
local Clause = require 'babi.Clause'

local BasicCoreference = class('BasicCoreference', 'Task')

function BasicCoreference:new_world()
    local world = World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_basic.txt')
    return world
end

function BasicCoreference:generate_story(world, knowledge, story)
    -- Find the actors and the locations in the world
    local actors = world:get_actors()
    local locations = world:get_locations()

    -- Our story will be 2 statements, 1 question, 5 times
    for i = 1, 5 do
        -- Find a random action
        local clause = Clause.sample_valid(world, {true}, actors,
                                           {actions.teleport}, locations)
        clause:perform()
        story[i * 3 - 2] = clause
        knowledge:update(clause)

        -- Find coreference clause
        local coref_clause = Clause.sample_valid(world, {true}, {clause.actor},
                                                 {actions.teleport}, locations)
        coref_clause:perform()
        story[i * 3 - 1] = coref_clause
        knowledge:update(coref_clause)

        -- Pick a random one and ask where he/she is
        story[i * 3] = Question(
            'eval',
            Clause(world, true, world:god(), actions.set,
                   clause.actor, 'is_in', coref_clause.args[1]),
            Set{coref_clause}
        )
    end
    return story, knowledge
end

BasicCoreference.DEFAULT_CONFIG = {
    coreference=1.0
}

return BasicCoreference

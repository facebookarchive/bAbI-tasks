-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.


local class = require 'class'

local List = require 'pl.List'

local actions = require 'babi.actions'
local Task = require 'babi.Task'
local World = require 'babi.World'
local Question = require 'babi.Question'
local Clause = require 'babi.Clause'
local utilities = require 'babi.utilities'

local Conjunction = class('Conjunction', 'Task')

function Conjunction:new_world()
    local world = World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_basic.txt')
    return world
end

function Conjunction:generate_story(world, knowledge, story)
    -- Find the actors and the locations in the world
    local actors = world:get_actors()
    local locations = world:get_locations()

    -- Our story will be 2 statements, 1 question, 5 times
    for i = 1, 5 do
        -- Select two actors and two locations
        local clauses = List()
        local random_actors = utilities.choice(actors, 2)
        random_actors:extend(utilities.choice(actors, 2))
        local random_locations = utilities.choice(locations, 2)

        clauses:append(Clause(world, true, random_actors[1],
                              actions.teleport, random_locations[1]))
        clauses:append(Clause(world, true, random_actors[2],
                              actions.teleport, random_locations[1]))
        clauses:append(Clause(world, true, random_actors[3],
                              actions.teleport, random_locations[2]))
        clauses:append(Clause(world, true, random_actors[4],
                              actions.teleport, random_locations[2]))

        for _, clause in pairs(clauses) do
            clause:perform()
            knowledge:update(clause)
        end
        story:extend(clauses)

        -- Pick a random actor and ask where he/she is
        local random_actor = random_actors[math.random(4)]
        local value, support =
            knowledge:current()[random_actor]:get_value('is_in', true)
        story:append(Question(
            'eval',
            Clause(world, true, world:god(), actions.set,
                   random_actor, 'is_in', value),
            support
        ))
    end
    return story, knowledge
end

Conjunction.DEFAULT_CONFIG = {conjunction=1.0}


return Conjunction

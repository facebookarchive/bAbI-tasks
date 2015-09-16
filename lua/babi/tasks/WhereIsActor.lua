-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.


local class = require 'class'

local tablex = require 'pl.tablex'

local actions = require 'babi.actions'
local Task = require 'babi.Task'
local World = require 'babi.World'
local Question = require 'babi.Question'
local Clause = require 'babi.Clause'

local WhereIsActor = class('WhereIsActor', 'Task')

function WhereIsActor:new_world()
    local world = World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_basic.txt')
    return world
end

function WhereIsActor:generate_story(world, knowledge, story)
    -- Find the actors and the locations in the world
    local actors = world:get_actors()
    local locations = world:get_locations()

    -- Our story will be 2 statements, 1 question, 5 times
    for i = 1, 15 do
        if i % 3 ~= 0 then
            -- Find a random action
            local clause = Clause.sample_valid(world, {true}, actors,
                                               {actions.teleport}, locations)
            clause:perform()
            story[i] = clause
            knowledge:update(clause)
        else
            -- Find the actors of which we know the location
            local known_actors = tablex.filter(
                knowledge:current():find('is_in'),
                function(entity) return entity.is_actor end
            )

            -- Pick a random one and ask where he/she is
            local random_actor = known_actors[math.random(#known_actors)]
            local value, support =
                knowledge:current()[random_actor]:get_value('is_in', true)
            story[i] = Question(
                'eval',
                Clause(world, true, world:god(), actions.set,
                       random_actor, 'is_in', value),
                support
            )
        end
    end
    return story, knowledge
end

return WhereIsActor

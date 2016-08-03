-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local Set = require 'pl.Set'

local babi = require 'babi'
local actions = require 'babi.actions'

local Motivations = torch.class('babi.Motivations', 'babi.Task', babi)

function Motivations:new_world()
    local world = babi.World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_motivations.txt')
    -- Randomly assign motivations to people
    local actors = world:get_actors()
    local motivations =
        world:get(function(entity) return entity.is_motivation end)
    local assignments = torch.randperm(#actors):totable()
    for i = 1, #actors do
        actors[i].mental_state = motivations[assignments[i]]
    end
    return world
end

function Motivations:generate_story(world, knowledge, story)
    -- Find the actors and the locations in the world
    local actors = world:get_actors()

    -- For each actor: state mental state, moves to destination, grabs object
    local counter = {}
    for i = 1, #actors do
        counter[i] = 0
    end

    -- Keep track of when we said what about an actor
    local mapping = {}
    for i = 1, #actors do
        mapping[i] = {}
    end

    for i = 1, 12 do
        -- Select an actor that has actions left
        local j
        repeat
            j = math.random(#actors)
        until counter[j] < 6
        counter[j] = counter[j] + 1

        -- Make it do the correct action
        if counter[j] == 1 then
            story:append(babi.Clause(world, true, world:god(), actions.set,
                actors[j], 'is', actors[j].mental_state))
        elseif counter[j] == 3 then
            story:append(babi.Clause(world, true, actors[j], actions.teleport,
                actors[j].mental_state.destination))
        elseif counter[j] == 5 then
            story:append(babi.Clause(world, true, actors[j], actions.get,
                actors[j].mental_state.object))
        end
        mapping[j][counter[j]] = #story

        -- Select an actor about which we can ask a new question
        repeat
            j = math.random(#actors)
        until counter[j] % 2 == 1
        counter[j] = counter[j] + 1

        -- Ask the question
        story:append(babi.Question(
            counter[j] > 2 and 'why' or 'whereto',
            {story[mapping[j][counter[j] -1]], actors[j].mental_state},
            Set{story[mapping[j][1]]}
        ))
    end
    return story, knowledge
end

return Motivations

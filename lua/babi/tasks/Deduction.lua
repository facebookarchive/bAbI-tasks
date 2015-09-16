-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.



local class = require 'class'

local tablex = require 'pl.tablex'
local Set = require 'pl.Set'

local actions = require 'babi.actions'
local Task = require 'babi.Task'
local World = require 'babi.World'
local Question = require 'babi.Question'
local Clause = require 'babi.Clause'
local utilities = require 'babi.utilities'

local Deduction = class('Deduction', 'Task')

function Deduction:new_world()
    local world = World()
    for _, animal in pairs{{'mouse', 'mice'}, {'sheep', 'sheep'},
                           {'wolf', 'wolves'}, {'cat', 'cats'}} do
        world:create_entity(animal[1], {is_animal=true, plural=animal[2]})
    end
    for _, actor in pairs{'Gertrude', 'Winona', 'Jessica', 'Emily'} do
        world:create_entity(actor, {is_actor=true, is_god=true})
    end
    return world
end

function Deduction:generate_story(world, knowledge, story)
    -- Find the actors and the locations in the world
    local actors = world:get_actors()
    local animals = world:get(function(entity) return entity.is_animal end)

    local assignments = torch.randperm(#actors):totable()
    local afraid_of = {}
    for i, _ in ipairs(animals) do
        repeat
            local j = math.random(#animals)
            afraid_of[i] = j
        until j ~= i
    end

    for i, j in ipairs(assignments) do
        story[i] = Clause(world, true, world:god(), actions.set, actors[i],
                         'is', animals[j])
    end
    for i, j in ipairs(afraid_of) do
        story[i + #actors] = Clause(world, true, world:god(), actions.set,
                                    animals[i], 'has_fear', animals[j])
    end
    for i = 1, #actors do
        story[i + 2 * #actors] = Question(
            'eval',
            Clause(world, true, world:god(), actions.set,
                   actors[i], 'has_fear', animals[afraid_of[assignments[i]]]),
            Set{story[i], story[assignments[i] + #actors]}
        )
    end
    local shuffled_story = utilities.choice(story:slice(1, 2 * #actors), 2 * #actors)
    shuffled_story:extend(utilities.choice(story:slice(2 * #actors + 1), #actors))

    return shuffled_story, knowledge
end

return Deduction

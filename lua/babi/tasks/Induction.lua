-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local tablex = require 'pl.tablex'
local List = require 'pl.List'
local Set = require 'pl.Set'

local babi = require 'babi'
local actions = require 'babi.actions'
local utilities = require 'babi.utilities'

local Deduction = torch.class('babi.Deduction', 'babi.Task', babi)

function Deduction:new_world()
    local world = babi.World()
    for _, animal in pairs{'swan', 'lion', 'frog', 'rhino'} do
        world:create_entity(animal, {is_animal=true})
    end
    for _, color in pairs{'gray', 'white', 'yellow', 'green'} do
        world:create_entity(color, {is_color=true})
    end
    for _, actor in pairs{'Lily', 'Bernhard', 'Greg', 'Julius', 'Brian'} do
        world:create_entity(actor, {is_actor=true, is_god=true})
    end
    return world
end

function Deduction:generate_story(world, knowledge, story)
    -- Find the actors and the locations in the world
    local actors = world:get_actors()
    local animals = world:get(function(entity) return entity.is_animal end)
    local colors = world:get(function(entity) return entity.is_color end)

    -- Map animals to colors
    local animal_colors = torch.randperm(#animals):totable()
    -- Map actors to animals
    local actor_animals = {}
    for i, _ in ipairs(actors) do
        actor_animals[i] = math.random(#animals)
    end
    -- Make sure that induction can be performed
    local question = math.random(#actors)
    while true do
        if List(
            tablex.values(actor_animals)):count(actor_animals[question]
        ) > 1 then
            break
        else
            actor_animals[question] = math.random(#animals)
        end
    end

    for i = 1, #actors do
        story[i] = babi.Clause(world, true, world:god(), actions.set,
            actors[i], 'has_color', colors[animal_colors[actor_animals[i]]])
    end
    for i = 1, #actors do
        story[i + #actors] = babi.Clause(world, true, world:god(), actions.set,
            actors[i], 'is', animals[actor_animals[i]])
    end
    local support = Set()
    for i = 1, #actors do
        if i ~= question and actor_animals[i] == actor_animals[question] then
            support = support + Set{story[i], story[#actors + i]}
        elseif i == question then
            support = support + Set{story[#actors + i]}
        end
    end
    story[question] = babi.Question(
        'eval', story[question], support
    )
    story[#story], story[question] = story[question], story[#story]
    local shuffled_story =
        utilities.choice(story:slice(1, #story - 1), #story - 1)
    shuffled_story:append(story[#story])

    return shuffled_story, knowledge
end

return Deduction

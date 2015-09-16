-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.


local class = require 'class'

local Set = require 'pl.Set'
local List = require 'pl.List'
local tablex = require 'pl.tablex'

local actions = require 'babi.actions'
local Task = require 'babi.Task'
local World = require 'babi.World'
local Question = require 'babi.Question'
local Clause = require 'babi.Clause'

local Counting = class('Counting', 'Task')

function Counting:new_world()
    local world = World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_basic.txt')
    return world
end

function Counting:generate_story(world, knowledge, story)
    -- Our story will be 2 statements, 1 question, 5 times
    local allowed_actions = {actions.get, actions.give, actions.teleport, actions.drop}
    local actors = world:get_actors()
    local known_actors = Set()
    local support = {}
    for i = 1, #actors do
        support[actors[i]] = List()
    end
    local i = 0
    local first_question
    while not first_question or i - first_question < 8 do
        -- Find a random action
        local clause
        while not clause do
            local random_action =
                allowed_actions[math.random(#allowed_actions)]
            if class.istype(random_action, 'Teleport') then
                clause = Clause.sample_valid(
                    world, {true}, world:get_actors(),
                    {actions.teleport}, world:get_locations()
                )
            elseif class.istype(random_action, 'Get') then
                clause = Clause.sample_valid(
                    world, {true}, world:get_actors(),
                    {actions.get, actions.drop}, world:get_objects()
                )
                if clause then
                    known_actors = known_actors + Set{clause.actor}
                    support[clause.actor]:append(clause)
                end
            else
                clause = Clause.sample_valid(
                    world, {true}, world:get_actors(),
                    {actions.give}, world:get_objects(), world:get_actors()
                )
                if clause then
                    known_actors = known_actors + Set{clause.actor}
                    support[clause.actor]:append(clause)
                end
            end
        end
        i = i + 1
        clause:perform()
        story:append(clause)
        knowledge:update(clause)
        if (not first_question and i > 1 and Set.len(known_actors) > 0) or
                (first_question and (i - first_question) % 2 == 0) then
            first_question = first_question or i
            -- Pick a random actor and ask how many objects he/she is carrying
            local random_actor = tablex.keys(known_actors)[math.random(Set.len(known_actors))]
            local held_objects = List()
            for _, entity in pairs(world:get_objects()) do
                local value = knowledge:current()[entity]:get_value('is_in')
                if value == random_actor then
                    held_objects:append(entity)
                end
            end
            story:append(Question(
                'count',
                Clause(world, true, world:god(), actions.set, random_actor,
                       'holding', held_objects),
                Set(support[random_actor])
            ))
        end
    end
    return story, knowledge
end

return Counting

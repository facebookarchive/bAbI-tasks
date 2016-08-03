-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local Set = require 'pl.Set'
local List = require 'pl.List'
local tablex = require 'pl.tablex'

local babi = require 'babi'
local actions = require 'babi.actions'

local Counting = torch.class('babi.Counting', 'babi.Task', babi)

function Counting:new_world()
    local world = babi.World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_basic.txt')
    return world
end

function Counting:generate_story(world, knowledge, story)
    -- Our story will be 2 statements, 1 question, 5 times
    local allowed_actions = {
        actions.get, actions.give, actions.teleport, actions.drop
    }
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
            if torch.isTypeOf(random_action, 'babi.Teleport') then
                clause = babi.Clause.sample_valid(
                    world, {true}, world:get_actors(),
                    {actions.teleport}, world:get_locations()
                )
            elseif torch.isTypeOf(random_action, 'babi.Get') then
                clause = babi.Clause.sample_valid(
                    world, {true}, world:get_actors(),
                    {actions.get, actions.drop}, world:get_objects()
                )
                if clause then
                    known_actors = known_actors + Set{clause.actor}
                    support[clause.actor]:append(clause)
                end
            else
                clause = babi.Clause.sample_valid(
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
            local random_actor =
                tablex.keys(known_actors)[math.random(Set.len(known_actors))]
            local held_objects = List()
            for _, entity in pairs(world:get_objects()) do
                local value = knowledge:current()[entity]:get_value('is_in')
                if value == random_actor then
                    held_objects:append(entity)
                end
            end
            story:append(babi.Question(
                'count',
                babi.Clause(world, true, world:god(), actions.set, random_actor,
                       'holding', held_objects),
                Set(support[random_actor])
            ))
        end
    end
    return story, knowledge
end

return Counting

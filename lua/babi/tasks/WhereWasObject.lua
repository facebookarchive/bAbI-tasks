-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local List = require 'pl.List'

local babi = require 'babi'
local actions = require 'babi.actions'

local WhereWasObject = torch.class('babi.WhereWasObject', 'babi.Task', babi)

function WhereWasObject:new_world()
    local world = babi.World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_basic.txt')
    return world
end

function WhereWasObject:generate_story(world, knowledge, story)
    local num_questions = 0
    local story_length = 0

    local allowed_actions = {actions.get, actions.drop, actions.teleport}
    while num_questions < 5 do
        local clause
        while not clause do
            local random_action =
                allowed_actions[math.random(#allowed_actions)]
            if torch.isTypeOf(random_action, 'babi.Teleport') then
                clause = babi.Clause.sample_valid(
                    world, {true}, world:get_actors(),
                    {actions.teleport}, world:get_locations()
                )
            else
                clause = babi.Clause.sample_valid(
                    world, {true}, world:get_actors(),
                    {actions.get, actions.drop}, world:get_objects())
            end
        end
        story_length = story_length + 1
        clause:perform()
        story:append(clause)
        knowledge:update(clause)
        if story_length > 2 and math.random(2) < 2 then
            -- TODO Need to resolve is_in for held objects
            local known_objects = List()
            for id, entity in pairs(world:get_objects()) do
                local entity_history = knowledge:get_value_history(entity,
                                                                   'is_in')
                if #entity_history > 1 then
                    known_objects:append(entity)
                end
            end
            if #known_objects > 0 then
                local random_object =
                    known_objects[math.random(#known_objects)]
                local value_history, support_history =
                    knowledge:get_value_history(random_object, 'is_in', true)
                -- TODO Ask about history, but needs to be unambiguous
                story:append(babi.Question(
                    'before',
                    List{
                        babi.Clause(
                            world, true, world:god(), actions.set,
                            random_object, 'is_in',
                            value_history[#value_history - 1]
                        ),
                        babi.Clause(
                            world, true, world:god(), actions.set,
                            random_object, 'is_in',
                            value_history[#value_history]
                        ),
                    },
                    support_history[#support_history]
                    + support_history[#support_history - 1]
                ))

                story_length = 0
                num_questions = num_questions + 1
            end
        end
    end
    return story, knowledge
end

return WhereWasObject

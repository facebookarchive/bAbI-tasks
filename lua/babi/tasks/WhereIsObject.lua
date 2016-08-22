-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local tablex = require 'pl.tablex'

local babi = require 'babi'
local actions = require 'babi.actions'

local WhereIsObject = torch.class('babi.WhereIsObject', 'babi.Task', babi)

function WhereIsObject:new_world()
    local world = babi.World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_basic.txt')
    return world
end

function WhereIsObject:generate_story(world, knowledge, story)
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
                    {actions.get, actions.drop}, world:get_objects()
                )
            end
        end
        clause:perform()
        story:append(clause)
        knowledge:update(clause)
        story_length = story_length + 1

        if story_length > 2 and math.random(2) < 2 then
            local known_objects = tablex.filter(
                knowledge:current():find('is_in'),
                function(entity)
                    return entity.is_gettable and
                        knowledge:current()[entity.is_in]:get_value('is_in')
                end
            )

            -- If there are any objects we know the location of, ask question
            if #known_objects > 0 then
                local random_object =
                    known_objects[math.random(#known_objects)]
                local value, support =
                    knowledge:current()[random_object]:get_value('is_in', true)
                local _, holder_support =
                    knowledge:current()[random_object.is_in]:get_value('is_in',
                                                                       true)
                story:append(babi.Question(
                    'eval',
                    babi.Clause(world, true, world:god(), actions.set,
                        random_object, 'is_in', value.is_in),
                    support + holder_support
                ))

                story_length = 0
                num_questions = num_questions + 1
            end
        end
    end
    return story, knowledge
end

return WhereIsObject

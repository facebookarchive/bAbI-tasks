-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local List = require 'pl.List'
local Set = require 'pl.Set'

local babi = require 'babi'
local actions = require 'babi.actions'

local Negation = torch.class('babi.Negation', 'babi.Task', babi)

function Negation:new_world()
    local world = babi.World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_basic.txt')
    return world
end

function Negation:generate_story(world, knowledge, story)
    -- NOTE Largely copy-paste of WhereIsActor
    -- Find the actors and the locations in the world
    local actors = world:get_actors()
    local locations = world:get_locations()

    knowledge.exclusive['is_in'] = Set(locations)

    -- Our story will be 2 statements, 1 question, 5 times
    local allowed_actions = {actions.teleport, actions.set}
    local known_actors = List()
    for i = 1, 15 do
        if i % 3 ~= 0 then
            -- Find a random action
            local clause
            local actor
            while not clause do
                local random_action =
                    allowed_actions[math.random(#allowed_actions)]
                if torch.isTypeOf(random_action, 'babi.Teleport') then
                    clause = babi.Clause.sample_valid(
                        world, {true}, world:get_actors(),
                        {actions.teleport}, world:get_locations()
                    )
                    actor = clause.actor
                else
                    local affirmative = ({true, false})[math.random(2)]
                    actor = actors[math.random(#actors)]
                    local location
                    if affirmative then
                        location = actor.is_in
                    else
                        local options =
                            locations:clone():remove_value(actor.is_in)
                        location = options[math.random(#options)]
                    end
                    clause = babi.Clause(world, affirmative, world:god(),
                        actions.set, actor, 'is_in', location)
                end
            end
            if not known_actors:contains(actor) then
                known_actors:append(actor)
            end
            clause:perform()
            story:append(clause)
            knowledge:update(clause)
        else
            -- Pick an actor and ask whether he/she is in a particular location
            local random_actor = known_actors[math.random(#known_actors)]
            local options = knowledge:current()[random_actor]['is_in']
            local value = options[math.random(#options)]
            local truth_value, location = value.truth_value, value.value
            if truth_value and math.random(2) > 1 then
                local options = locations:clone():remove_value(location)
                location = options[math.random(#options)]
                truth_value = false
            end
            story:append(babi.Question(
                'yes_no',
                babi.Clause(world, truth_value, world:god(), actions.set,
                    random_actor, 'is_in', location),
                value.support
            ))
        end
    end
    return story, knowledge
end

return Negation

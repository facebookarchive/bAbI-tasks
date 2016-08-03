-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local Set = require 'pl.Set'

local babi = require 'babi'
local actions = require 'babi.actions'
local utilities = require 'babi.utilities'

local WhoWhatGave = torch.class('babi.WhoWhatGave', 'babi.Task', babi)

function WhoWhatGave:new_world()
    local world = babi.World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_basic.txt')
    return world
end

function WhoWhatGave:generate_story(world, knowledge, story)
    local num_questions = 0
    local story_length = 0

    local allowed_actions = {actions.get, actions.give, actions.teleport}
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
            elseif torch.isTypeOf(random_action, 'babi.Get') then
                clause = babi.Clause.sample_valid(
                    world, {true}, world:get_actors(),
                    {actions.get}, world:get_objects()
                )
            else
                clause = babi.Clause.sample_valid(
                    world, {true}, world:get_actors(),
                    {actions.give}, world:get_objects(), world:get_actors()
                )
            end
        end
        story_length = story_length + 1
        clause:perform()
        story:append(clause)
        knowledge:update(clause)
        if story_length > 2 and torch.isTypeOf(clause.action, 'babi.Give') then
            story = story
                :slice(1, -story_length - 1)
                :extend(
                    utilities.choice(story:slice(-story_length), story_length)
                )
            story:append(babi.Question('eval', clause, Set{clause}))
            num_questions = num_questions + 1
            story_length = 0
        end
    end
    return story, knowledge
end

return WhoWhatGave

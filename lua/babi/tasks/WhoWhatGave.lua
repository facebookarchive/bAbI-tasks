-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local Set = require 'pl.Set'

local babi = require 'babi'
local actions = require 'babi.actions'

local WhoWhatGave = torch.class('babi.WhoWhatGave', 'babi.Task', babi)

function WhoWhatGave:new_world()
    local world = babi.World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_basic.txt')
    return world
end

local function sample_clause(world)
    local allowed_actions = {actions.get, actions.give, actions.teleport}

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
    return clause
end

function WhoWhatGave:generate_story(world, knowledge, story)
    local num_questions = 0
    local story_length = 0

    while num_questions < 5 do
        local clause = sample_clause(world)
        story_length = story_length + 1
        clause:perform()
        story:append(clause)
        knowledge:update(clause)
        if story_length > 1 and torch.isTypeOf(clause.action, 'babi.Give') then
            -- we don't want the clause the question is about to be the most
            -- recent one, so sample a few more unrelated clauses first
            for i = 2, math.random(6) do -- 0 to 5 extra clauses
                local cls
                -- don't use any more stories about the same item, or
                -- about the same people exchanging any other item
                while not cls or cls.args[1] == clause.args[1] or
                (
                    cls.actor == clause.actor and
                    torch.isTypeOf(cls.action, 'babi.Give') and
                    cls.args[2] == clause.args[2]
                ) do
                    cls = sample_clause(world)
                end
                story:append(cls)
            end
            story:append(babi.Question('eval', clause, Set{clause}))
            num_questions = num_questions + 1
            story_length = 0
        end
    end
    return story, knowledge
end

return WhoWhatGave

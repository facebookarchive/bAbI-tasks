-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.


local class = require 'class'

local Set = require 'pl.Set'

local actions = require 'babi.actions'
local Task = require 'babi.Task'
local World = require 'babi.World'
local Question = require 'babi.Question'
local Clause = require 'babi.Clause'
local utilities = require 'babi.utilities'

local WhoWhatGave = class('WhoWhatGave', 'Task')

function WhoWhatGave:new_world()
    local world = World()
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
            if class.istype(random_action, 'Teleport') then
                clause = Clause.sample_valid(world, {true}, world:get_actors(),
                                             {actions.teleport},
                                             world:get_locations())
            elseif class.istype(random_action, 'Get') then
                clause = Clause.sample_valid(world, {true}, world:get_actors(),
                                             {actions.get},
                                             world:get_objects())
            else
                clause = Clause.sample_valid(world, {true}, world:get_actors(),
                                             {actions.give},
                                             world:get_objects(),
                                             world:get_actors())
            end
        end
        story_length = story_length + 1
        clause:perform()
        story:append(clause)
        knowledge:update(clause)
        if story_length > 2 and class.istype(clause.action, 'Give') then
            story = story:slice(1, -story_length - 1):extend(utilities.choice(story:slice(-story_length), story_length))
            story:append(Question('eval', clause, Set{clause}))
            num_questions = num_questions + 1
            story_length = 0
        end
    end
    return story, knowledge
end

return WhoWhatGave

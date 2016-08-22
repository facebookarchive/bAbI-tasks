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

do
    local EitherRule = torch.class('babi.EitherRule', 'babi.Rule', babi)

    function EitherRule:__init(actor, ...)
        self.actor = actor
        self.locations = List{...}
        self.applied = false
    end

    function EitherRule:is_applicable()
        -- This rule is only applied once
        if not self.applied then
            self.applied = true
            return true
        end
    end

    function EitherRule:update_knowledge(world, knowledge, clause)
        -- If the actor is (not) in one of two places, he's (not) in the other
        for i = 1, 2 do
            local truth_value, support =
                knowledge[self.actor]:get_truth_value('is_in',
                                                      self.locations[i],
                                                      true)
            if truth_value ~= nil then
                knowledge[self.actor]:add('is_in',
                                          self.locations[i % 2 + 1],
                                          not truth_value,
                                          Set{self} + support)
            end
        end
        for _, location in ipairs(world:get_locations()) do
            if not self.locations:contains(location) then
                knowledge[self.actor]:add('is_in', location, false, Set{self})
            end
        end
    end
end

local Indefinite = torch.class('babi.Indefinite', 'babi.Task', babi)

function Indefinite:new_world()
    local world = babi.World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_basic.txt')
    return world
end

function Indefinite:generate_story(world, knowledge, story)
    -- NOTE Largely copy-paste of WhereIsActor
    -- Find the actors and the locations in the world
    local actors = world:get_actors()
    local locations = world:get_locations()

    knowledge.exclusive['is_in'] = Set(locations)

    -- Our story will be 2 statements, 1 question, 5 times
    local allowed_actions = {actions.teleport, actions.set,
                             babi.EitherRule}
    local known_actors = List()
    local maybe_support = {}
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
                    knowledge:update(clause)
                elseif torch.isTypeOf(random_action, 'babi.SetProperty') then
                    actor = actors[math.random(#actors)]
                    clause = babi.Clause(world, true, world:god(),
                        actions.set, actor, 'is_in', actor.is_in)
                else
                    actor = actors[math.random(#actors)]
                    local options = locations:clone()
                    local location1 = options[math.random(#options)]
                    options = options:remove_value(location1)
                    local location2 = options[math.random(#options)]
                    clause = babi.EitherRule(actor, location1, location2)
                    maybe_support[actor] = clause
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
            local random_location = locations[math.random(#locations)]
            local truth_value, support =
                knowledge:current()[random_actor]
                    :get_truth_value('is_in', random_location, true)
            story:append(babi.Question(
                'yes_no',
                babi.Clause(world, truth_value, world:god(), actions.set,
                    random_actor, 'is_in', random_location),
                support or Set{maybe_support[random_actor]}
            ))
        end
    end
    return story, knowledge
end

return Indefinite

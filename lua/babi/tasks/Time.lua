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
local utilities = require 'babi.utilities'

local Time = torch.class('babi.Time', 'babi.Task', babi)

function Time:new_world()
    local world = babi.World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_basic.txt')
    return world
end

function Time:generate_story(world, knowledge, story)
    -- Find the actors and the locations in the world
    local actors = world:get_actors()
    local locations = world:get_locations()
    local times =
        {'yesterday', 'this morning', 'this afternoon', 'this evening'}
    local num_questions = 5

    local movements = {}
    for _, actor in pairs(actors) do
        movements[actor] = List()
        for i, _ in pairs(times) do
            movements[actor][i] = false
        end
    end

    -- Make sure we can answer at least one question
    local i, j = unpack(utilities.choice({1, 2, 3, 4}, 2))
    local first_locations = utilities.choice(locations, 2)
    local actor = actors[math.random(#actors)]
    local first_times = utilities.choice(List.range(4), 2)
    story[i] = babi.Clause(world, true, actor, actions.teleport,
        first_locations[1], 'when', times[first_times[1]])
    movements[actor][first_times[1]] = story[i]
    story[j] = babi.Clause(world, true, actor, actions.teleport,
        first_locations[2], 'when', times[first_times[2]])
    movements[actor][first_times[2]] = story[j]

    -- Fill the rest of the story with random movements
    for i = 1, num_questions * 3 + 2 do
        if i > 2 and (i - 2) % 3 == 0 then
            -- Question time, sample a question
            local actor, actor_movements, t
            repeat
                actor = actors[math.random(#actors)]
                actor_movements = movements[actor]:filter(function(clause)
                    return not not clause
                end)
                if #actor_movements > 1 then
                    t = math.random(#actor_movements - 1)
                end
            until t
            story[i] = babi.Question(
                'eval',
                babi.Clause(
                    world, true, world:god(), actions.set, actor, 'before',
                    actor_movements[t].args[1], actor_movements[t + 1].args[1]
                ),
                Set{actor_movements[t], actor_movements[t + 1]}
            )
        elseif not story[i] then
            local actor, time, location
            repeat
                actor = actors[math.random(#actors)]
                time = math.random(4)
                location = locations[math.random(#locations)]
                local has_visited = movements[actor]:map(
                    function(clause) return clause and clause.args[1] end
                ):contains(location)
            until not movements[actor][time] and not has_visited
            story[i] = babi.Clause(world, true, actor, actions.teleport,
                location, 'when', times[time])
            movements[actor][time] = story[i]
        end
    end
    return story, knowledge
end

return Time

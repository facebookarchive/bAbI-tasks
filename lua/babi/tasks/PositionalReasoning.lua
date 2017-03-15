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

local PositionalReasoning =
    torch.class('babi.PositionalReasoning', 'babi.Task', babi)
local DIRECTIONS = {{'w', 'e'}, {'n', 's'}}

function PositionalReasoning:new_world()
    local world = babi.World()
    for _, shape in pairs{'square', 'rectangle', 'triangle', 'sphere'} do
        for _, color in pairs{'red', 'blue', 'pink', 'yellow'} do
            world:create_entity(color .. ' ' .. shape, {shape=shape,
                                                        has_color=true,
                                                        color=color})
        end
        world:create_entity(shape, {shape=shape, has_color=false})
    end
    return world
end

function PositionalReasoning:generate_story(world, knowledge, story)
    local shapes = world:get(function(entity) return entity.shape end)

    -- Find 3 shapes that are not ambiguous (e.g. triangle and pink triangle)
    local num_shapes = 3
    local chosen_shapes = List()
    repeat
        local candidate = shapes[math.random(#shapes)]
        if not chosen_shapes:contains(candidate) then
            if candidate.has_color then
                chosen_shapes[#chosen_shapes + 1] = candidate
            else
                local ambiguous = false
                for i = 1, #chosen_shapes do
                    if chosen_shapes[i].shape == candidate.shape then
                        ambiguous = true
                    end
                end
                if not ambiguous then
                    chosen_shapes[#chosen_shapes + 1] = candidate
                end
            end
        end
    until #chosen_shapes == num_shapes

    -- Fill in the shapes on a grid
    local grid = utilities.Grid(5)
    local next_node = grid:center()
    local prev_node
    local i = 0
    local dir
    while i < num_shapes do
        if not grid.nodes[next_node] then
            i = i + 1
            grid:add_node(next_node, chosen_shapes[i])
            utilities.add_loc(grid, next_node, chosen_shapes[i], world)
            if i > 1 then
                story:append(babi.Clause(world, true, world:god(), actions.set,
                                    chosen_shapes[i - 1], dir,
                                    chosen_shapes[i]))
            end
            prev_node = next_node
        end
        dir = DIRECTIONS[math.random(2)][math.random(2)]
        next_node = grid:rel_node(prev_node, dir)
    end

    -- Now ask questions about the shapes
    for i = 1, 8 do
        local q1, q2 = unpack(torch.randperm(num_shapes):sub(1, 2):totable())
        local q1, q2 = chosen_shapes[q1], chosen_shapes[q2]
        local loc1, loc2 = grid.objects[q1], grid.objects[q2]
        local x1, y1 = grid:to_coordinates(loc1)
        local x2, y2 = grid:to_coordinates(loc2)
        local diff = {x1 - x2, y1 - y2}
        -- Ask question about x (1) or y (2) direction
        local q_dir = math.random(2 - (diff[1] ~= 0 and 1 or 0),
                                  1 + (diff[2] ~= 0 and 1 or 0))
        local q_truth = ({true, false})[math.random(2)]
        local q_dir_name = DIRECTIONS[q_dir][(q_truth and 1 or -1) *
                                             diff[q_dir] > 0 and 1 or 2]

        story:append(babi.Question(
            'yes_no',
            babi.Clause(world, q_truth, world:god(),
                   actions.set, q1, q_dir_name, q2),
            Set{story[1], story[2]}
        ))
    end
    return story, knowledge
end

PositionalReasoning.DEFAULT_CONFIG = {
    directions='relative'
}

return PositionalReasoning

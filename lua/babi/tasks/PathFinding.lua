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

local DIRECTIONS = {'n', 's', 'e', 'w'}

local PathFinding = torch.class('babi.PathFinding', 'babi.Task', babi)

function PathFinding:new_world()
    local world = babi.World()
    local locations = List()
    for i, option in ipairs{'bedroom', 'bathroom', 'kitchen',
                            'office', 'garden', 'hallway'} do
        local location = world:create_entity(option, {is_location = true})
        locations:append(location)
    end
    self.locations = utilities.choice(locations, 6)
    return world
end

local function add_loc(grid, i, obj, world)
    world:perform_action('set_pos', world:god(), obj, grid:to_coordinates(i))
    -- Set all the direction properties
    for _, dir in pairs(DIRECTIONS) do
        local j = grid:rel_node(i, dir)
        if grid.nodes[j] then
            world:perform_action('set_dir', world:god(), obj, dir,
                grid.nodes[j])
        end
    end
end


function PathFinding:generate_story(world, knowledge, story, config)
    -- Choose the direction in which the locations wlil be ordered
    local path_length = config.path_length
    assert(path_length + 1 + config.decoys <= #self.locations,
           'not enough locations to create path of this length')
    local grid = utilities.Grid(#self.locations * 2 + 1)
    local source_loc = self.locations[1]
    local target_loc

    local source = grid:center()
    local target
    local cur_node = source
    local path = List()

    grid:add_node(source, source_loc)
    add_loc(grid, source, source_loc, world)
    local i = 2
    while true do
        local dir = DIRECTIONS[math.random(#DIRECTIONS)]
        local next_node = grid:rel_node(cur_node, dir)
        if not grid.nodes[next_node] then
            grid:add_node(next_node, self.locations[i])
            if #grid:yen(source, next_node, 2) > 1 then
                grid:remove_node(next_node)
            else
                path:append(dir)
                add_loc(grid, next_node, self.locations[i], world)
                story:append(babi.Clause(world, true, world:god(), actions.set,
                    self.locations[i - 1], dir, self.locations[i]))
                if i - 1 == path_length then
                    target = next_node
                    target_loc = self.locations[i]
                    break
                end
                cur_node = next_node
                i = i + 1
            end
        end
    end

    -- Decoys
    local num_decoys = config.decoys
    local j = 0
    while j < num_decoys do
        local rel_obj = self.locations[math.random(i)]
        local rel_node = grid.objects[rel_obj]
        local dir = DIRECTIONS[math.random(#DIRECTIONS)]
        local decoy_node = grid:rel_node(rel_node, dir)
        if not grid.nodes[decoy_node] then
            grid:add_node(decoy_node, self.locations[i + 1])
            if #grid:yen(source, target, 2) > 1 then
                grid:remove_node(decoy_node)
            else
                add_loc(grid, decoy_node, self.locations[i + 1], world)
                story:append(babi.Clause(world, true, world:god(), actions.set,
                                    rel_obj, dir, self.locations[i + 1]))
                i = i + 1
                j = j + 1
            end
        end
    end
    local support = Set(story:slice(1, path_length))
    story = utilities.choice(story, #story)
    story:append(babi.Question(
        'eval',
        babi.Clause(world, true, world:god(), actions.set, source_loc,
               'path', {target_loc, path}),
        support
    ))
    return story, knowledge
end

PathFinding.DEFAULT_CONFIG = {path_length=2, decoys=2}

return PathFinding

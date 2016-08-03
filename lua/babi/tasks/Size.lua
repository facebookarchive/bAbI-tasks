-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local tablex = require 'pl.tablex'
local List = require 'pl.List'
local Set = require 'pl.Set'

local babi = require 'babi'
local actions = require 'babi.actions'
local utilities = require 'babi.utilities'


-- To support arbitrary complexity, we keep track of the orderings in a DAG. We
-- walk the DAG to retrieve the supporting facts
do
    local Ordering = torch.class('babi.Ordering', babi)

    function Ordering:__init()
        self.edges = {}
    end

    function Ordering:add(x, y, obj)
        self.edges[x] = self.edges[x] or {}
        self.edges[x][y] = obj or true
    end

    function Ordering:get_roots()
        local S = Set(tablex.keys(self.edges))
        for node, children in pairs(self.edges) do
            S = S - Set(tablex.keys(children))
        end
        return S
    end

    function Ordering:toposort()
        local L = List()
        local S = self:get_roots()
        -- Copy so that we can remove edges
        local edges = tablex.copy(self.edges)

        while Set.len(S) > 0 do
            local n = Set.values(S)[1]
            S = S - Set{n}
            L:append(n)
            local children = tablex.keys(edges[n] or {})
            edges[n] = nil
            for i = 1, #children do
                local child = children[i]
                local is_root = true
                for _, children in pairs(edges) do
                    if Set{child} < Set(tablex.keys(children)) then
                        is_root = false
                        break
                    end
                end
                if is_root then
                    S = S + Set{child}
                end
            end
        end
        return L
    end

    function Ordering:single_source(x)
        -- Find the shortest path from x to y
        local dist = {[x]=0}
        local prev = {}
        local L = self:toposort()
        for i = 1, #L do
            local u = L[i]
            for v, _ in pairs(self.edges[u] or {}) do
                if (dist[v] or math.huge) > (dist[u] or math.huge) + 1 then
                    dist[v] = dist[u] + 1
                    prev[v] = u
                end
            end
        end
        return dist, prev
    end

    function Ordering:_path(dist, prev, y)
        -- Walk the graph in reverse to find the support
        local path = List()
        local u = y
        while prev[u] do
            path:append(self.edges[prev[u]][u])
            u = prev[u]
        end
        return path:reverse()
    end

    function Ordering:shortest_path(x, y)
        local dist, prev = self:single_source(x)
        return self:_path(dist, prev, y)
    end

    function Ordering:get_paths_of_length(l)
        local L = self:toposort()
        local rvals = {}
        for i = 1, #L - 1 do
            local dist, prev = self:single_source(L[i])
            for j = i + 1, #L do
                local path = self:_path(dist, prev, L[j])
                if #path == l then
                    rvals[{L[i], L[j]}] = path
                end
            end
        end
        return rvals
    end
end

local Size = torch.class('babi.Size', 'babi.Task', babi)

function Size:new_world()
    local world = babi.World()
    world:load((BABI_HOME or '') .. 'tasks/worlds/world_sizes.txt')
    local objects = world:get(function(entity) return entity.is_thing and
                                                      not entity.is_god end)
    for i = 1, #objects do
        if objects[i].size == 0 then
            objects[i].size = 1 + math.random()
        end
    end
    return world
end

function Size:generate_story(world, knowledge, story, config)
    -- Find the actors and the locations in the world
    local objects = world:get(function(entity) return entity.is_thing and
                                                      not entity.is_god end)
    assert(config.steps < #objects,
           'not enough objects for this number of comparisons')
    table.sort(objects, function(x, y) return x.size > y.size end)

    -- Keep a track of the ordering the reader is aware of
    local ordering = babi.Ordering()

    -- Let's make sure we can answer at least one question
    local initial_objects = torch.randperm(#objects):sub(1, config.steps + 1)
    initial_objects = initial_objects:sort():totable()
    for i = 1, config.steps do
        local x = objects[initial_objects[i]]
        local y = objects[initial_objects[i + 1]]
        local clause =
            babi.Clause(world, true, world:god(), actions.set, x, '>', y)
        story:append(clause)
        ordering:add(x, y, clause)
    end

    -- Now sample some other pieces of information
    for i = 1, math.random(config.steps, 7) do
        local n = 0
        while true do
            n = n + 1
            local indices = torch.randperm(#objects):sub(1, 2):sort()
            local i, j = unpack(indices:totable())
            local x, y = objects[i], objects[j]
            -- Check to make sure we don't have this information already
            if (not ordering.edges[x] or not ordering.edges[x][y]) then
                -- Check to make sure we still have a question
                ordering:add(x, y)
                local options = ordering:get_paths_of_length(config.steps)
                if #tablex.keys(options) == 0 then
                    -- Remove the relationship and try again
                    ordering.edges[x][y] = nil
                    if n > 100 then
                        -- To prevent infinite loops, we stop eventually
                        break
                    end
                else
                    -- Add to the story and break the loop
                    local clause = babi.Clause(
                        world, true, world:god(), actions.set, x, '>', y
                    )
                    story:append(clause)
                    ordering.edges[x][y] = clause
                    break
                end
            end
        end
    end

    -- Shuffle the story
    story = utilities.choice(story, #story)

    -- Find all the questions we can ask
    local options = ordering:get_paths_of_length(config.steps)
    assert(#tablex.keys(options) > 0)
    for pair, support in pairs(options) do
        local clause = babi.Clause(
            world, true, world:god(), actions.set, pair[1], '>', pair[2]
        )
        story:append(babi.Question('eval', clause, Set(support)))
    end

    return story, knowledge
end

Size.DEFAULT_CONFIG = {steps=2}

return Size

-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local List = require 'pl.List'
local Set = require 'pl.Set'
local tablex = require 'pl.tablex'

local torch = require 'torch'

local utilities = {}
local DIRECTIONS = {'n', 's', 'e', 'w'}

function utilities.split(s)
    local rval = {}
    local inner_loop = false
    local opening_quote
    for word in string.gmatch(s, "%g+") do
        local first_char = word:sub(1, 1)
        local last_char = word:sub(-1, -1)
        if not inner_loop then
            if first_char == "'" or first_char == '"' then
                opening_quote = first_char
                rval[#rval + 1] = word:sub(2, -1)
                inner_loop = true
            else
                rval[#rval + 1] = word
            end
        else
            if last_char == opening_quote then
                rval[#rval] = rval[#rval] .. ' ' .. word:sub(1, -2)
                inner_loop = false
            else
                rval[#rval] = rval[#rval] .. ' ' .. word
            end
        end
    end
    return rval
end

-- Random sample of a list-like table, with or without replacement
function utilities.choice(a, size, replace)
    size = size or 1
    local is_set = false
    if Set.is_a(a, Set) then
        is_set = true
        a = a:values()
    end

    local choices = List()
    if replace then
        for i = 1, size do
            choices:append(a[math.random(#a)])
        end
    else
        local indices = torch.randperm(#a):narrow(1, 1, size)
        for i = 1, size do
            choices:append(a[indices[i]])
        end
    end

    if is_set then
        return Set(choices)
    else
        return choices
    end
end

local Grid = torch.class('utilities.Grid', utilities)

function Grid:__init(width, height)
    self.width = width
    self.height = height or width
    self.nodes = {}
    self.objects = {}
    self.edges = {}
    for i = 1, self.width * self.height do
        self.edges[i] = Set{}
    end
end

function Grid:to_coordinates(i)
    return (i - 1) % self.width + 1, math.floor((i - 1) / self.width) + 1
end

function Grid:to_node(x, y)
    return x + (y - 1) * self.width
end

function Grid:center()
    return math.floor(self.height / 2) * self.width + math.ceil(self.width / 2)
end

function Grid:rel_node(i, dir)
    if dir == 'n' then return i - self.width end
    if dir == 's' then return i + self.width end
    if dir == 'e' then return i + 1 end
    if dir == 'w' then return i - 1 end
end

function Grid:add_node(i, obj, edges)
    self.nodes[i] = obj or true
    if obj then
        self.objects[obj] = i
    end
    for _, dir in pairs(DIRECTIONS) do
        local j = self:rel_node(i, dir)
        if self.nodes[j] then
            self:add_edge(i, j)
        end
    end
end

function Grid:remove_node(i)
    local obj = self.nodes[i]
    self.nodes[i] = nil
    self.objects[obj] = nil
    local edges = List()
    for j, _ in pairs(self.edges[i]) do
        edges:append({i, j})
        self:remove_edge(i, j)
    end
    return obj, edges
end

function Grid:add_edge(i, j)
    self.edges[i] = self.edges[i] + Set{j}
    self.edges[j] = self.edges[j] + Set{i}
end

function Grid:remove_edge(i, j)
    self.edges[i] = self.edges[i] - Set{j}
    self.edges[j] = self.edges[j] - Set{i}
end

function Grid:manhattan(i, j, via)
    if via then
        return self:manhattan(i, via) + self:manhattan(j, via)
    end
    local x1, y1 = self:to_coordinates(i)
    local x2, y2 = self:to_coordinates(j)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

function Grid:print(i)
    -- For debugging purposes
    local x_mark, y_mark
    if i then
        x_mark, y_mark = self:to_coordinates(i)
    end
    for y = 1, self.height do
        for x = 1, self.width do
            if x == x_mark and y == y_mark then
                io.write('T')
            elseif self.nodes[self:to_node(x, y)] then
                io.write('X')
            else
                io.write('O')
            end
            io.write(' ')
        end
        io.write('\n')
    end
end

function Grid:yen(source, target, K)
    local A = List{self:dijkstra(source, target)}
    local B = List()
    for k = 1, K - 1 do
        for i = 1, #A[k] - 1 do
            local spur_node = A[k][i]
            local root_path = A[k]:slice(1, i)

            local removed_edges = List()
            local removed_nodes = List()
            for _, p in ipairs(A) do
                if root_path == p:slice(1, i) then
                    self:remove_edge(p[i], p[i + 1])
                    removed_edges:append({p[i], p[i + 1]})
                end
            end

            for _, j in ipairs(root_path) do
                if j ~= spur_node then
                    removed_nodes:append({j, self:remove_node(j)})
                end
            end

            local spur_path = self:dijkstra(spur_node, target)

            if spur_path then
                local total_path = root_path:extend(spur_path:slice(2))
                B:append(total_path)
            end

            for _, edge in pairs(removed_edges) do
                self:add_edge(unpack(edge))
            end

            for _, node in pairs(removed_nodes) do
                self:add_node(unpack(node))
            end
        end

        if #B == 0 then
            break
        end

        B:sort(function(p1, p2) return #p1 < #p2 end)
        A:append(B:pop(1))

    end
    return A
end

function Grid:dijkstra(source, target)
    local dist, prev = {}, {}
    local unvisited = Set(tablex.range(1, self.width * self.height))

    for i = 1, self.width * self.height do
        if i ~= source then
            dist[i] = math.huge
        else
            dist[i] = 0
        end
    end

    while #unvisited > 0 do
        local u = tablex.sortv(tablex.merge(dist, unvisited))()
        if u == target then
            break
        end
        unvisited = unvisited - Set{u}
        for v, _ in pairs(self.edges[u]) do
            if dist[u] + 1 < dist[v] then
                dist[v] = dist[u] + 1
                prev[v] = u
            end
        end
    end

    if dist[target] < math.huge then
        local path = List{target}
        local u = target
        while prev[u] do
            u = prev[u]
            path:append(u)
        end
        return path:reverse()
    end
end

local function add_loc(grid, i, obj, world)
    world:perform_action('set_pos', world:god(), obj,
                         grid:to_coordinates(i))
    -- Set all the direction properties
    for _, dir in pairs(DIRECTIONS) do
        local j = grid:rel_node(i, dir)
        if grid.nodes[j] then
            world:perform_action('set_dir', world:god(), obj, dir,
                                 grid.nodes[j])
        end
    end
end

utilities.add_loc = add_loc

local function babi_home()
    local str = debug.getinfo(1, 'S').source
    return str:sub(2, str:find('babi') + 4)
end

utilities.babi_home = babi_home

return utilities

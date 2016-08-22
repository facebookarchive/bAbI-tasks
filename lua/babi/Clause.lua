-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local tablex = require 'pl.tablex'

local babi = require 'babi._env'

local Clause = torch.class('babi.Clause', babi)

function Clause:__init(world, truth_value, actor, action, ...)
    self.world = world
    self.truth_value = truth_value
    self.actor = actor
    self.action = action
    self.args = {...}
end

function Clause.new(...)
    local cl = {}
    setmetatable(cl, {__index = Clause})
    cl:__init(...)
    return cl
end

function Clause:is_valid()
    return self.action:is_valid(self.world, self.actor, unpack(self.args))
end

function Clause:perform()
    if self.truth_value then
        self.action:perform(self.world, self.actor, unpack(self.args))
    end
end

function Clause.__eq(lhs, rhs)
    if lhs.world == rhs.world and lhs.actor == rhs.actor and
            tablex.compare(lhs.args, rhs.args,
                           function(lhs, rhs) return lhs == rhs end) then
        return true
    end
end

-- Given options, sample a clause that is valid
function Clause.sample_valid(world, truth_values, actors, actions, ...)
    local clause
    for _ = 1, 100 do
        local truth_value = truth_values[math.random(#truth_values)]
        local actor = actors[math.random(#actors)]
        local action = actions[math.random(#actions)]
        local args = {}
        for i, arg in ipairs{...} do
            args[i] = arg[math.random(#arg)]
        end
        clause = Clause.new(world, truth_value, actor, action, unpack(args))
        if clause:is_valid() then
            return clause
        end
    end
end

return Clause

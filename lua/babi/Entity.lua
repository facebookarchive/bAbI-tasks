-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local babi = require 'babi._env'

local Entity = torch.class('babi.Entity', babi)

-- An entity in the world (just a table with some defaults)
function Entity:__init(name, properties)
    self.name = name

    self.carry = 0
    self.size = 0
    self.is_thing = true

    if properties then
        for key, value in pairs(properties) do
            self[key] = value
        end
    end
end

function Entity:__tostring()
    return self.name
end

function Entity:can_hold(entity)
    return self.size >= self.carry + entity.size
end

return Entity

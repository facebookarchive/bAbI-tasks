-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.


local class = require 'class'

local Rule = class('Rule')

function Rule:perform(world)
    return
end

function Rule:is_applicable(clause, knowledge, story)
    return true
end

function Rule:update_knowledge(world, knowledge, clause)
    return
end

return Rule

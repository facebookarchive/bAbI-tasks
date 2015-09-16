-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.


local class = require 'class'

local Set = require 'pl.Set'
local List = require 'pl.List'

local actions = require 'babi.actions'
local Task = require 'babi.Task'
local World = require 'babi.World'
local Question = require 'babi.Question'
local Clause = require 'babi.Clause'
local Counting = require 'babi.tasks.Counting'

local Listing, parent = class('Listing', 'Counting')

function Listing:generate_story(...)
    local story, knowledge = parent:generate_story(...)
    for i = 1, #story do
        if class.istype(story[i], 'Question') then
            story[i].kind = 'eval'
        end
    end
    return story, knowledge
end

return Listing

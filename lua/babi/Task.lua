-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.


local class = require 'class'

local List = require 'pl.List'

local Knowledge = require 'babi.Knowledge'
local stringify = require 'babi.stringify'

local Task = class('Task')

--- Generate a story and questions, and print to screen.
function Task:generate(config)
    local world = self:new_world(config)
    local story, knowledge = self:generate_story(world, Knowledge(world),
                                                 List(), config)
    -- Count number of questions
    local num_questions = 0
    for i = 1, #story do
      if class.istype(story[i], 'Question') then
        num_questions = num_questions + 1
      end
    end
    return stringify(story, knowledge, config), num_questions
end

return Task

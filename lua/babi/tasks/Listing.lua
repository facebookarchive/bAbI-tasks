-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local babi = require 'babi'
require 'babi.tasks.Counting'

local Listing, parent = torch.class('babi.Listing', 'babi.Counting', babi)

function Listing:generate_story(...)
    local story, knowledge = parent:generate_story(...)
    for i = 1, #story do
        if torch.isTypeOf(story[i], 'babi.Question') then
            story[i].kind = 'eval'
        end
    end
    return story, knowledge
end

return Listing

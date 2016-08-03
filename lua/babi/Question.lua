-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.

local babi = require 'babi._env'

local Question = torch.class('babi.Question', babi)

function Question:__init(kind, args, support)
    self.kind = kind
    self.args = args
    self.support = support
end

return Question

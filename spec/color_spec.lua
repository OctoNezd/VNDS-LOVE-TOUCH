local pprint = require "lib.pprint"
local colorify = require("text.text_color").colorify

describe("Basic Colors", function()
    it("Single Color", function()
        assert.are.equal("demon", colorify("x1b[32;1mdemon")[2])
    end)
    it("No Color", function()
        assert.are.equal("hello", colorify("hello")[2])
    end)
end)

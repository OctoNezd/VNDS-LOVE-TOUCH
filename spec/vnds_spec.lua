local pprint = require "lib.pprint"
_G.love = {
    filesystem = {
        getDirectoryItems = function() return {"main.scr"} end,
        getInfo = function(path)
            -- treat everything as a file for test purposes
            return {type = "file"}
        end,
    },
}
local script = require "script"

local function run_scr(code)
    local i = script.load("", function() return code end)
    local instructions = {}
    while true do
        local ins
        i, ins = script.next_instruction(i)
        if ins then
            table.insert(instructions, ins)
        else
            break
        end
    end
    return i, instructions
end

describe("VNDS Interpreter Tests", function()
    describe("Assignment", function()
        it("Local Number Assignment", function()
            local i = run_scr('setvar test = 5')
            assert.are.equal(i.locals["test"], 5)
            i = run_scr('setvar test = 5.0')
            assert.are.equal(i.locals["test"], 5.0)
            i = run_scr('setvar test = 5.01')
            assert.are.equal(i.locals["test"], 5.01)
        end)
        it("Local String Assignment", function()
            local i = run_scr('setvar test = "test, string"')
            assert.are.equal(i.locals["test"], "test, string")
        end)
        it("Global Number Assignment", function()
            local i = run_scr('gsetvar test = 5')
            assert.are.equal(i.globals["test"], 5)
            i = run_scr('gsetvar test = 5.0')
            assert.are.equal(i.globals["test"], 5.0)
            i = run_scr('gsetvar test = 5.01')
            assert.are.equal(i.globals["test"], 5.01)
        end)
        it("Global String Assignment", function()
            local i = run_scr('gsetvar test = "test, string"')
            assert.are.equal(i.globals["test"], "test, string")
        end)
    end)

    describe("Operations", function()
        it("Number Addition", function()
            local i = run_scr('setvar test + 2')
            assert.are.equal(i.locals["test"], 2)
            local ins
            i, ins = run_scr('setvar test + 2\nsetvar test + 4')
            assert.are.equal(i.locals["test"], 6)
        end)
        it("Number Subtraction", function()
            local i = run_scr('setvar test - 2')
            assert.are.equal(i.locals["test"], -2)
            i = run_scr('setvar test + 2\nsetvar test - 4')
            assert.are.equal(i.locals["test"], -2)
        end)
        it("String Concat", function()
            local i = run_scr('setvar test + "hello there"')
            assert.are.equal(i.locals["test"], "hello there")
            i = run_scr('setvar test + "hello "\nsetvar test + "there"')
            assert.are.equal(i.locals["test"], "hello there")
        end)
        it("Number and String Concat", function()
            local i = run_scr('setvar test + 5\nsetvar test + " there"')
            assert.are.equal(i.locals["test"], "5 there")
        end)
    end)

    describe("Text Interpolation", function()
        it("Number Interpolation", function()
            local i, ins = run_scr('setvar test = 2\ntext hello there $test')
            assert.are.equal(ins[1].text, "hello there 2")
        end)
        it("String Interpolation", function()
            local i, ins = run_scr('setvar test = "hello"\ntext $test there 2')
            assert.are.equal(ins[1].text, "hello there 2")
            i, ins = run_scr('setvar strS[1903] = "Stay in bed."\nsetvar strS[1904] = "Get up."\nchoice $strS[1903]|$strS[1904]')
            assert.are.equal(ins[1].choices[1], "Stay in bed.")
        end)
    end)

    describe("Labels", function()
        it("Single File", function()
            local i, ins = run_scr('goto hello\ntext not run\nlabel hello\ntext run')
            assert.are.equals(ins[1].text, "run")
        end)
        it("Label Interpolation", function()
            local i, ins = run_scr('setvar RETLABEL = "hello"\ngoto $RETLABEL\ntext not run\nlabel hello\ntext run')
            assert.are.equals(ins[1].text, "run")
        end)
    end)

    -- todo
    -- nested if statements
    -- different comparison operators
    -- multi file labels
    -- selection
    -- Saving format
end)

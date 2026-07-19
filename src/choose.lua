local function choose(i)
    return function()
        script.choose(interpreter, i)
        dispatch("next_ins")
    end
end

on("choice", function(self) -- This is the VNDS choice event
    local choices = {}
    for i, c in ipairs(self.choices) do
        table.insert(choices, {text = c, action = choose(i)})
    end
    create_listbox({choices = choices, allow_menu = true})
end)

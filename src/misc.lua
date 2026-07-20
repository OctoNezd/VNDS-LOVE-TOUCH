-- Source - https://stackoverflow.com/a/66699630
-- Posted by Roque, modified by community. See post 'Timeline' for change history
-- Retrieved 2026-07-20, License - CC BY-SA 4.0
-- in some helper module
function utils_Set(list)
    local set = {}
    for _, l in ipairs(list) do
        set[l] = true
    end
    return set
end

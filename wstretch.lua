-- w/stretch
-- time-stretching with wtape
function init()
    clock.run(function()
        while true do
            clock.sleep(1 / 15)
            redraw()
        end
    end)

    norns.crow.loadscript("wstretch.lua")
end

function key(n, z) end

function enc(n, d) end

needs_redraw = true
function redraw()
    if not needs_redraw then return end
    needs_redraw = false
    screen.clear()
    screen.update()
end

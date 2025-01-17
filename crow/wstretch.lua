public {window_size = 0.05}
public {window_step = 0.25}
public {clock_div = 1 / 4}

function stretch(start_ts, end_ts)
    clock.cleanup()

    local window_start_ts = start_ts
    local window_end_ts = window_start_ts + public.window_size

    ii.wtape.event = function(e, value)
        if e.name == "timestamp" then
            if value > window_end_ts then
                ii.wtape[1].timestamp(window_start_ts)
            elseif value < window_start_ts then
                ii.wtape[1].timestamp(window_end_ts)
            end
        end
    end

    clock.run(function()
        while true do
            clock.sleep(0.05)
            ii.wtape[1].get("timestamp")
        end
    end)

    clock.run(function()
        while true do
            clock.sync(public.clock_div)
            window_start_ts = window_start_ts + public.window_size *
                                  public.window_step
            window_end_ts = window_start_ts + public.window_size
            if window_end_ts >= end_ts then
                window_start_ts = start_ts
                window_end_ts = window_start_ts + public.window_size
            end
            ii.wtape[1].timestamp(window_start_ts)
        end
    end)
end

function init_stretch()
    local loop_start = nil
    local loop_end = nil
    ii.wtape.event = function(e, value)
        if e.name == "loop_start" then
            loop_start = value
        elseif e.name == "loop_end" then
            loop_end = value
        end
        if loop_start ~= nil and loop_end ~= nil then
            stretch(loop_start, loop_end)
        end
    end

    ii.wtape[1].get("loop_start")
    ii.wtape[1].get("loop_end")
end

function init() input[1] {mode = "clock", division = 1 / 16} end

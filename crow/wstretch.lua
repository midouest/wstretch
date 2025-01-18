public{poll_freq=20}
public{window_size=0.1}
public{window_step=0.5}
public{clock_div=1/4}

function stretch()
  local devices={
    {start_ts=nil,end_ts=nil,window_start_ts=nil,window_end_ts=nil},
    {start_ts=nil,end_ts=nil,window_start_ts=nil,window_end_ts=nil},
  }

  local function run()
    clock.cleanup()

    for i,device in ipairs(devices) do
      device.window_start_ts=device.start_ts+(i-1)*public.window_size*public.window_step
      device.window_end_ts=device.window_start_ts+public.window_size
    end

    ii.wtape.event=function(e,value)
      local device=devices[e.device]
      if e.name=="timestamp" then
        if value>device.window_end_ts then
          ii.wtape[e.device].timestamp(device.window_start_ts)
        elseif value<device.window_start_ts then
          ii.wtape[e.device].timestamp(device.window_end_ts)
        end
      end
    end

    clock.run(function()
      while true do
        clock.sleep(1/public.poll_freq)
        ii.wtape[1].get("timestamp")
        ii.wtape[2].get("timestamp")
      end
    end)

    clock.run(function()
      while true do
        clock.sync(public.clock_div)
        for i,device in ipairs(devices) do
          device.window_start_ts=device.window_start_ts+public.window_size*public.window_step
          device.window_end_ts=device.window_start_ts+public.window_size
          if device.window_end_ts>=device.end_ts then
            device.window_start_ts=device.start_ts
            device.window_end_ts=device.window_start_ts+public.window_size
          end
          ii.wtape[i].timestamp(device.window_start_ts)
        end
      end
    end)
  end

  ii.wtape.event=function(e,value)
    if e.name=="loop_start" then
      devices[e.device].start_ts=value
    elseif e.name=="loop_end" then
      devices[e.device].end_ts=value
    end
    for _,device in ipairs(devices) do
      if device.start_ts==nil or device.end_ts==nil then
        return
      end
    end
    run()
  end

  ii.wtape[1].get("loop_start")
  ii.wtape[2].get("loop_start")
  ii.wtape[1].get("loop_end")
  ii.wtape[2].get("loop_end")
end

function rec_start()
  ii.wtape[1].loop_active(0)
  ii.wtape[2].loop_active(0)
  ii.wtape[1].record(1)
  ii.wtape[2].record(1)
  ii.wtape[1].loop_start()
  ii.wtape[2].loop_start()
  ii.wtape[1].play(1)
  ii.wtape[2].play(1)
end

function rec_stop()
  ii.wtape[1].loop_end()
  ii.wtape[2].loop_end()
  ii.wtape[1].record(0)
  ii.wtape[2].record(0)
  ii.wtape[1].loop_active(1)
  ii.wtape[2].loop_active(1)
end

function init()
  input[1]{mode="clock",division=1/16}
  ii.wtape[1].speed(1)
  ii.wtape[2].speed(1)
end

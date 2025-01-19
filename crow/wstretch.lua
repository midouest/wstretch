--[[
TODO:
- when a loop is set, automatically start time stretching
- when a loop is cleared, stop time stretching? check for nil loop_start/loop_end?
- programmatically check for one or two wtapes?
- handle start_ts>end_ts
]]
local ring={}
ring.__index=ring

function ring.new(len)
  len=len+1
  local buf={}
  for _=1,len do
    table.insert(buf,0)
  end
  return setmetatable({_len=len,_buf=buf,_r=1,_w=1},ring)
end

function ring:push(x)
  self._buf[self._w]=x
  self._w=self._w%self._len+1
  if self._w==self._r then self._r=self._r%self._len+1 end
end

function ring:peek()
  if self._r==self._w then return end
  return self._buf[self._r]
end

local function _iter(o,i)
  local r=(o._r+i-1)%o._len+1
  if r==o._w then return end
  local x=o._buf[r]
  return i+1,x
end

function ring:iter()
  return _iter,self,0
end

public{window_step=1}
public{device_step=1/2}
public{clock_div=1/4}

local prev=nil
local window_size=0.1
function stretch()
  local devices={
    {start_ts=nil,end_ts=nil,window_start_ts=nil,window_end_ts=nil,direction=1},
    {start_ts=nil,end_ts=nil,window_start_ts=nil,window_end_ts=nil,direction=1},
  }

  local function run()
    clock.cleanup()

    for i,device in ipairs(devices) do
      device.window_start_ts=device.start_ts+(i-1)*window_size*public.device_step
      device.window_end_ts=device.window_start_ts+window_size
    end

    ii.wtape.event=function(e,value)
      local device=devices[e.device]
      if e.name=="timestamp" then
        if e.device==1 then
          device.window_end_ts=device.window_start_ts+window_size
        else
          local prev_device=devices[e.device-1]
          local window_start_ts=prev_device.window_start_ts-prev_device.start_ts+device.start_ts+
            window_size*public.device_step
          local drift=math.abs(window_start_ts-device.window_start_ts)
          if drift>=0.01 then
            device.window_start_ts=window_start_ts
            device.window_end_ts=device.window_start_ts*window_size
          end
        end
        if value>device.window_end_ts then
          ii.wtape[e.device].timestamp(device.window_start_ts)
        elseif value<device.window_start_ts then
          ii.wtape[e.device].timestamp(device.window_end_ts)
        end
      elseif e.name=="speed" then
        device.direction=value>0 and 1 or -1
      else
        print(e.name..e.device.."="..value)
      end
    end

    input[2]{mode="change",direction="rising",change=function()
      local curr=time()
      if prev~=nil then
        window_size=2*(curr-prev)/1000
        ii.wtape[1].get("timestamp")
        ii.wtape[2].get("timestamp")
      end
      prev=curr
    end}

    clock.run(function()
      while true do
        clock.sleep(0.1)
        ii.wtape[1].get("speed")
        ii.wtape[2].get("speed")
      end
    end)

    clock.run(function()
      while true do
        clock.sync(public.clock_div)
        for i,device in ipairs(devices) do
          device.window_start_ts=device.window_start_ts+window_size*public.window_step
          device.window_end_ts=device.window_start_ts+window_size
          if device.window_end_ts>=device.end_ts then
            device.window_start_ts=device.start_ts
            device.window_end_ts=device.window_start_ts+window_size
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
end

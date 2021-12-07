local func = function(p, uv)
  local before = os.time()
  local async
  async = uv.new_async(function(a, b, c)
    p('in async notify callback')
    p(a, b, c)
    uv.close(async)
  end)
  local args = {500, 'string', nil, false, 5, "helloworld", async}
  local unpack = unpack or table.unpack
  uv.new_thread(function(num, s, null, bool, five, hw, asy)
    local uv2 = require 'luv'
    uv2.async_send(asy, 'a', true, 250)
    uv2.sleep(1000)
  end, unpack(args)):join()
  local elapsed = (os.time() - before) * 1000
  assert(elapsed >= 1000, "elapsed should be at least delay ")
end

func(print, vim.loop)

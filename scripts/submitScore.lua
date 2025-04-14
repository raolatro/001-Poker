-- submitScore.lua
local http = require("socket.http")
local ltn12 = require("ltn12")
local config = require("scripts.config")
local submitScore = {}

function submitScore.send(player, score)
  local url = "https://raoni.studio/games/raolatro/backend/submit_score.php"
  local postData = "player=" .. player .. "&score=" .. score
  local responseBody = {}
  local res, code = http.request{
    url = url,
    method = "POST",
    headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded",
      ["Content-Length"] = tostring(#postData)
    },
    source = ltn12.source.string(postData),
    sink = ltn12.sink.table(responseBody)
  }
  return table.concat(responseBody), code
end

return submitScore
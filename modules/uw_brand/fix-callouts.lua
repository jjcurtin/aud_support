-- fix-callouts.lua
-- Runs before Quarto's own callout processing. Repairs div classes that were
-- meant to be callouts but won't be recognized by Quarto:
--   ::: {callout}      -> pandoc reads the class literally as "{callout}"
--   ::: {.callout}     -> fine already
--   ::: callut / calloiut / {calloiut}  -> typos
-- Anything that normalizes to "callout" or "callout-<type>" is rewritten.

local valid_types = { note = true, tip = true, important = true, warning = true, caution = true }

local function near_callout(word)
  -- "callout" with at most one dropped / inserted / swapped letter
  if word == "callout" then return true end
  if #word < 6 or #word > 8 then return false end
  if word:sub(1, 3) ~= "cal" then return false end
  local target = "callout"
  -- simple edit-distance (Levenshtein) <= 1
  local m, n = #word, #target
  local prev = {}
  for j = 0, n do prev[j] = j end
  for i = 1, m do
    local cur = { [0] = i }
    for j = 1, n do
      local cost = (word:sub(i, i) == target:sub(j, j)) and 0 or 1
      cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
    end
    prev = cur
  end
  return prev[n] <= 1
end

function Div(el)
  local changed = false
  local new = pandoc.List()
  for _, cls in ipairs(el.classes) do
    local clean = cls:gsub("^[{%.]+", ""):gsub("}+$", ""):lower()
    local base, typ = clean:match("^([a-z]+)%-?([a-z]*)$")
    local fixed = cls
    if base and near_callout(base) and (typ == "" or valid_types[typ]) then
      fixed = (typ == "") and "callout" or ("callout-" .. typ)
    end
    if fixed ~= cls then
      changed = true
      io.stderr:write(string.format("[uw-brand] fixed callout class '%s' -> '%s'\n", cls, fixed))
    end
    new:insert(fixed)
  end
  if changed then
    el.classes = new
    return el
  end
end

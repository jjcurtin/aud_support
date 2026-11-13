-- uw-dividers.lua
-- In markdown, `------` is used two ways in the activity files:
--   * as a divider between sections   -> styled UW red (class "uw-divider")
--   * as a blank line to write on      -> left as a plain gray rule
-- Only top-level rules are considered; rules inside lists or callouts are
-- always treated as writing lines.
--
-- Rules (applied to each run of consecutive `------` lines):
--   1. A single rule on its own                -> divider
--   2. Several rules right after a heading     -> all writing lines
--      (e.g. "## Reasons for Not Drinking" followed by 6 lines)
--   3. Several rules after other content:
--        if the run ends at a heading, callout or end of page
--             -> last rule is the divider, the rest are writing lines
--        else -> all writing lines

local function is_callout(b)
  if b == nil or b.t ~= "Div" then return false end
  for _, c in ipairs(b.classes) do
    if c:match("^callout") then return true end
  end
  return false
end

local function divider()
  return pandoc.RawBlock("html", '<hr class="uw-divider">')
end

function Pandoc(doc)
  local bl = doc.blocks
  local i = 1
  while i <= #bl do
    if bl[i].t == "HorizontalRule" then
      local j = i
      while bl[j + 1] and bl[j + 1].t == "HorizontalRule" do j = j + 1 end
      local prev, nxt = bl[i - 1], bl[j + 1]
      local after_heading = prev ~= nil and prev.t == "Header"
      local ends_section = nxt == nil or nxt.t == "Header" or is_callout(nxt)
      if i == j then
        bl[i] = divider()
      elseif not after_heading and ends_section then
        bl[j] = divider()
      end
      i = j + 1
    else
      i = i + 1
    end
  end
  return doc
end

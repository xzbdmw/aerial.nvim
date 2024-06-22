local function make_display(entry)
  local item = entry.value

  local lnum = item.selection_range and item.selection_range.lnum or item.lnum
  local col = item.selection_range and item.selection_range.col or item.col

  local indent = string.rep(" ", item.level * 2)
  local icon = config.get_icon(bufnr, item.kind)
  icon = "[" .. icon .. "]"
  local name_hl = highlight.get_highlight(item, false, false) or "NONE"
  local icon_hl = highlight.get_highlight(item, true, false) or "NONE"

  local buf_highligter = vim.treesitter.highlighter.active[bufnr]

  local buf_query = buf_highligter:get_query(vim.bo[bufnr].filetype)

  if buf_cache[bufnr] == nil then
    buf_cache[bufnr] = {}
  end
  if buf_cache[bufnr][entry.name] == nil then
    local captures = vim.treesitter.get_captures_at_pos(bufnr, lnum - 1, col)
    local name
    if captures ~= nil and #captures ~= 0 then
      name = captures[#captures].capture
    end
    if name ~= nil then
      name_hl = "@" .. name .. "." .. buf_query.lang
      buf_cache[bufnr][entry.name] = name_hl
    end
  end

  local columns = {
    { indent, icon_hl },
    { icon, icon_hl },
    { entry.name, buf_cache[bufnr][entry.name] },
  }

  local layout = {
    { width = #indent },
    { width = 6 },
    { remaining = true },
  }

  local displayer = opts.displayer
    or entry_display.create({
      separator = "",
      items = layout,
    })

  return displayer(columns)
end

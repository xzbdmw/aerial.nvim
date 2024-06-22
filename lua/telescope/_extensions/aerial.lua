local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local telescope = require("telescope")
local hl_cache = {}
local buf_cache = {}
local ext_config = {
  show_lines = true,
  show_nesting = {
    ["_"] = false,
    json = true,
    yaml = true,
  },
}

local function aerial_picker(opts)
  opts = opts or {}
  require("aerial").sync_load()
  local backends = require("aerial.backends")
  local config = require("aerial.config")
  local data = require("aerial.data")
  local highlight = require("aerial.highlight")
  local util = require("aerial.util")

  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(0)
  local filetype = vim.bo[bufnr].filetype
  local show_nesting = ext_config.show_nesting[filetype]
  if show_nesting == nil then
    show_nesting = ext_config.show_nesting["_"]
  end
  local backend = backends.get()

  if not backend then
    backends.log_support_err()
    return
  elseif not data.has_symbols(0) then
    backend.fetch_symbols_sync(0, opts)
  end
  local function make_display(entry)
    local item = entry.value

    local lnum = item.selection_range and item.selection_range.lnum or item.lnum
    local col = item.selection_range and item.selection_range.col or item.col

    local indent = string.rep(" ", item.level * 2)
    local icon = config.get_icon(bufnr, item.kind)
    icon = "[" .. icon .. "]"
    local name_hl = highlight.get_highlight(item, false, false) or "NONE"
    local icon_hl = highlight.get_highlight(item, true, false) or "NONE"

    -- if buf_cache[bufnr] == nil then
    --   buf_cache[bufnr] = {}
    -- end
    -- if buf_cache[bufnr][item.kind .. entry.name] == nil then
    --   local captures = vim.treesitter.get_captures_at_pos(bufnr, lnum - 1, col)
    --   local buf_highlighter = vim.treesitter.highlighter.active[bufnr]
    --   local state = buf_highlighter._highlight_states
    --   local capture_name = state.highlighter_query:query().captures[capture]
    --   local name
    --   if captures ~= nil and #captures ~= 0 then
    --     name = captures[#captures].capture
    --   end
    --   if name ~= nil then
    --     name_hl = "@" .. name .. "." .. vim.bo[bufnr].filetype
    --     buf_cache[bufnr][item.kind .. entry.name] = name_hl
    --   end
    -- end

    local columns = {
      { indent, icon_hl },
      { icon, icon_hl },
      { entry.name, name_hl },
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

  local function make_entry(item)
    local name = item.name
    if opts.get_entry_text ~= nil then
      name = opts.get_entry_text(item)
    else
      if show_nesting then
        local cur = item.parent
        while cur do
          name = string.format("%s.%s", cur.name, name)
          cur = cur.parent
        end
      end
    end
    local lnum = item.selection_range and item.selection_range.lnum or item.lnum
    local col = item.selection_range and item.selection_range.col or item.col
    return {
      value = item,
      display = make_display,
      name = name,
      ordinal = name .. " " .. string.lower(item.kind),
      lnum = lnum,
      col = col + 1,
      filename = filename,
    }
  end

  local results = {}
  local default_selection_index = 1
  if data.has_symbols(0) then
    local bufdata = data.get_or_create(0)
    local position = bufdata.positions[bufdata.last_win]
    for _, item in bufdata:iter({ skip_hidden = false }) do
      table.insert(results, item)
      if item == position.closest_symbol then
        default_selection_index = #results
      end
    end
  end

  -- Reverse the symbols so they have the same top-to-bottom order as in the file
  if conf.sorting_strategy == "descending" then
    util.tbl_reverse(results)
    default_selection_index = #results - (default_selection_index - 1)
  end
  pickers
    .new(opts, {
      prompt_title = "Document Symbols",
      finder = finders.new_table({
        results = results,
        entry_maker = make_entry,
      }),
      default_selection_index = default_selection_index,
      sorter = conf.generic_sorter(opts),
      previewer = conf.qflist_previewer(opts),
      push_cursor_on_edit = true,
    })
    :find()
end

return telescope.register_extension({
  setup = function(user_config)
    ext_config = vim.tbl_extend("force", ext_config, user_config or {})
    if type(ext_config.show_nesting) ~= "table" then
      ext_config.show_nesting = {
        ["_"] = ext_config.show_nesting,
      }
    end
  end,
  exports = {
    aerial = aerial_picker,
  },
})

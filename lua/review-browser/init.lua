local M = {}

-- resolve plugin root from this file's location: lua/review-browser/init.lua -> ../../..
local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")

local installers = {
  claude = {
    src  = plugin_dir .. "/commands/review-branch.md",
    dest = vim.fn.expand("~/.claude/commands/review-branch.md"),
    dir  = vim.fn.expand("~/.claude/commands"),
  },
}

local function find_file_upward()
  for lnum = vim.fn.line("."), 1, -1 do
    local line = vim.fn.getline(lnum)
    local clean = line:gsub("^#+%s*", ""):gsub("%*%*", ""):gsub("`", "")
    local file, lineno = clean:match("([%w%.%/_%-]+%.%a+):(%d+)")
    if not file then
      file = clean:match("([%w%.%/_%-]+%.%a+)")
    end
    if file and vim.fn.filereadable(file) == 1 then
      return file, lineno
    end
  end
end

function M.setup()
  vim.api.nvim_create_user_command("ReviewBranchInstall", function(opts)
    local target = opts.args
    local installer = installers[target]
    if not installer then
      vim.notify("Unknown target '" .. target .. "'. Available: " .. table.concat(vim.tbl_keys(installers), ", "), vim.log.levels.ERROR)
      return
    end
    vim.fn.mkdir(installer.dir, "p")
    vim.uv.fs_unlink(installer.dest)
    local ok, err = vim.uv.fs_symlink(installer.src, installer.dest)
    if ok then
      vim.notify("Linked " .. target .. " command: " .. installer.dest, vim.log.levels.INFO)
    else
      vim.notify("Failed to link: " .. (err or "unknown error"), vim.log.levels.ERROR)
    end
  end, { nargs = 1, complete = function() return vim.tbl_keys(installers) end, desc = "Install review-branch command" })

  vim.api.nvim_create_user_command("ReviewBrowse", function()
    local reviews = vim.fn.glob(".reviews/*.md", false, true)
    if #reviews == 0 then
      vim.notify("No reviews in .reviews/", vim.log.levels.WARN)
      return
    end
    table.sort(reviews, function(a, b)
      return vim.fn.getftime(a) > vim.fn.getftime(b)
    end)
    local names = vim.tbl_map(function(f)
      return vim.fn.fnamemodify(f, ":t")
    end, reviews)
    vim.ui.select(names, { prompt = "Reviews:" }, function(_, idx)
      if not idx then return end
      vim.cmd("edit " .. vim.fn.fnameescape(reviews[idx]))
    end)
  end, { desc = "Browse local branch reviews" })

  vim.api.nvim_create_autocmd("BufRead", {
    pattern = "*/.reviews/*.md",
    callback = function()
      vim.wo.wrap = true
      vim.wo.linebreak = true
      local function open_file(cmd_prefix)
        local file, lnum = find_file_upward()
        if file then
          local cmd = lnum
            and string.format("%s +%s %s", cmd_prefix, lnum, vim.fn.fnameescape(file))
            or (cmd_prefix .. " " .. vim.fn.fnameescape(file))
          vim.cmd(cmd)
        else
          vim.notify("No readable file found above cursor", vim.log.levels.WARN)
        end
      end

      vim.keymap.set("n", "gF", function() open_file("edit") end,
        { buffer = true, desc = "Open nearest file reference in current window" })
      vim.keymap.set("n", "gf", function() open_file("rightbelow vsplit") end,
        { buffer = true, desc = "Open nearest file reference in right split" })
    end,
  })
end

return M

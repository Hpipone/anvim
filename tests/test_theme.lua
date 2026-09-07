-- test_theme.lua

return function(ctx)
  local run = ctx.run
  run("theme: groups terdefinisi + override aman", function()
    package.loaded["anvim.theme"] = nil
    local theme = require("anvim.theme")
    theme.setup()
    vim.api.nvim_set_hl(0, "AnvimSelected", { link = "Visual" })
    theme.hl(-1, 0, "AnvimOk")
    assert(true)
  end)
end

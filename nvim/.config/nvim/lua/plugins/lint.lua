return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPost", "BufWritePost" },
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = {
      c = { "cppcheck" },
      cpp = { "cppcheck" },
      python = { "ruff" },
      php = { "phpcs" },
    }
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
      callback = function() lint.try_lint() end,
    })
  end,
}

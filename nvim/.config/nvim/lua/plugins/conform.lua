return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  keys = {
    {
      "<leader>f",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = { "n", "v" },
      desc = "Format buffer",
    },
  },
  opts = {
    formatters_by_ft = {
      c = { "clang-format" },
      cpp = { "clang-format" },
      lua = { "stylua" },
      python = { "ruff_format" },
      javascript = { "prettier" },
      css = { "prettier" },
      html = { "prettier" },
      php = { "php_cs_fixer" },
      json = { "prettier" },
      ["_"] = { "trim_whitespace" },
    },
    format_on_save = { timeout_ms = 500, lsp_format = "fallback" },
  },
}

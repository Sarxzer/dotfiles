return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    -- parsers get compiled once, in the background (needs tree-sitter-cli, which your install.sh already has)
    require("nvim-treesitter").install({
      "python", "javascript", "typescript", "tsx", "php", "html", "css",
      "json", "yaml", "toml", "bash", "lua", "markdown", "markdown_inline",
      "vim", "vimdoc", "regex", "gitcommit", "diff",
    })

    -- on the main branch you turn highlighting on yourself
    vim.api.nvim_create_autocmd("FileType", {
      callback = function()
        pcall(vim.treesitter.start)
      end,
    })
  end,
}

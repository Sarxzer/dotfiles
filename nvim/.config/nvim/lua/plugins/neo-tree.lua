return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    lazy = false, -- load on startup so it can catch `nvim .`
    keys = {
      {
        "<C-n>",
        function()
          if vim.bo.filetype == "neo-tree" then
            vim.cmd("wincmd p")
          else
            vim.cmd("Neotree focus")
          end
        end,
        desc = "Focus tree / go back to previous window",
      },
    },
    opts = {
      filesystem = {
        hijack_netrw_behavior = "open_default",
      },
    },
  },
}

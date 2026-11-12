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
            vim.cmd("wincmd p") -- already in the tree: jump back to the previous window
          else
            vim.cmd("Neotree focus") -- open if closed, otherwise just focus it
          end
        end,
        desc = "Focus file tree / go back",
      },
    },
    opts = {
      filesystem = {
        hijack_netrw_behavior = "open_default",
      },
    },
  },
}

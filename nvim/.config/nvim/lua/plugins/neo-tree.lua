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
        "<cmd>Neotree toggle<CR>",
        desc = "Toggle file tree",
      },
    },
    opts = {
      filesystem = {
        hijack_netrw_behavior = "open_default",
      },
    },
  },
}

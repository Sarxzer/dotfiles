return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      {
        "<C-p>",
        "<cmd>Telescope find_files<CR>",
        desc = "Find files",
      },
      {
        "<C-f>",
        "<cmd>Telescope live_grep<CR>",
        desc = "Search project",
      },
    },
  },
}

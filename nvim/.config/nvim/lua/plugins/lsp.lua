return {
	{ "mason-org/mason.nvim", opts = {} },

	{
		"mason-org/mason-lspconfig.nvim",
		dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
		opts = {
			-- installed through Mason, then enabled automatically
			ensure_installed = {
				"lua_ls",
				"pyright",
				"ts_ls",
				"intelephense",
				"html",
				"cssls",
				"rust_analyzer",
				"emmet_language_server",
				"clangd",
				"marksman",
			},
		},
	},

	{
		"neovim/nvim-lspconfig",
		config = function()
			-- let blink.cmp see what the servers can do
			vim.lsp.config("*", {
				capabilities = require("blink.cmp").get_lsp_capabilities(),
			})

			-- stop lua_ls from yelling "undefined global vim"
			vim.lsp.config("lua_ls", {
				settings = { Lua = { diagnostics = { globals = { "vim" } } } },
			})

			vim.lsp.config("rust_analyzer", {
				settings = { ["rust-analyzer"] = { check = { command = "clippy" } } },
			})

			vim.diagnostic.config({ virtual_text = true, severity_sort = true })

			vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
		end,
	},
}

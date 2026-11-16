return {
	{
		"lervag/vimtex",
		lazy = false, -- vimtex lazy-loads itself, don't fight it
		init = function()
			vim.g.vimtex_view_method = "zathura" -- or "sioyek", "okular"
			vim.g.vimtex_compiler_method = "latexmk"
		end,
	},
}

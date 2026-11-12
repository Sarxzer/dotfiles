return {
	"WhoIsSethDaniel/mason-tool-installer.nvim",
	dependencies = { "mason-org/mason.nvim" },
	opts = {
		ensure_installed = {
			"clang-format",
			"stylua",
			"prettier",
			"ruff",
			"php-cs-fixer",
			"phpcs",
		},
	},
}

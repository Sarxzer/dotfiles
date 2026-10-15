 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#0a0a0f',
    base01 = '#15121f',
    base02 = '#1e192c',
    base03 = '#605977',
    base04 = '#b8aed0',
    base05 = '#e6e1f0',
    base06 = '#e6e1f0',
    base07 = '#e6e1f0',
    base08 = '#ff5470',
    base09 = '#d946ef',
    base0A = '#7c3aed',
    base0B = '#a855f7',
    base0C = '#e78af5',
    base0D = '#c185f9',
    base0E = '#b18af4',
    base0F = '#d0b9f9',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '#e6e1f0',          bg = '#0a0a0f' })
  hi('TelescopeBorder',         { fg = '#605977',             bg = '#0a0a0f' })
  hi('TelescopePromptNormal',   { fg = '#e6e1f0',          bg = '#0a0a0f' })
  hi('TelescopePromptBorder',   { fg = '#605977',             bg = '#0a0a0f' })
  hi('TelescopePromptPrefix',   { fg = '#a855f7',             bg = '#0a0a0f' })
  hi('TelescopePromptCounter',  { fg = '#b8aed0',  bg = '#0a0a0f' })
  hi('TelescopePromptTitle',    { fg = '#0a0a0f',             bg = '#a855f7' })
  hi('TelescopePreviewTitle',   { fg = '#0a0a0f',             bg = '#7c3aed' })
  hi('TelescopeResultsTitle',   { fg = '#0a0a0f',             bg = '#d946ef' })
  hi('TelescopeSelection',      { fg = '#e6e1f0',          bg = '#1e192c' })
  hi('TelescopeSelectionCaret', { fg = '#a855f7',             bg = '#1e192c' })
  hi('TelescopeMatching',       { fg = '#a855f7',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '#e6e1f0',          bg = '#0a0a0f' })
  hi('MiniPickBorder',         { fg = '#605977',             bg = '#0a0a0f' })
  hi('MiniPickPrompt',   { fg = '#e6e1f0',          bg = '#0a0a0f' })
  hi('MiniPickPromptPrefix',   { fg = '#a855f7',             bg = '#0a0a0f' })
  hi('MiniPickBorderText',    { fg = '#0a0a0f',             bg = '#a855f7' })
  hi('MiniPickMatchCurrent',      { fg = '#e6e1f0',          bg = '#1e192c' })
  hi('MiniPickPromptCaret', { fg = '#a855f7',             bg = '#1e192c' })
  hi('MiniPickMatchRanges',       { fg = '#a855f7',             bold = true })
end

-- Register a signal handler for SIGUSR1 (matugen updates).
-- The handler re-requires this module, which re-runs the code below, so the
-- previous handle is stopped first; otherwise handlers double on every signal.
if _G.__matugen_signal then
  _G.__matugen_signal:stop()
  _G.__matugen_signal:close()
end

local signal = vim.uv.new_signal()
_G.__matugen_signal = signal
signal:start(
  'sigusr1',
  vim.schedule_wrap(function()
    package.loaded['matugen'] = nil
    require('matugen').setup()
  end)
)

return M

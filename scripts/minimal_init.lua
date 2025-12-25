-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd("let &rtp.=','.getcwd()")

-- Set up 'mini.test' and 'mini.doc' only when calling headless Neovim (like with `make test` or `make documentation`)
if vim.tbl_isempty(vim.api.nvim_list_uis()) then
  -- Add 'mini.nvim' to 'runtimepath' to be able to use 'mini.test'
  -- Assumed that 'mini.nvim' is stored in 'deps/mini.nvim'
  vim.cmd('set rtp+=deps/mini.nvim')

  require('mini.test').setup()
end
-- vim: set ts=2 sts=2 sw=2 et ai si sta:

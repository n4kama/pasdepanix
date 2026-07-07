{
  programs.nixvim.plugins.lualine = {
    enable = true;

    luaConfig.post = ''
      local status_ok, lualine = pcall(require, 'lualine')
      if not status_ok then
        return
      end

			local clients_lsp = function ()
				local bufnr = vim.api.nvim_get_current_buf()
				local clients = vim.lsp.buf_get_clients(bufnr)
				if next(clients) == nil then
					return ""
				end

				local c = {}
				for _, client in pairs(clients) do
					table.insert(c, client.name)
				end
				return '\u{f085} ' .. table.concat(c, '|')
			end

      local config = {
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch' },
          lualine_c = { 'filename', 'diff' },
          lualine_x = { clients_lsp, 'encoding', 'fileformat', 'filetype'},
          lualine_y = {'progress'},
          lualine_z = {'location'}
        };
      };

      lualine.setup(config)
    '';
  };
}

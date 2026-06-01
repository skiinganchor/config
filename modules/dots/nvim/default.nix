{ ... }:
{
  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
    colorschemes.vscode.enable = true;
    opts = {
      number = true;
      undofile = true;
      encoding = "utf-8";
      signcolumn = "yes";
      belloff = "all";
      wrap = false;
      wildmenu = true;
      modeline = true;
      modelines = 1;
      tabstop = 2;
      softtabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      smarttab = true;
      autoindent = true;
    };
    clipboard = {
      register = "unnamedplus";
      providers.wl-copy.enable = true;
    };
    waylandSupport = true;
    plugins = {
      web-devicons.enable = true;
      lualine.enable = true;
      lazygit.enable = true;
      gitblame.enable = true;
      gitsigns.enable = true;
      indent-blankline.enable = true;
      lastplace.enable = true;
      treesitter.enable = true;
      nvim-autopairs.enable = true;
      blink-cmp.enable = true;
      neo-tree = {
        enable = true;
        settings.window.position = "right";
      };
      lsp = {
        enable = true;
        servers = {
          docker_language_server.enable = true;
          gopls.enable = true;
          jsonls.enable = true;
          just.enable = true;
          markdown_oxide.enable = true;
          nixd.enable = true;
          yamlls.enable = true;
        };
      };
    };
  };
}

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
      relativenumber = false;
      guicursor = "n-v-c-sm:block,i-ci-ve:ver25-Cursor,r-cr-o:hor20";
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
      helm.enable = true;
      blink-cmp.enable = true;
      neo-tree = {
        enable = true;
        settings.window.position = "right";
      };
      lsp = {
        enable = true;
        servers = {
          nixd.enable = true;
          clangd.enable = true;
          gopls.enable = true;
        };
      };
    };
  };
}

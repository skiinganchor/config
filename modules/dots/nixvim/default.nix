{ ... }:
{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    colorschemes.gruvbox.enable = true;

    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    opts = {
      number = true;
      relativenumber = false;
      guicursor = "n-v-c-sm:block,i-ci-ve:ver25-Cursor,r-CR-o:hor20";
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
      hlsearch = false;
      incsearch = true;
      termguicolors = true;
      scrolloff = 8;
      updatetime = 50;
      colorcolumn = "80";
    };

    clipboard = {
      register = "unnamedplus";
      providers.wl-copy.enable = true;
    };

    keymaps = [
      {
        mode = "";
        key = "<space>";
        action = "<nop>";
      }
      {
        mode = "v";
        key = "J";
        action = ":m '>+1<CR>gv=gv";
      }
      {
        mode = "v";
        key = "K";
        action = ":m '<-2<CR>gv=gv";
      }
      {
        mode = "n";
        key = "<leader>fv";
        action = ":LazyGit <CR>";
        options.desc = "Show LazyGit";
      }
      {
        mode = "n";
        key = "<leader>fw";
        action = "<CMD> wa <CR>";
        options.desc = "Write to all files";
      }
      {
        mode = "n";
        key = "<leader>fq";
        action = "<CMD> wqa <CR>";
        options.desc = "Write all buffers, Quit all";
      }
      {
        mode = "n";
        key = "<leader>fx";
        action = "<CMD> qa! <CR>";
        options.desc = "Discard all buffers, Quit all";
      }
      # Neotree
      {
        mode = "n";
        key = "<leader>fns";
        action = "<CMD> Neotree filesystem reveal <CR>";
        options.desc = "Show Neotree";
      }
      {
        mode = "n";
        key = "<leader>fnh";
        action = "<CMD> Neotree filesystem close <CR>";
        options.desc = "Hide Neotree";
      }
      # Telescope
      {
        mode = "n";
        key = "<leader>ff";
        action = "<CMD> Telescope git_files <CR>";
        options.desc = "Open file in Git";
      }
      {
        mode = "n";
        key = "<leader>fa";
        action = "<CMD> Telescope find_files <CR>";
        options.desc = "Open file";
      }
      {
        mode = "n";
        key = "<leader>fg";
        action = "<CMD> Telescope live_grep <CR>";
        options.desc = "Find in files";
      }
      {
        mode = "n";
        key = "<leader>fb";
        action = "<CMD> Telescope buffers <CR>";
        options.desc = "Buffers";
      }
      # LSP
      {
        mode = "n";
        key = "gd";
        action = "<CMD> lua vim.lsp.buf.definition() <CR>";
        options.desc = "Go to definition";
      }
      {
        mode = "n";
        key = "<leader>lh";
        action = "<CMD> lua vim.lsp.buf.hover() <CR>";
        options.desc = "Show hover";
      }
      {
        mode = "n";
        key = "<leader>lf";
        action = "<CMD> lua vim.lsp.buf.format() <CR>";
        options.desc = "Format the file";
      }
      {
        mode = "n";
        key = "<leader>lt";
        action = "<CMD> Trouble diagnostics toggle <CR>";
        options.desc = "Trouble toggle";
      }
    ];

    autoCmd = [
      {
        event = [ "InsertLeave" ];
        pattern = [ "*" ];
        desc = "Format buffer using LSP when leaving insert mode";
        callback = {
          __raw = ''
            function()
              pcall(vim.lsp.buf.format, { async = true })
            end
          '';
        };
      }
    ];

    dependencies = {
      ripgrep.enable = true;
    };

    plugins = {
      web-devicons.enable = true;
      lualine.enable = true;
      lazygit.enable = true;
      gitblame.enable = true;
      gitsigns.enable = true;
      indent-blankline.enable = true;
      treesitter.enable = true;
      nvim-autopairs.enable = true;
      telescope.enable = true;
      trouble.enable = true;
      lsp = {
        enable = true;
        servers = {
          nixd.enable = true;
          gopls.enable = true;
        };
      };
      blink-cmp = {
        enable = true;
        setupLspCapabilities = true;
        settings = {
          signature.enabled = true;
          completion.documentation.auto_show = true;
          keymap = {
            "<C-space>" = [
              "show"
              "show_documentation"
              "hide_documentation"
            ];
            "<CR>" = [
              "accept"
              "fallback"
            ];
            "<Tab>" = [
              "select_next"
              "snippet_forward"
              "fallback"
            ];
            "<S-Tab>" = [
              "select_prev"
              "snippet_backward"
              "fallback"
            ];
          };
        };
      };
      which-key = {
        enable = true;
        settings = {
          spec = [
            {
              __unkeyed-1 = "<leader>f";
              group = "+Find/Files";
            }
            {
              __unkeyed-1 = "<leader>fn";
              group = "+Neotree";
            }
            {
              __unkeyed-1 = "<leader>l";
              group = "+LSP";
            }
          ];
        };
      };
      toggleterm = {
        enable = true;
        settings = {
          direction = "float";
          open_mapping = "[[<c-\\>]]";
        };
      };
      neo-tree = {
        enable = true;
        settings = {
          close_if_last_window = true;
          filesystem = {
            filtered_items = {
              visible = true;
            };
            follow_current_file = {
              enabled = true;
              leave_dirs_open = false;
            };
          };
          window = {
            position = "right";
            mappings = {
              "<space>" = "none";
              "h" = "close_node";
              "l" = "open";
            };
          };
        };
      };
    };
  };
}

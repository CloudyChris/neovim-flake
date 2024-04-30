{ pkgs
, config
, lib
, ...
}:
with lib;
with builtins; let
  cfg = config.vim.languages.sql;
  sqlfluffDefault = "sqlfluff";

  defaultServer = "sqlls";
  servers = {
    sqlls = {
      package = [ "sqls" ];
      lspConfig = /* lua */ ''
        lspconfig.sqlls.setup {
          on_attach = function(client, bufnr)
            client.server_capabilities.execute_command = true
            on_attach_keymaps(client, bufnr)
            require'sqlls'.on_attach(client, bufnr)
          end,
          cmd = {"${nvim.languages.commandOptToCmd cfg.lsp.package "sqlls"}", "-config", string.format("%s/config.yml", vim.fn.getcwd()) }
        }
      '';
    };
  };

  defaultFormat = "sqlfluff";
  formats = {
    sqlfluff = {
      package = [ sqlfluffDefault ];
      nullConfig = /* lua */ ''
        table.insert(
          ls_sources,
          null_ls.builtins.formatting.sqlfluff.with({
            command = "${nvim.languages.commandOptToCmd cfg.format.package "sqlfluff"}",
            extra_args = {"--dialect", "${cfg.dialect}"}
          })
        )
      '';
    };
  };

  defaultDiagnostics = [ "sqlfluff" ];
  diagnostics = {
    sqlfluff = {
      package = pkgs.${sqlfluffDefault};
      nullConfig = pkg: /* lua */ ''
        table.insert(
          ls_sources,
          null_ls.builtins.diagnostics.sqlfluff.with({
            command = "${pkg}/bin/sqlfluff",
            extra_args = {"--dialect", "${cfg.dialect}"}
          })
        )
      '';
    };
  };
in
{
  options.vim.languages.sql = {
    enable = mkEnableOption "SQL language support";

    dialect = mkOption {
      description = "SQL dialect for sqlfluff (if used)";
      type = types.str;
      default = "ansi";
    };

    treesitter = {
      enable = mkOption {
        description = "Enable SQL treesitter";
        type = types.bool;
        default = config.vim.languages.enableTreesitter;
      };
      package = nvim.options.mkGrammarOption pkgs "sql";
    };

    lsp = {
      enable = mkOption {
        description = "Enable SQL LSP support";
        type = types.bool;
        default = config.vim.languages.enableLSP;
      };
      server = mkOption {
        description = "SQL LSP server to use";
        type = with types; enum (attrNames servers);
        default = defaultServer;
      };
      package = nvim.options.mkCommandOption pkgs {
        description = "SQL LSP server";
        inherit (servers.${cfg.lsp.server}) package;
      };
    };

    format = {
      enable = mkOption {
        description = "Enable SQL formatting";
        type = types.bool;
        default = config.vim.languages.enableFormat;
      };
      type = mkOption {
        description = "SQL formatter to use";
        type = with types; enum (attrNames formats);
        default = defaultFormat;
      };
      package = nvim.options.mkCommandOption pkgs {
        description = "SQL formatter";
        inherit (formats.${cfg.format.type}) package;
      };
    };

    extraDiagnostics = {
      enable = mkOption {
        description = "Enable extra SQL diagnostics";
        type = types.bool;
        default = config.vim.languages.enableExtraDiagnostics;
      };
      types = lib.nvim.options.mkDiagnosticsOption {
        langDesc = "SQL";
        inherit diagnostics;
        inherit defaultDiagnostics;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.treesitter.enable {
      vim.treesitter.enable = true;
      vim.treesitter.grammars = [ cfg.treesitter.package ];
    })

    (mkIf cfg.lsp.enable {
      vim.startPlugins = [ "sqlls-nvim" ];

      vim.lsp.lspconfig.enable = true;
      vim.lsp.lspconfig.sources.sql-lsp = servers.${cfg.lsp.server}.lspConfig;
    })

    (mkIf cfg.format.enable {
      vim.lsp.null-ls.enable = true;
      vim.lsp.null-ls.sources."sql-format" = formats.${cfg.format.type}.nullConfig;
    })

    (mkIf cfg.extraDiagnostics.enable {
      vim.lsp.null-ls.enable = true;
      vim.lsp.null-ls.sources = lib.nvim.languages.diagnosticsToLua {
        lang = "sql";
        config = cfg.extraDiagnostics.types;
        inherit diagnostics;
      };
    })
  ]);
}

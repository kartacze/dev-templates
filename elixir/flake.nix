{
  description = "Flake based elixir development environment";

  # that needs some more specification
  inputs = { nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable"; };

  outputs = inputs:
    let
      supportedSystems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (system:
          f {
            pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [ inputs.self.overlays.default ];
            };
          });
    in {
      overlays.default = final: prev: rec {
        # documentation
        # https://nixos.org/manual/nixpkgs/stable/#sec-beam

        # ==== ERLANG ====

        # use whatever version is currently defined in nixpkgs
        # erlang = pkgs.beam.interpreters.erlang;

        # use latest version of Erlang 27
        erlang = final.beam.interpreters.erlang_28;

        # specify exact version of Erlang OTP
        # erlang = pkgs.beam.interpreters.erlang.override {
        #   version = "26.2.2";
        #   sha256 = "sha256-7S+mC4pDcbXyhW2r5y8+VcX9JQXq5iEUJZiFmgVMPZ0=";
        # }

        # ==== BEAM packages ====

        # all BEAM packages will be compile with your preferred erlang version
        pkgs-beam = final.beam.packagesWith erlang;

        # ==== Elixir ====

        # use whatever version is currently defined in nixpkgs
        # elixir = pkgs-beam.elixir;

        # use latest version of Elixir 1.17
        elixir = pkgs-beam.elixir_1_18;

        # specify exact version of Elixir
        # elixir = pkgs-beam.elixir.override {
        #   version = "1.17.1";
        #   sha256 = "sha256-a7A+426uuo3bUjggkglY1lqHmSbZNpjPaFpQUXYtW9k=";
        # };
      };

      devShells = forEachSupportedSystem ({ pkgs }: {

        default = pkgs.mkShell {
          packages = with pkgs;
            [
              # use the Elixr/OTP versions defined above; will also install OTP, mix, hex, rebar3
              elixir
              erlang

              # mix needs it for downloading dependencies
              git

              # probably needed for your Phoenix assets
              nodejs_22
              watchman
              glibcLocalesUtf8
            ] ++
            # Linux only
            pkgs.lib.optionals pkgs.stdenv.isLinux
            (with pkgs; [ gigalixir inotify-tools libnotify ]) ++
            # macOS only
            pkgs.lib.optionals pkgs.stdenv.isDarwin
            (with pkgs; [ terminal-notifier ]);

          shellHook = ''
            if ! test -d .nix-shell; then
              mkdir .nix-shell
            fi


            export NIX_SHELL_DIR=$PWD/.nix-shell

            export MIX_HOME=$NIX_SHELL_DIR/.mix
            export MIX_ARCHIVES=$MIX_HOME/archives
            export HEX_HOME=$NIX_SHELL_DIR/.hex

            export PATH=$MIX_HOME/bin:$PATH
            export PATH=$HEX_HOME/bin:$PATH
            export PATH=$MIX_HOME/escripts:$PATH
            export LIVEBOOK_HOME=$PWD

          '';

        };
      });
    };
}

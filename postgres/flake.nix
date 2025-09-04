{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-25.05-darwin";
    flake-utils = { url = "github:numtide/flake-utils"; };
  };

  outputs = { self, nixpkgs, flake-utils, }:

    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        postgresql = pkgs.postgresql_17;

      in {
        devShell = pkgs.mkShell {
          buildInputs = [
            postgresql

            (pkgs.writeShellScriptBin "gicz-setup" ''
              mix archive.install hex phx_new
            '')
            (pkgs.writeShellScriptBin "pg-stop" ''
              pg_ctl -D $PGDATA -U postgres stop
            '')
            (pkgs.writeShellScriptBin "pg-reset" ''
              rm -rf $PGDATA
            '')
            (pkgs.writeShellScriptBin "pg-setup" ''
              if ! test -d $PGDATA; then
                ######################################################
                # Init PostgreSQL
                ######################################################
                pg_ctl initdb -D  $PGDATA
                #### initdb --locale=C --encoding=UTF8 --auth-local=peer --auth-host=scram-sha-256 > /dev/null || exit
                # initdb --encoding=UTF8 --no-locale --no-instructions -U postgres
                ######################################################
                # PORT ALREADY IN USE
                ######################################################
                # If another `nix-shell` is  running with a PostgreSQL
                # instance,  the logs  will show  complaints that  the
                # default port 5432  is already in use.  Edit the line
                # below with  a different  port number,  uncomment it,
                # and try again.
                ######################################################
                if [[ "$PGPORT" ]]; then
                  sed -i "s|^#port.*$|port = $PGPORT|" $PGDATA/postgresql.conf
                fi
                echo "listen_addresses = ${"'"}${
                  "'"
                }" >> $PGDATA/postgresql.conf
                echo "unix_socket_directories = '$PGDATA'" >> $PGDATA/postgresql.conf
                echo "CREATE USER postgres WITH PASSWORD 'postgres' CREATEDB SUPERUSER;" | postgres --single -E postgres
              fi
            '')
            (pkgs.writeShellScriptBin "pg-start" ''
              [ ! -d $PGDATA ] && pg-setup
              HOST_COMMON="host\s\+all\s\+all"
              sed -i "s|^$HOST_COMMON.*127.*$|host all all 0.0.0.0/0 trust|" $PGDATA/pg_hba.conf
              sed -i "s|^$HOST_COMMON.*::1.*$|host all all ::/0 trust|"      $PGDATA/pg_hba.conf

              pg_ctl                                                  \
                -D $PGDATA                                            \
                -l $PGDATA/postgres.log                               \
                -o "-c unix_socket_directories='$PGDATA'"             \
                -o "-c listen_addresses='*'"                          \
                -o "-c log_destination='stderr'"                      \
                -o "-c logging_collector=on"                          \
                -o "-c log_directory='log'"                           \
                -o "-c log_filename='postgresql-%Y-%m-%d_%H%M%S.log'" \
                -o "-c log_min_messages=info"                         \
                -o "-c log_min_error_statement=info"                  \
                -o "-c log_connections=on"                            \
                start
            '')
          ];
          shellHook = ''
            if ! test -d .nix-shell; then
              mkdir .nix-shell
            fi


            # to connect to postgres using psql 
            export PGDATABASE=postgres
            export PGUSER=postgres
            export PGHOST=localhost
            export PGPORT=5432

            export NIX_SHELL_DIR=$PWD/.nix-shell
            # Put the PostgreSQL databases in the project directory.
            export PGDATA=$NIX_SHELL_DIR/db

          '';
        };
      });

}

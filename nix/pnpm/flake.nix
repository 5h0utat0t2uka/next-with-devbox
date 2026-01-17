{
  description = "Pinned pnpm that runs on pinned Node";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pinnedNodeFlake.url = "path:../node";
    pinnedNodeFlake.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, pinnedNodeFlake, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };

          pinnedNode = pinnedNodeFlake.packages.${system}.node;
          nodeExe = "${pinnedNode}/bin/node";

          pnpmVersion = "10.26.1";
          src = pkgs.fetchurl {
            url = "https://registry.npmjs.org/pnpm/-/pnpm-${pnpmVersion}.tgz";
            hash = "sha256-6ObkmRKPaAT1ySIjzR8uP2JVcQLAxuJUzJm7KqIpu/k=";
          };
        in
        {
          pnpm = pkgs.stdenvNoCC.mkDerivation {
            pname = "pnpm";
            version = pnpmVersion;
            inherit src;

            nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              mkdir -p "$out/libexec" "$out/bin"
              tar -xzf "$src"
              cp -R package/* "$out/libexec/"

              cat > "$out/bin/pnpm" <<EOF
              #!${pkgs.runtimeShell}
              exec "${nodeExe}" "$out/libexec/bin/pnpm.cjs" "\$@"
              EOF
              chmod +x "$out/bin/pnpm"
            '';
          };
          default = self.packages.${system}.pnpm;
        });
    };
}

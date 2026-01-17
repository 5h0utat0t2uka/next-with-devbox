{
  description = "Pinned pnpm that runs on the pinned Node (no corepack, no npm -g)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # あなたの node flake を参照（相対パスでOK）
    node.url = "path:../node";
    node.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, node, ... }:
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
          pinnedNode = node.packages.${system}.node;
          pnpmVersion = "10.26.1";

          # pnpm は本体が JS なので、tarball を fetch してラッパーを作る
          src = pkgs.fetchurl {
            url = "https://registry.npmjs.org/pnpm/-/pnpm-${pnpmVersion}.tgz";
            hash = "sha256-6ObkmRKPaAT1ySIjzR8uP2JVcQLAxuJUzJm7KqIpu/k=";
          };

          pkg = pkgs.stdenvNoCC.mkDerivation {
            pname = "pnpm";
            version = pnpmVersion;
            inherit src;

            nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              runHook preInstall
              mkdir -p $out/libexec $out/bin

              # npm tarball は "package/" 配下に展開される
              tar -xzf $src
              cp -R package/* $out/libexec/

              # pnpm CLI を pinned node で起動するラッパーを作る（shebang固定の問題を回避）
              cat > $out/bin/pnpm <<'EOF'
              #!${pkgs.runtimeShell}
              exec "${pinnedNode}/bin/node" "${self}/libexec/bin/pnpm.cjs" "$@"
              EOF

              # ↑の self 参照を解決するため、あとで置換
              substituteInPlace $out/bin/pnpm \
                --replace-fail "${self}/libexec" "$out/libexec"

              chmod +x $out/bin/pnpm
              runHook postInstall
            '';
          };
        in
        {
          pnpm = pkg;
          default = pkg;
        });
    };
}

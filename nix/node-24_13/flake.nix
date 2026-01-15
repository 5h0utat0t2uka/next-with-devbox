{
  description = "Node.js 24.13.0 (prebuilt) for Devbox";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
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

          url =
            if system == "aarch64-darwin" then
              "https://nodejs.org/dist/v24.13.0/node-v24.13.0-darwin-arm64.tar.gz"
            else if system == "x86_64-darwin" then
              "https://nodejs.org/dist/v24.13.0/node-v24.13.0-darwin-x64.tar.gz"
            else if system == "aarch64-linux" then
              "https://nodejs.org/dist/v24.13.0/node-v24.13.0-linux-arm64.tar.xz"
            else
              "https://nodejs.org/dist/v24.13.0/node-v24.13.0-linux-x64.tar.xz";

          # まずダミーで動かして、後で `nix store prefetch-file` の結果に差し替えます
          src = pkgs.fetchurl {
            inherit url;
            sha256 = pkgs.lib.fakeSha256;
          };
        in
        {
          node = pkgs.stdenvNoCC.mkDerivation {
            pname = "nodejs";
            version = "24.13.0";
            inherit src;

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              mkdir -p $out
              tar -xf $src --strip-components=1 -C $out
            '';
          };
        });
    };
}

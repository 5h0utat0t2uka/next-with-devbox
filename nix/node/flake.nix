{
  description = "Pinned Node.js (prebuilt) for Devbox";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;

      # -----------------------------
      # Update only this
      # -----------------------------
      version = "24.13.0";
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f system);

      # Pick the official Node.js prebuilt artifact per platform
      nodeDist = system:
        let
          base = "https://nodejs.org/dist/v${version}";
        in
        if system == "aarch64-darwin" then {
          url = "${base}/node-v${version}-darwin-arm64.tar.gz";
          unpack = "tar -xzf";
        } else if system == "x86_64-darwin" then {
          url = "${base}/node-v${version}-darwin-x64.tar.gz";
          unpack = "tar -xzf";
        } else if system == "aarch64-linux" then {
          url = "${base}/node-v${version}-linux-arm64.tar.xz";
          unpack = "tar -xJf";
        } else if system == "x86_64-linux" then {
          url = "${base}/node-v${version}-linux-x64.tar.xz";
          unpack = "tar -xJf";
        } else
          throw "Unsupported system: ${system}";

      # -----------------------------
      # Hashes (one per system)
      # Fill these once by the steps below
      # -----------------------------
      hashes = {
        # macOS（Apple Silicon / ARM64）
        aarch64-darwin = "sha256-1ZWWHlY/yuBX1KD7mS8XWlTZf8xKFNwtR02S3e6jufg=";
        # macOS（Intel / x86_64）
        x86_64-darwin  = lib.fakeSha256;
        # Linux（ARM64）
        aarch64-linux  = lib.fakeSha256;
        # Linux（ARM64）
        x86_64-linux   = lib.fakeSha256;
      };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          dist = nodeDist system;

          src = pkgs.fetchurl {
            url = dist.url;
            sha256 = hashes.${system};
          };
        in
        {
          # Use as: path:./nix/node#node
          node = pkgs.stdenvNoCC.mkDerivation {
            pname = "nodejs";
            inherit version src;

            dontConfigure = true;
            dontBuild = true;
            installPhase = ''
              mkdir -p "$out"
              ${dist.unpack} "$src" --strip-components=1 -C "$out"
            '';
            meta = with lib; {
              description = "Node.js ${version} (official prebuilt binary tarball)";
              homepage = "https://nodejs.org/";
              platforms = platforms.all;
            };
          };
        });
    };
}

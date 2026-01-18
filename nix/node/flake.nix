{
  description = "Pinned Node.js (prebuilt) + pnpm for Devbox";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;

      # -----------------------------
      # Update only this
      # -----------------------------
      nodeVersion = "24.13.0";
      pnpmVersion = "10.26.1";

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
          base = "https://nodejs.org/dist/v${nodeVersion}";
        in
        if system == "aarch64-darwin" then {
          url = "${base}/node-v${nodeVersion}-darwin-arm64.tar.gz";
          unpack = "tar -xzf";
        } else if system == "x86_64-darwin" then {
          url = "${base}/node-v${nodeVersion}-darwin-x64.tar.gz";
          unpack = "tar -xzf";
        } else if system == "aarch64-linux" then {
          url = "${base}/node-v${nodeVersion}-linux-arm64.tar.xz";
          unpack = "tar -xJf";
        } else if system == "x86_64-linux" then {
          url = "${base}/node-v${nodeVersion}-linux-x64.tar.xz";
          unpack = "tar -xJf";
        } else
          throw "Unsupported system: ${system}";

      # -----------------------------
      # Hashes (one per system)
      # -----------------------------
      nodeHashes = {
        aarch64-darwin = "sha256-1ZWWHlY/yuBX1KD7mS8XWlTZf8xKFNwtR02S3e6jufg=";
        x86_64-darwin  = lib.fakeSha256;
        aarch64-linux  = lib.fakeSha256;
        x86_64-linux   = lib.fakeSha256;
      };
      pnpmHash = "sha256-6ObkmRKPaAT1ySIjzR8uP2JVcQLAxuJUzJm7KqIpu/k=";
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          dist = nodeDist system;

          nodeSrc = pkgs.fetchurl {
            url = dist.url;
            sha256 = nodeHashes.${system};
          };
          # Node.js derivation
          nodeDrv = pkgs.stdenvNoCC.mkDerivation {
            name = "nodejs";
            inherit nodeVersion;
            src = nodeSrc;

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

          # pnpm を Nix で固定（nodeDrv の /bin/node で起動するラッパーを作る）
          pnpmSrc = pkgs.fetchurl {
            url = "https://registry.npmjs.org/pnpm/-/pnpm-${pnpmVersion}.tgz";
            hash = pnpmHash;
          };

          pnpmDrv = pkgs.stdenvNoCC.mkDerivation {
            name = "pnpm";
            version = pnpmVersion;
            src = pnpmSrc;

            nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              mkdir -p "$out/libexec" "$out/bin"
              # npm tarball は package/ 配下
              tar -xzf "$src"
              cp -R package/* "$out/libexec/"
              # Node のストアパスを固定して pnpm を起動
              cat > "$out/bin/pnpm" <<EOF
              #!${pkgs.runtimeShell}
              exec "${nodeDrv}/bin/node" "$out/libexec/bin/pnpm.cjs" "\$@"
              EOF
              chmod +x "$out/bin/pnpm"
            '';
          };
        in
        {
          # Use as: path:./nix/node#node
          node = nodeDrv;
          # Use as: path:./nix/node#pnpm
          pnpm = pnpmDrv;
          default = nodeDrv;
        });
    };
}

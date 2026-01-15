This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).  

このリポジトリは`devbox`, `pnpm`を利用して、セキュアな **Next.js** の開発環境を、異なるOSや開発者間の環境で再現するためのサンプルです  
また、できるだけ早い`node`の最新バージョンへの追従のため、パッケージの参照先に一部`nix`を利用します  

## 前提条件  
対象OS  
- macOS (Apple Silicon, Intel)
- Linux (x86_64, aarch64)
- Windows: WSL2 (Ubuntu recommended)

インストールが必要なもの  
1. [Determinate Nix](https://determinate.systems/nix-installer/)  
2. [Devbox](https://www.jetify.com/devbox)  

## 開発環境  
`devbox.json`で定義している以下のコマンドで可能です  
```sh
# Install dependencies
devbox run install
# Start development server
devbox run dev
# Build production version
devbox run build
```

もしくは`devbox shell`で開発環境を直接起動できます  
終了は`exit`です  
```sh
# Launch devbox shell
devbox shell
# Install dependencies
pnpm install --frozen-lockfile
# Start development server
pnpm dev
# Build production version
pnpm build
```

## `node`のバージョン更新  
1. `nix/node/flake.nix`の下記`version`を更新  
``` nix
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
```

2. 以下のコマンドでビルド実行  
``` sh
cd nix/node
nix build .#node
```

3. 実行後、以下のような`hash mismatch`のエラーになるので、本来指定すべき`got:`以降のハッシュ値をコピー  
``` sh
• Added input 'nixpkgs':
    'github:NixOS/nixpkgs/1412caf' (2026-01-13)
error: hash mismatch in fixed-output derivation '/nix/store/jdaj3m3vni2w5q7bkzlrw0nahqrfsr4c-node-v24.13.0-darwin-arm64.tar.gz.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-1ZWWHlY/yuBX1KD7mS8XWlTZf8xKFNwtR02S3e6jufg=
```

4. `nix/node/flake.nix`で、コピーしたハッシュ値を下記の自身のOSに合わせて更新する  
``` nix
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
```

5. (2)の手順で再度ビルド
``` sh
cd nix/node
nix build .#node
```

6. プロジェクトルートに戻り、バージョン確認  
``` sh
devbox shell
node -v
exit
```

> [!Tip]
> (2)の手順で失敗させて正しいハッシュ値を確認してますが、以下のコマンドで事前にハッシュを取得することも可能です  
> バージョンは適時書き換えてください  

- macOS Apple Silicon（aarch64-darwin）  
``` sh
nix store prefetch-file https://nodejs.org/dist/v24.13.0/node-v24.13.0-darwin-arm64.tar.gz
```

- macOS Intel（x86_64-darwin）  
``` sh
nix store prefetch-file https://nodejs.org/dist/v24.13.0/node-v24.13.0-darwin-x64.tar.gz
```

- Linux ARM64（aarch64-linux）  
``` sh
nix store prefetch-file https://nodejs.org/dist/v24.13.0/node-v24.13.0-linux-arm64.tar.xz
```

- Linux x86_64（x86_64-linux）  
``` sh
nix store prefetch-file https://nodejs.org/dist/v24.13.0/node-v24.13.0-linux-x64.tar.xz
```

> [!NOTE]
> `node`のバージョンを厳格に管理しない場合は、`devbox.json`の`packages`の配列で参照してる`"path:./nix/node#node"`を`"nodejs_24@latest"`に変更してください  
> その場合は`nix/node/flake.nix`の更新も不要です

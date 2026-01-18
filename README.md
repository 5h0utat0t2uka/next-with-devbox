## 構成  
このリポジトリは`devbox`, `pnpm`, `infisical`を利用して、セキュアな **Next.js** の開発環境を、異なるOSや開発者間の環境で再現するためのサンプルです  

`devbox`は`nix`を簡単に扱えるようになるラッパーですが、できるだけ早い`node`の最新バージョンへの追従するための参考として、このリポジトリではパッケージの参照先に一部`nix`を利用します  

### 目的と趣旨  
- 各ユーザー環境の`node`や`pnpm`のバージョンやインストール有無に関わらず、隔離された共通の開発環境にする
- `osv-scanner` を利用して、依存関係をインストールする前にロックファイルからパッケージの脆弱性を確認する
- `infisical`を利用したシークレット管理を行い、平文のシークレットをローカルに持たない  
- サプライチェーン攻撃・パッケージ汚染の対策として、信用するパッケージを除いてレジストリ公開後24時間未満のパッケージをインストールしない [^1]  
- インストール時の`preinstall`や`postinstall`などのビルドスクリプトは、明示的に許可したパッケージ以外は実行させない [^2]  

[^1]: 悪意のあるパッケージは多くの場合レジストリ公開後数時間程度で削除されるため、インストール自体を未然に防ぐための対策です  
[^2]: インストール時のスクリプトをトリガとする感染を防ぐための対策です  

## 前提条件  
対象OS  
- macOS (Apple Silicon, Intel)
- Linux (x86_64, aarch64)
- Windows: WSL2 (Ubuntu recommended)

事前にインストールが必要なもの  
- [Determinate Nix](https://determinate.systems/nix-installer/)  
- [Devbox](https://www.jetify.com/devbox)  

## 開発環境  
`devbox.json`で定義している以下のコマンドが利用可能です  
```sh
# Scan existing vulnerabilities from lockfile
devbox run scan
# Install dependencies
devbox run install
# Start development server
devbox run dev
# Build production version
devbox run build
```

もしくは`devbox shell`で開発環境を直接起動することもできます  
```sh
# Launch devbox shell
devbox shell
# Scan existing vulnerabilities from lockfile
pnpm scan
# Install dependencies
pnpm install --frozen-lockfile
# Start development server
pnpm dev
# Build production version
pnpm build
# Exit devbox shell
exit
```
終了は`exit`です  

## バージョン管理  
以下の2つのレイヤーに分けて管理されます  
- 開発環境  
従来各ユーザーに委ねられていた部分で、主に`node`や`pnpm`などのパッケージマネージャを`devbox.json`で管理します  
後述する`node`のバージョン固定するようなケース以外では、以下のコマンドでアップデートします
```sh
devbox update
```

- アプリケーション  
`next`や`react`などのライブラリは、通常通り`package.json`で管理されるので、以下のように`ncu`で確認・アップデートを行います  
``` sh
ncu -u
pnpm install
```

## `node`のバージョン更新  
> [!NOTE]
> これは`nixpkgs`に最新のバージョンが反映されるまでにタイムラグがあるため、必要な場合に`nodejs`から直接最新バージョンを取り込むための参考としてのもので、必須ではありません  

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

``` sh
# macOS Apple Silicon（aarch64-darwin）
nix store prefetch-file https://nodejs.org/dist/v24.13.0/node-v24.13.0-darwin-arm64.tar.gz

# macOS Intel（x86_64-darwin）
nix store prefetch-file https://nodejs.org/dist/v24.13.0/node-v24.13.0-darwin-x64.tar.gz

# Linux ARM64（aarch64-linux）
nix store prefetch-file https://nodejs.org/dist/v24.13.0/node-v24.13.0-linux-arm64.tar.xz

# Linux x86_64（x86_64-linux）
nix store prefetch-file https://nodejs.org/dist/v24.13.0/node-v24.13.0-linux-x64.tar.xz
```


> [!NOTE]
> `node`のバージョンを厳格に管理しない場合は、`devbox.json`の`packages`の配列で参照してる`"path:./nix/node#node"`を`"nodejs_24@latest"`に変更してください  
> その場合は`nix/node/flake.nix`の更新も不要です

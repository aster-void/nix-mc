# CLAUDE.md

このファイルは、このリポジトリでコードを扱う際にClaude Code (claude.ai/code)へのガイダンスを提供します。

## プロジェクト概要

これはMinecraftサーバー（Forge、NeoForge、Bedrock版）を実行するためのNixOSモジュールを提供するNix flakeです。このモジュールは適切なセキュリティ強化とファイル管理を備えたsystemdサービスを作成します。

## アーキテクチャ

**コアコンポーネント:**
- `flake.nix`: NixOSモジュールを公開するエントリーポイント
- `nixosModules/nix-mc.nix`: Minecraftサーバー管理を実装するメインNixOSモジュール

**主要な設計パターン:**
- **関心の分離**: `upstreamDir`（読み取り専用サーバーファイル） vs `dataDir`（永続的ワールドデータ）
- **セキュリティ強化**: Systemdサービスは`NoNewPrivileges`、`ProtectSystem=strict`、制限されたケーパビリティで実行
- **ファイル同期戦略**: 異なるコンテンツタイプに対するシンボリックリンク vs ファイルコピーの設定可能な選択
- **マルチサーバー対応**: 単一のモジュールが個別設定を持つ複数のサーバーインスタンスを管理

**サービスアーキテクチャ:**
- 各サーバーは独自の`minecraft-${name}` systemdサービスを持つ
- サーバータイプごとの自動ファイアウォール管理（Java用TCP 25565、Bedrock用UDP 19132）
- 事前開始同期スクリプトがupstreamからdataディレクトリへのファイル/シンボリックリンクセットアップを処理

## 開発コマンド

**モジュール構文のテスト:**
```bash
nix flake check
```

**ビルド/評価:**
```bash
nix eval .#nixosModules.nix-mc
```

## 設定パターン

**サーバー定義構造:**
- `type`: "forge" | "neoforge" | "bedrock"
- `upstreamDir`: プリインストールされたサーバーファイル（読み取り専用）
- `dataDir`: 永続的ランタイムデータ（デフォルト: `/var/lib/minecraft/${name}`）
- `symlinks`: シンボリックリンクするディレクトリ（例：mods、config）
- `files`: 起動時にコピーするファイル/ディレクトリ（例：server.properties）

**セキュリティモデル:**
- サービスは専用の`minecraft`ユーザー/グループで実行
- `ProtectSystem=strict`による厳格なファイルシステム分離
- `dataDir`のみが書き込み可能
- 昇格された権限やケーパビリティなし

**ポートのデフォルト:**
- Javaサーバー（forge/neoforge）: TCP 25565
- Bedrockサーバー: UDP 19132

## 主要関数

- `mkSyncScript`: ファイル同期用の事前開始スクリプトを生成
- `mkService`: サーバー用のsystemdサービス設定を作成
- `defaultsFor`: タイプ固有のデフォルト（ポートなど）を提供
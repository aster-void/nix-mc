# Development Documentation

内部開発者向けドキュメント

## アーキテクチャ概要

### モジュール構造

```
nixosModules/nix-mc.nix
├── options定義
│   ├── services.minecraft.enable
│   ├── services.minecraft.user/group
│   ├── services.minecraft.openFirewall
│   └── services.minecraft.servers.<name>
│       ├── type (forge|neoforge|bedrock)
│       ├── upstreamDir (サーバーファイル)
│       ├── dataDir (永続データ)
│       ├── ports (tcp/udp)
│       └── その他設定
├── 設定生成ロジック
│   ├── mkSyncScript (ファイル同期)
│   ├── mkService (systemdサービス生成)
│   └── defaultsFor (サーバータイプ別デフォルト)
└── config実装
    ├── ユーザー/グループ作成
    ├── systemdサービス生成
    └── ファイアウォール設定
```

### 重要な設計原則

#### 1. 無限再帰の回避
- **問題**: `cfg = config.services.minecraft`による循環参照
- **解決**: configセクション内では`minecraftCfg = config.services.minecraft`として局所化
- **NG例**: configセクション内で`cfg.servers`を参照
- **OK例**: `minecraftCfg.servers`を参照

#### 2. サーバータイプ別デフォルト処理
- Javaサーバー (forge/neoforge): TCP 25565
- Bedrockサーバー: UDP 19132
- ポート設定が空の場合のみデフォルト適用

#### 3. ファイル同期戦略
- **symlinks**: 読み取り専用コンテンツ (mods, config)
- **files**: 書き込み可能コンテンツ (server.properties)
- upstreamDir → dataDir への適切な配置

## 開発ワークフロー

### テスト方法

1. **基本評価テスト**
   ```bash
   nix flake check
   ```

2. **モジュール評価テスト**
   ```bash
   nix-instantiate --eval tests/test-recursion.nix
   ```

3. **実際のNixOSビルドテスト**
   ```bash
   nixos-rebuild dry-build --no-flake -I nixos-config=configuration.nix
   ```

### CI/CD

GitHub Actionsで自動テスト:
- `nix flake check`: 基本構文チェック
- モジュール評価テスト: 無限再帰防止確認
- NixOSビルドテスト: 実際の使用可能性確認

## トラブルシューティング

### よくある問題

#### 1. 無限再帰エラー
```
error: infinite recursion encountered
```

**原因**: configセクション内でcfgを再帰的に参照

**確認ポイント**:
- `let cfg = config.services.minecraft` の使用場所
- configセクション内での`cfg.*`参照
- submodule内での親設定参照

**修正方法**:
- configセクション内では`let minecraftCfg = config.services.minecraft`を使用
- submodule内では`config`パラメータを活用

#### 2. systemdサービスエラー
```
error: The option `systemd.services.{name}.ExecStart' does not exist
```

**原因**: systemdサービス構造の不正

**確認ポイント**:
- `ExecStart`/`ExecStartPre`がserviceConfig内にあるか
- サービス名が`minecraft-${name}`形式になっているか
- 必要な属性が正しく`inherit`されているか

#### 3. 型エラー
```
error: A definition for option `...` is not of type `...`
```

**原因**: オプション型定義と実際の使用の不整合

**確認ポイント**:
- `ExecStartPre`: `listOf str` vs `str`
- `files`: `listOf str` vs `attrsOf path`
- `ports.*`: `listOf int`のデフォルト値

### デバッグ方法

1. **詳細トレース有効化**
   ```bash
   nix-instantiate --eval --show-trace
   nixos-rebuild dry-build --show-trace
   ```

2. **段階的な設定追加**
   - 最小構成から開始
   - サーバーを1つずつ追加
   - オプションを段階的に設定

3. **モジュール分離テスト**
   ```bash
   nix-instantiate --eval --expr '
     let lib = (import <nixpkgs> {}).lib;
     in lib.evalModules {
       modules = [ ./nixosModules/nix-mc.nix ];
     }'
   ```

## 将来の拡張ポイント

### 計画中の機能
- [ ] NeoForgeサーバー専用設定
- [ ] プラグイン管理機能
- [ ] バックアップ自動化
- [ ] パフォーマンス監視

### アーキテクチャ改善案
- [ ] マルチバージョン対応
- [ ] 設定テンプレート機能
- [ ] モジュラー設定システム

## 注意事項

### セキュリティ
- サービスは専用ユーザーで実行
- ファイルシステム分離 (`ProtectSystem=strict`)
- 権限最小化 (`NoNewPrivileges=true`)

### パフォーマンス
- ファイル同期は起動時のみ実行
- symlink使用で重複排除
- systemdによる適切なリソース管理

### 保守性
- 設定パターンの統一
- エラーメッセージの明確化
- テストカバレッジの維持
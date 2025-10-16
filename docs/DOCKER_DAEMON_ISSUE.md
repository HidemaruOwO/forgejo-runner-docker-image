# Docker Daemon Connection Issue - Root Cause and Solution

## 問題の根本原因 (Root Cause)

`node20-dind` イメージを Forgejo Actions で実行すると以下のエラーが発生する：

```
ERROR: Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

### なぜこのエラーが発生するのか？

1. **Docker-in-Docker (DinD) の仕組み**
   - `docker:dind` ベースのイメージは、コンテナ内で独立した Docker デーモンを実行します
   - このデーモンは自動的には起動せず、明示的に起動する必要があります

2. **Forgejo Actions での設定不足**
   - ワークフローで `container:` を使用する場合、デフォルトでは privileged モードが有効になっていません
   - Docker デーモンを起動するための設定が不足していました

3. **Docker ソケットへのアクセス**
   - DinD イメージを使用する場合、独自のソケット (`/var/run/docker.sock`) を作成します
   - デーモンが起動していない場合、このソケットは存在しないため接続エラーが発生します

## 解決方法 (Solutions)

### 方法1: Docker-in-Docker (DinD) - 完全な分離

この方法は最も安全で、完全な分離を提供します。

```yaml
jobs:
  build:
    runs-on: docker
    container:
      image: ghcr.io/hidemaruowo/forgejo-runner-docker-image:node20-dind
      options: --privileged  # 重要: privileged モードが必要
    steps:
      - name: Start Docker daemon
        run: |
          # Docker デーモンをバックグラウンドで起動
          dockerd-entrypoint.sh &
          
          # デーモンの起動を待機
          for i in {1..30}; do
            if docker info >/dev/null 2>&1; then
              echo "Docker daemon is ready!"
              break
            fi
            sleep 1
          done
```

**メリット:**
- 完全な分離とセキュリティ
- ホストシステムに影響なし
- 複雑な Docker 操作にも対応

**デメリット:**
- privileged モードが必要
- リソースをより多く消費
- 手動でデーモンを起動する必要がある

### 方法2: Docker-on-Docker (DooD) - シンプルで高速

この方法はよりシンプルで、ホストの Docker デーモンを使用します。

```yaml
jobs:
  build:
    runs-on: docker
    container:
      image: ghcr.io/hidemaruowo/forgejo-runner-docker-image:node20-cli
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock  # ホストのソケットをマウント
    steps:
      - name: Build Docker image
        run: docker build -t myimage:latest .
```

**メリット:**
- シンプルな設定
- privileged モード不要
- 高速な起動
- ホストとレイヤーキャッシュを共有

**デメリット:**
- セキュリティ上の考慮事項（コンテナがホスト Docker にアクセス）
- ホストの Docker 操作と競合する可能性

## どちらを選ぶべきか？

### DinD (node20-dind) を選択する場合:
- CI/CD パイプラインで完全な分離が必要
- セキュリティが重要
- Docker イメージのビルドと実行が複雑

### DooD (node20-cli) を選択する場合:
- シンプルな Docker 操作のみ
- 高速な実行が重要
- ホストシステムとの統合が許容される

## 詳細なドキュメント

より詳しい情報と追加の設定例については、以下を参照してください：
- [Forgejo Actions 使用ガイド](FORGEJO_ACTIONS_GUIDE.md)

## サンプルワークフロー

このリポジトリには2つのサンプルワークフローが含まれています：
- `.forgejo/workflows/docker-build-push.yml` - DinD を使用した例
- `.forgejo/workflows/docker-build-push-dood.yml` - DooD を使用した例

# CI/CD 練習ガイド

**上から順に1つずつ**進めてください。各ステップは「やること」と「できたかの確認」だけです。
仕組みの説明は一番下の「仕組みメモ」にまとめてあります(読まなくても進められます)。

コマンドはすべて、このフォルダ(`cicd-test`)を開いたターミナルで実行します。

---

## ✅ ステップ1: AWS CLI を入れる(完了)

## ✅ ステップ2: AWS にログインする(完了)

ユーザー `iam-suzuki`、プロファイル名 `cicd` でログイン済みです。

> ログインは最長12時間で切れます。翌日以降に続きをやるときは、まずこれを実行してください。
>
> ```bash
> aws login --profile cicd
> ```

---

## ✅ ステップ3: Terraform を入れる(完了)

**やること**: 下のコマンドをそのまま実行します。途中で Mac のパスワードを聞かれます。

```bash
cd /tmp && curl -fsSLO https://releases.hashicorp.com/terraform/1.16.6/terraform_1.16.6_darwin_arm64.zip && unzip -o terraform_1.16.6_darwin_arm64.zip terraform && sudo mv terraform /usr/local/bin/ && rm terraform_1.16.6_darwin_arm64.zip && cd -
```

**できたかの確認**:

```bash
terraform -version
```

`Terraform v1.16.6` と表示されれば OK です。

---

## ✅ ステップ4: アプリを手元で動かしてみる(完了)

**やること**:

```bash
npm test
```

**できたかの確認**: `pass 3` / `fail 0` と表示されれば OK です。

**ブラウザで見たいとき**:

```bash
npm start
```

`listening on :3000` と出たら、ブラウザで次を開きます。

- http://localhost:3000 → `Hello from cicd-demo` と `version: dev`
- http://localhost:3000/healthz → `{"status":"ok","version":"dev"}`

見終わったら、ターミナルで `Ctrl + C` を押して止めます。

---

## ✅ ステップ5: GitHub にリポジトリを作って送る(完了)

**やること**: 下の2つを順に実行します。

```bash
git init -b main && git add . && git commit -m "initial"
```

```bash
gh repo create cicd-test --public --source . --push
```

**できたかの確認**: ブラウザで `https://github.com/y-suzuki-hub/cicd-test` の **Actions** タブを開きます。`pipeline` が動いて、次の状態になれば OK です。

- `test` と `scan` → 緑(成功)
- `build` → 赤(失敗)

> `build` が失敗するのは正常です。AWS 側の受け皿をまだ作っていないためで、ステップ6で作ります。

---

## ✅ ステップ6: AWS 側を作る(完了)

**やること**: 下の4つを順に実行します。

① infra フォルダに移動し、AWS のログイン情報をこのターミナルに読み込む

```bash
cd infra && eval "$(aws configure export-credentials --profile cicd --format env)"
```

② 設定ファイルを作る(GitHub からリポジトリの ID を取って自動で書き込みます)

```bash
gh api repos/y-suzuki-hub/cicd-test --jq '"github_repo = \"\(.full_name)\"\ngithub_sub_repo = \"\(.owner.login)@\(.owner.id)/\(.name)@\(.id)\""' > terraform.tfvars && cat terraform.tfvars
```

③ 準備

```bash
terraform init
```

④ 作成。作られるものの一覧が出て `Enter a value:` と聞かれるので、`yes` と入力します。完了まで数分かかります。

```bash
terraform apply
```

**できたかの確認**: 最後に `Apply complete!` と出れば OK です。続けて次を実行し、表示された2つの URL をブラウザで開きます。

```bash
terraform output
```

表示は2つの部分に分かれています。

- 上の `gh_variable_commands = <<EOT ... EOT`: ステップ7で使う GitHub 登録用のコマンド。**ここでは何もしなくてよい**
- 一番下の `production_url` と `staging_url`: この2つの URL をブラウザで開く

どちらの URL も `placeholder` と表示されれば OK です(表示されるまで1〜2分かかることがあります)。

> `EntityAlreadyExists` というエラーで止まった場合は、`terraform.tfvars` の最後に `create_oidc_provider = false` の1行を足してから、もう一度 `terraform apply` を実行してください。

---

## ✅ ステップ7: GitHub 側の設定(完了)

**やること**:

① 確認用(staging)と本番用(production)の環境を作り、本番に「承認者 = 自分」を設定する

```bash
gh api -X PUT repos/y-suzuki-hub/cicd-test/environments/staging
```

```bash
gh api -X PUT repos/y-suzuki-hub/cicd-test/environments/production --input - <<< "{\"reviewers\":[{\"type\":\"User\",\"id\":$(gh api user --jq .id)}],\"prevent_self_review\":false}"
```

② AWS の情報を GitHub に登録する(ステップ6と同じ `infra` フォルダで実行)

```bash
terraform output -raw gh_variable_commands | sh
```

**できたかの確認**: GitHub のリポジトリで **Settings → Environments** を開きます。

- `staging` と `production` の2つがあること
- `production` を開くと、Required reviewers に自分が入っていること

---

## ✅ ステップ8: 初めての本番公開(完了)

**やること**:

1. GitHub の **Actions** タブで、一覧の赤い ✕ が付いた **initial** の文字をクリック → 開いた画面の右上にある **Re-run jobs** → **Re-run all jobs** → 確認画面でもう一度 **Re-run jobs** を押す
2. 待っていると `deploy-production` が黄色の **Waiting** で止まる
3. 確認用の URL(`:8080` で終わるほう)を開き、`Hello from cicd-demo` と出ていることを見る
4. Actions の画面に戻って **Review deployments** → `production` にチェック → **Approve and deploy**

**できたかの確認**: 本番の URL(`:8080` が付かないほう)を開いて `Hello from cicd-demo` が出れば、**CI/CD 完成**です。

> `build` の **Configure AWS credentials** で `Not authorized to perform sts:AssumeRoleWithWebIdentity` と出て失敗した場合は、エラー画面をそのまま Claude に貼ってください。

---

## ステップ9: 一つ前に戻してみる

**やること**:

① 見た目を変えて送る

```bash
cd ~/Projects/cicd-test && sed -i '' 's/Hello from cicd-demo/Hello v2/' src/app.js test/app.test.js && git commit -am "v2" && git push
```

② ステップ8と同じ要領で承認して、本番が `Hello v2` になることを確認する

③ GitHub の **Actions** タブ → 左の一覧から **rollback** → **Run workflow** → environment は `production` のまま **Run workflow** を押す → 承認する

**できたかの確認**: 本番の URL が `Hello from cicd-demo` に戻っていれば OK です。

---

## ステップ10(任意): わざと失敗させてみる

ブランチを切って Pull Request を出し、それぞれ止まることを確かめます。確認したら Pull Request は閉じてください。

| 試すこと | 止まる場所 |
|---|---|
| `test/app.test.js` の期待値を変える | `test` |
| どこかのファイルに `AKIA` で始まる偽のアクセスキー風の文字列(20文字)を書く | `scan` |

---

## ステップ11: 後片付け(必ずやる)

ALB と Fargate は、動いている時間だけ料金がかかります。試し終わったら消してください。

```bash
cd infra && eval "$(aws configure export-credentials --profile cicd --format env)" && terraform destroy
```

`yes` と入力して、`Destroy complete!` と出れば OK です。

---
---

## 仕組みメモ

### 全体の流れ

```
 Pull Request ─▶ test ─┐
                       ├─ (PRはここまで。AWS には触らない)
                scan ──┘
 main に push ──▶ test ─┐
                 scan ──┴▶ build ──▶ staging ──▶ [承認待ち] ──▶ production
                          コンテナ作成   自動で公開    自分で承認       本番公開
                          +イメージ検査  +動作確認
```

| ファイル | 役割 |
|---|---|
| `src/`, `test/` | 練習用アプリ |
| `Dockerfile` | コンテナの作り方 |
| `infra/*.tf` | AWS 側の部品(ステップ6で作るもの) |
| `.github/workflows/pipeline.yml` | 上の流れの本体 |
| `.github/workflows/deploy.yml` | staging と production で共通のデプロイ処理 |
| `.github/workflows/rollback.yml` | 「一つ前に戻す」ボタン(ステップ9) |

### アクセスキーを使わない仕組み(OIDC)

GitHub Actions は、実行のたびに「どのリポジトリの、どの環境のジョブか」が書かれた短命の証明書を発行します。AWS 側(`infra/github_oidc.tf`)は、その中身を見て AWS の権限を貸します。権限は役割ごとに3つに分けています。

- **build 用**: main ブランチからだけ使える。ECR にイメージを置くことしかできない
- **staging 用**: staging 環境のジョブからだけ使える
- **production 用**: production 環境のジョブからだけ使える。つまり**承認を通らないと使えない**

GitHub に登録するのは名前や ARN だけで、秘密情報(Secrets)は1つもありません。

ステップ6の②で `github_sub_repo` を書いているのは、2026年7月15日以降に作った GitHub リポジトリでは証明書の中の表記が `ユーザー名@ID/リポジトリ名@ID` 形式になるためです。

### 承認の仕組み

`production` 環境に Required reviewers を設定すると、その環境を使うジョブは承認されるまで止まります。GitHub の Free / Pro / Team プランでは、この機能は **Public リポジトリでしか使えません**。そのため、ステップ5でリポジトリを `--public` で作っています。

### 一つ前に戻せる仕組み

- ECS は、公開のたびに「タスク定義」を `cicd-demo-production:1, :2, :3 …` と番号付きで残します。rollback は、今より1つ小さい番号を指定し直すだけです。ビルドをやり直さないので1〜2分で戻ります
- 新しい版が起動に失敗したときは、ECS が自動で前の版に戻します(`infra/ecs.tf` の `deployment_circuit_breaker`)
- ECR のイメージはタグ(コミットの ID)の上書きを禁止しているので、戻した先が「当時のもの」であることが保証されます

### 安全のための決めごと

- イメージは1回だけ作り、確認用で動いたものと**同じもの**を本番に出す
- 秘密情報のチェックは過去のコミットも全部見る。一度コミットした鍵は、消しても履歴に残るため
- 本格運用では、Actions のバージョンを `@v6` のような番号ではなくコミット ID で固定すると、より安全です

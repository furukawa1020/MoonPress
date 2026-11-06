# インストールと使い方

## Linux版を入手する

[GitHubの配布一覧](https://github.com/furukawa1020/MoonPress/releases)を開き、公開済みのプレビュー版から `moonpress-linux-x86_64.tar.gz` と `SHA256SUMS` を同じフォルダに保存します。Ubuntu 22.04と24.04で検証しています。配布版はMoonBitのインストールなしで起動できます。

ダウンロード先のフォルダで実行します。照合結果が `OK` になってから展開してください。

```sh
sha256sum --check --strict SHA256SUMS
tar -xzf moonpress-linux-x86_64.tar.gz
cd moonpress-linux-x86_64
```

[ソースからビルドする手順](https://github.com/furukawa1020/MoonPress#quick-start)

## サイトを作り、管理画面を開く

展開したフォルダで次の二行を実行します。最初のコマンドは `my-site` にサンプル記事と設定を作ります。既存サイトを開くときは、そのフォルダを二行目に指定してください。

```sh
./moonpress init my-site
./moonpress admin my-site 8080
```

ターミナルを開いたまま、ブラウザで [管理画面を開く](http://127.0.0.1:8080/rooms)。終了するときはターミナルで Ctrl+C を押します。

この公開ガイドは手順を読むためのページです。実際の編集は、起動したPCの管理画面で行います。

## 最初の記事を作ってZIPを取得する

1. [記事を書く](room-write.html)。管理画面で「新しい下書き」を作り、本文を入力して保存します。
2. [プレビューする](room-preview.html)。「プレビューをつくる」を押し、生成したプレビューを開きます。公開したい記事の編集画面で「公開対象にする」を押します。
3. [公開用ファイルを生成する](room-build.html)。変更計画を確認し、確認した内容で公開用ファイルを生成します。
4. [ZIPを取得する](room-publish.html)。「公開用ZIPをダウンロード」を押し、展開したファイルを公開先にアップロードします。

## MoonBitが担当すること

HTMLフォームを受け取り、保存済み記事の検証・依存関係の解析・SHA-256による差分計画・確認済み計画のビルドをネイティブで実行します。ブラウザのJavaScriptやTypeScriptは使いません。

記事はMarkdown、見た目はHTMLとCSS、画像はファイルとして手元に残ります。生成物もHTML・CSS・画像なので、配信先にMoonBitを入れる必要はありません。

配布版では、実Chromeで記事作成からZIP出力までを検証しています。

[入口へ戻る](index.html)

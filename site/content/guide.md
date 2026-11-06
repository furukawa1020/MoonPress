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

## おひろめる〜むから先へ

生成したファイルをGitHub Pagesなどのホストへ配信します。ローカルでのビルド成功と、ホストへの公開成功は別々です。

[GitHub Pagesへの詳しい道順](https://github.com/furukawa1020/MoonPress/blob/main/docs/deployment.md)

## MoonBitが担当すること

HTMLフォームを受け取り、保存済み記事の検証・依存関係の解析・SHA-256による差分計画・確認済み計画のビルドをネイティブで実行します。ブラウザのJavaScriptやTypeScriptは使いません。

記事はMarkdown、見た目はHTMLとCSS、画像はファイルとして手元に残ります。生成物もHTML・CSS・画像なので、配信先にMoonBitを入れる必要はありません。

完全な電源断耐性、実ブラウザでの操作検証、安定版配布は引き続き開発中です。

[入口へ戻る](index.html)

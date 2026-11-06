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

## 自分の工房をひらく

```sh
moonpress="$PWD/_build/native/release/build/cmd/main/main.exe"
"$moonpress" init ../my-site
"$moonpress" admin ../my-site 8080
```

ブラウザで http://127.0.0.1:8080/rooms を開きます。ターミナルは開いたままにしてください。

書斎で記事を書いて保存し、ぷれびゅ〜る〜むでプレビュー、こんぱいら〜る〜むで変更計画を確認してビルドします。おひろめる〜むでは、最新の生成物だけをZIPで持ち出せます。

管理画面は自分のPCだけに開きます。ネット上のこのサイトは体験ガイドです。ここであなたのファイルを編集することはありません。

## おひろめる〜むから先へ

生成したファイルをGitHub Pagesなどのホストへ配信します。ローカルでのビルド成功と、ホストへの公開成功は別々です。

[GitHub Pagesへの詳しい道順](https://github.com/furukawa1020/MoonPress/blob/main/docs/deployment.md)

## MoonBitが担当すること

HTMLフォームを受け取り、保存済み記事の検証・依存関係の解析・SHA-256による差分計画・確認済み計画のビルドをネイティブで実行します。ブラウザのJavaScriptやTypeScriptは使いません。

記事はMarkdown、見た目はHTMLとCSS、画像はファイルとして手元に残ります。生成物もHTML・CSS・画像なので、配信先にMoonBitを入れる必要はありません。

完全な電源断耐性、実ブラウザでの操作検証、安定版配布は引き続き開発中です。

[入口へ戻る](index.html)

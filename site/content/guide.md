# 冒険のはじめ方

## 道具をそろえる

いまのMoonPressはLinux x86_64向けのプレビュー版です。ソースから作る場合は、Git・Bash・Cコンパイラと検証済みMoonBitツールチェーンを使います。

```sh
git clone https://github.com/furukawa1020/MoonPress.git
cd MoonPress
bash scripts/setup.sh
export PATH="$HOME/.moon/bin:$PATH"
moon build --target native --release
```

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

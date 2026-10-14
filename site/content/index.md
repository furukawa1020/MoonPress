# MoonPress

Review the change. Build that plan.

MoonBitで書く、静的サイトのための小さなコンパイラ。
JavaScriptもNode.jsも、配信時のランタイムも不要です。

何が変わるかを、書き出す前に確認する。確認した計画と違えば、勝手に先へ進まない。
MoonPressは記事・テーマ・画像の依存関係から変更計画を作り、その計画を確認してからビルドできます。

## Build your first site

```sh
moonpress build site dist
```

MarkdownとHTMLレイアウト、CSSから静的サイトを生成します。このページもMoonPressで生成しています。

## An honest beginning

記事の作成・下書きプレビュー・変更理由の確認を、JavaScriptなしのブラウザ画面から操作できます。公開用ビルドは確認済みの計画と照合し、変わっていれば書き出さずに停止します。CLIでもreviewとbuild-reviewedで同じ仕組みを使えます。

SHA-256による差分ビルドで、未変更のページは書き換えません。これはローカルの生成処理です。ホスティングへの公開は別の手順で行います。信頼できるローカルプロジェクト向けの実験段階で、電源断への完全な耐久性や外部プロセスによる同時変更への防御は保証しません。

「超軽量」は目標です。サイズと速度を測定し、その根拠を公開します。

# Getting started

## Prerequisites

Linux x86_64、Cコンパイラ、MoonBitの検証済みツールチェーンを使用します。

```sh
bash scripts/setup.sh
export PATH="$HOME/.moon/bin:$PATH"
bash scripts/check.sh
moon run cmd/main --target native -- build site dist
```

## Input contract

site/content直下の.mdファイルを、同名の.htmlへ変換します。layout.htmlの{{title}}と{{content}}を置換し、style.cssをコピーします。

最初のH1をページタイトルとして使います。本文中のHTMLはエスケープします。レイアウトとCSSは制作者が管理する信頼済みファイルです。

## Supported Markdown

1〜6段階の見出し、空行で区切る段落、バッククォート3個のコードフェンスに対応します。リンク・リスト・強調・frontmatter・ネストしたディレクトリは未対応です。CommonMark完全互換ではありません。

## Safe output

既存の出力ディレクトリは上書きしません。毎回新しい出力先を指定してください。差分ビルドはIssue #4で実装予定です。

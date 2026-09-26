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

初回に生成した管理情報をもとに、変更されたページだけを再生成します。削除・リネームされた記事の古い出力は除去します。管理外のファイル、手動編集、シンボリックリンクを検出した場合は更新を中止します。

```sh
moonpress explain site dist
moonpress build site dist
```

explainは変更せずに更新予定と理由を表示します。同じ出力先への同時ビルドは未対応です。

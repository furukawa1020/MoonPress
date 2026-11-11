---
{"title":"使い方","kind":"page"}
---
# GitHub Pagesで使う

[サイト管理を開く](manage.html)。投稿、固定ページ、メディア、サイト設定をここから開けます。編集には対象リポジトリの書き込み権限があるGitHubアカウントでログインします。

## 新規作成

1. サイト管理の「投稿・固定ページを作る」を押します。
2. GitHub Actionsで「Run workflow」を開きます。種類、タイトル、URL名、必要なら抜粋を入力して実行します。
3. 終了した実行のSummaryにある「編集を開く」で本文を書きます。Previewで本文を確認できます。
4. 下書きを保存する間は `"draft": true` のまま作業ブランチに保存します。公開するときは `false` にして保存し、SummaryからPRを作成します。

このプロジェクトのGitHubリポジトリは公開されています。ブランチやPRの内容も閲覧できます。機密の下書きは公開リポジトリに保存しないでください。

## 編集、画像、公開

- 公開済みのページは、サイト管理の一覧にある「編集」から開きます。GitHubで新しい作業ブランチに保存し、PRを作成します。
- 画像は「メディア」の「画像・ファイルを追加」からGitHubにアップロードし、投稿でファイル名を指定します。公開用フォルダに入れた画像は公開対象です。
- PRの **Review Pages changes** で、追加、更新、削除される公開ファイルを確認します。
- PRをマージしたら、サイト管理の「Pages公開の結果」を開きます。ビルドが成功したら公開ページを確認します。

## 自分のリポジトリで使う

このリポジトリの構成を引き継ぎ、`site/site.json` の `base_url` と `pages_admin.repository` を自分のサイトに合わせます。GitHub Pagesを `gh-pages` ブランチのルートから公開する設定にして、最初の Publish Pages を実行します。編集対象は `main` の `site/` です。

[GitHub Pagesの設定と検証](https://github.com/furukawa1020/MoonPress/blob/main/docs/deployment.md)

# 初めての記事を公開するまで

対応環境はLinux x86_64です。[README](../README.md#quick-start)の手順で実行ファイルを構築し、サイトを初期化して管理画面を起動してください。別の版のMoonBitがある場合は[専用の導入先](toolchain.md)を指定します。安定版バイナリ配布やmacOS/Windowsの動作確認はまだ完了していません。

ブラウザで **http://127.0.0.1:8080/workflow** を開きます。作業中は起動したターミナルを開いたままにし、終了するときはCtrl-Cを押します。

1. **Write and save**：Create a draftからタイトルとファイル名（例：first-post）を入力し、Markdown本文を書いてSave articleで保存します。画像はMediaからアップロードし、表示されたMarkdownを本文に貼ります。
2. **Preview your saved drafts**：Build full preview filesでテーマ・画像を含むプレビューを生成します。サイト内の `.moonpress-preview/index.html` をファイルブラウザから開いてください。ここには下書きが含まれます。
3. **Choose what goes live**：公開する記事を開き、保存後にSet ready for buildを押します。Draftは下書き、Readyは通常ビルドに含める状態です。
4. **Review before building**：Inspect production changesで追加・変更・削除と、その原因となる元記事・レイアウト・設定などの依存関係を確認します。エラーが出た場合は表示された元ファイルや出力の問題を直してから再確認します。手動編集した生成物は上書きされません。
5. **Create production files**：確認結果の画面にあるBuild production filesで `.moonpress-build` に下書きを除く公開用ファイルを生成します。確認後に変更計画が変わると書き出さず停止するので、再度Inspect production changesで確認してください。プレビュー用ディレクトリとは分かれています。
6. **Publish and verify**：公開用ファイルをホストへ配置するか、設定済みのGitHub Actionsで保存済みソースをビルド・公開します。[GitHub Pages設定](deployment.md)には一度だけ管理者の操作が必要です。Actionsの成功と実際の公開URLを確認してください。

保存・Readyへの変更・ローカルビルドだけではインターネットに公開されません。この管理画面はホストの公開状態を取得していません。記事をDraftに戻した場合も、通常ビルドをやり直してホストへ反映するまで公開済みページは残ります。

記事のURLを変更する前には、編集画面の **Inspect saved article references** で参照元と参照先を確認できます。必要なら **Include saved drafts** で下書きも含めます。記事の参照元は編集画面へ戻るリンクになっています。CSS・外部URL・自動生成された一覧リンクなどは対象外なので、参照ゼロは削除してよいという保証ではありません。リンク切れのある範囲はエラーとして表示されます。[参照範囲の詳細](references.md)。

MoonPressの実装はMoonBitのnative実行ファイルと薄いC境界です。管理画面はHTMLフォームで操作でき、JS/TS/Nodeは不要です。編集・CLI・管理画面で共通の型と検証を使い、元ファイルの依存関係から変更理由を追跡します。MoonBitだけに可能な機能という主張や、他製品より速いという未測定の主張はしません。

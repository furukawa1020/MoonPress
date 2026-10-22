<?php
header('Content-Type: text/html; charset=UTF-8');
if (!have_posts()) { status_header(404); exit('Not found'); }
the_post();
echo '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>' . esc_html(get_the_title()) . '</title></head><body><main><h1>' . esc_html(get_the_title()) . '</h1>';
the_content();
echo '</main></body></html>' . "\n";

<?php
require $argv[1] . '/wp-load.php';
$cases = [];
foreach (['left','center','right'] as $align) {
    $cell = 'class="has-text-align-' . $align . '" data-align="' . $align . '"';
    $source = '<!-- wp:table {"hasFixedLayout":false} --><figure class="wp-block-table"><table><thead><tr><th ' . $cell . '>Header</th></tr></thead><tbody><tr><td ' . $cell . '>A &amp; 月</td></tr></tbody></table></figure><!-- /wp:table -->';
    $blocks = parse_blocks($source);
    if (count($blocks)!==1 || $blocks[0]['blockName']!=='core/table') { throw new RuntimeException('Core table parse differs'); }
    $rendered = render_block($blocks[0]);
    $cases[] = [$source,$rendered];
}
file_put_contents($argv[2],json_encode($cases,JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE));

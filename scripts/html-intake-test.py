"""HTML semantics through the actual REST create/update/WXR source path."""
import pathlib,sys,json
from rest_fixture import NativeSite,run
cases=[('<p>Before <strong>bold</strong> after <em>soft</em>.</p>','<p>Before <strong>bold</strong> after <em>soft</em>.</p>\n'),('<p>Read <a href="https://example.test/">月</a> with <code>x &lt; y</code>.</p>','<p>Read <a href="https://example.test/">月</a> with <code>x &lt; y</code>.</p>\n')]
cases += [('<ul><li>First <strong>bold</strong> end</li><li>Second &amp; 月</li></ul>', '<ul>\n<li>First <strong>bold</strong> end</li>\n<li>Second &amp; 月</li>\n</ul>\n'),('<ol start="3"><li>Third</li><li>Fourth</li></ol>','<ol start="3">\n<li>Third</li>\n<li>Fourth</li>\n</ol>\n')]
cases += [('<!-- wp:paragraph --><p>Before <strong>bold</strong> end.</p><!-- /wp:paragraph -->','<p>Before <strong>bold</strong> end.</p>\n'),('<!-- wp:list {"ordered":true,"start":3} --><ol class="wp-block-list" start="3"><!-- wp:list-item --><li>Third</li><!-- /wp:list-item --></ol><!-- /wp:list -->','<ol start="3">\n<li>Third</li>\n</ol>\n')]
cases += [('<p>Line one<br>Line two<br />月</p>','<p>Line one<br>\nLine two<br>\n月</p>\n')]
cases += [('<blockquote><p>A <strong>quoted</strong> line<br>Next</p></blockquote>','<blockquote>\n<p>A <strong>quoted</strong> line<br>\nNext</p>\n</blockquote>\n')]
cases += [('<pre><code class="language-moonbit">  x &lt; y\n```\n</code></pre>','<pre><code class="language-moonbit">  x &lt; y\n```\n</code></pre>\n')]
cases += [('<p>Before</p><hr /><p>After</p>','<p>Before</p>\n<hr>\n<p>After</p>\n')]
cases += [('<p>Look <img src="https://example.test/image.png" alt="月 &amp; stars" /> here.</p>','<p>Look <img src="https://example.test/image.png" alt="月 &amp; stars"> here.</p>\n')]
cases += [('<!-- wp:quote --><blockquote class="wp-block-quote"><!-- wp:paragraph --><p>Quoted <strong>bold</strong> end.</p><!-- /wp:paragraph --></blockquote><!-- /wp:quote -->','<blockquote>\n<p>Quoted <strong>bold</strong> end.</p>\n</blockquote>\n'),('<!-- wp:image {"id":123,"sizeSlug":"large","linkDestination":"none"} --><figure class="wp-block-image size-large"><img src="https://example.test/image.png" alt="Moon" class="wp-image-123" /></figure><!-- /wp:image -->','<p><img src="https://example.test/image.png" alt="Moon"></p>\n')]
cases += [('<p>Before <del>old</del> after.</p>','<p>Before <del>old</del> after.</p>\n'),('<p><s>Removed</s></p>','<p><del>Removed</del></p>\n')]
cases += [('<table><thead><tr><th>Name</th><th>Value</th></tr></thead><tbody><tr><td>One</td><td><strong>two</strong></td></tr></tbody></table>','<table>\n<thead>\n<tr><th scope="col">Name</th><th scope="col">Value</th></tr>\n</thead>\n<tbody>\n<tr><td>One</td><td><strong>two</strong></td></tr>\n</tbody>\n</table>\n')]
if len(sys.argv)>1:cases+=json.loads(pathlib.Path(sys.argv[1]).read_text())
with NativeSite() as site:
    for index,(body,expected) in enumerate(cases):
        status,headers,value=site.request('/wp-json/wp/v2/posts','POST',{'title':'HTML '+str(index),'content':body},'author')
        assert status==201 and value['content']['rendered']==expected,(status,value,expected)
        path='/wp-json/wp/v2/posts/'+str(value['id'])
        status,_,value=site.request(path,'POST',{'content':'<p>Changed <strong>bold</strong> end.</p>'},'author',headers['ETag'])
        assert status==200 and value['content']['rendered']=='<p>Changed <strong>bold</strong> end.</p>\n'
    _,current_headers,_=site.request(path+'?context=edit',role='author')
    before={p.name:p.read_bytes() for p in (site.site/'content').glob('*.md')}
    for body in ['<table><tr><th>X</th></tr><tr><td colspan="2">Y</td></tr></table>','<table><tr><th>A</th><th>B</th></tr><tr><td>C</td></tr></table>','<p><del onclick="bad">x</del></p>','<p><del> edge </del></p>','<p>A<strong>B</strong>C</p>','<p><a href="javascript:alert(1)">x</a></p>','<p><span>x</span></p>','<p>x<!-- hidden -->y</p>','<p><strong>x</p>','<!-- wp:latest-posts /-->','<!-- wp:paragraph --><p>A</p><!-- /wp:heading -->']:
        assert site.request('/wp-json/wp/v2/posts','POST',{'title':'Rejected','content':body},'author')[0]==400
        assert site.request(path,'POST',{'content':body},'author',current_headers['ETag'])[0]==400
    assert before=={p.name:p.read_bytes() for p in (site.site/'content').glob('*.md')}
print('HTML intake passed: ordered inline text/styles/links/code, create and update, unsafe/lossy input refused without mutation.')

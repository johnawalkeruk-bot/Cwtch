"""Build local blog previews; freeze one post per version during manual publishing."""
import argparse
import json
import re
from html import escape
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
AUTHOR = 'Waldas Gamer Studios'


def make_post(entry):
    editorial = entry.get('blog', {})
    return dict(version=entry['id'], date=entry.get('date'), title=entry['title'],
        author=AUTHOR, sections=entry['sections'],
        intro=editorial.get('intro', 'Another update has wandered into the valley. We have given it a cup of tea and checked its muddy boots. Here is what changed.'),
        why=editorial.get('why', ['This update brings together the changes listed below. Detailed design notes were not recorded for this release; the changelog remains the source for what changed.']),
        issues=editorial.get('issues', ['No additional issues were recorded in these release notes. That is not a promise that every hedgehog has passed quality assurance.']),
        screenshots=editorial.get('screenshots', []))


def page(title, body, prefix=''):
    return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>{escape(title)} — CWTCH</title><meta name="description" content="Development stories from Waldas Gamer Studios: what changed in CWTCH, why, and what still needs tending."><link rel="icon" href="{prefix}favicon.ico"><link rel="stylesheet" href="{prefix}style.css"></head><body><a class="skip" href="#main">Skip to content</a><header class="wrap"><a class="wordmark" href="{prefix}index.html">CWTCH<span>YOUR SLICE OF THE VALLEY.</span></a><nav aria-label="Main navigation"><a href="{prefix}index.html#valley">The Valley</a><a href="{prefix}blog.html" aria-current="page">Blog</a><a href="{prefix}changelog.html">Changelog</a><a href="{prefix}index.html#download">Download</a></nav></header><main id="main" class="blog wrap">{body}</main><footer class="wrap"><a class="wordmark" href="{prefix}index.html">CWTCH</a><p>Waldas Gamer Studios · Made for the quieter moments.</p><a href="{prefix}blog.html">Notes from the studio</a></footer></body></html>'''


def article(post, website, preview=False):
    stamp = 'Development preview · not released' if preview else 'v' + post['version'] + ' · ' + post['date']
    body = '<a href="../blog.html">← All studio notes</a><article><header class="blog-heading"><p class="eyebrow">NOTES FROM THE STUDIO</p><h1>'+escape(post['title'])+'</h1><p class="blog-byline">By '+AUTHOR+' · '+escape(stamp)+'</p></header>'
    if post.get('updated'):
        body += '<p class="change-note">Updated '+escape(post['updated'])+' · See the dated development follow-up below.</p>'
    body += '<p class="blog-lede">'+escape(post['intro'])+'</p><h2>Why we changed it</h2>'
    body += ''.join('<p>'+escape(p)+'</p>' for p in post['why'])
    body += '<h2>What changed</h2>'
    for section in post['sections']:
        body += '<h3>'+escape(section['heading'])+'</h3><ul>'+''.join('<li>'+escape(p)+'</li>' for p in section['items'])+'</ul>'
    body += '<h2>The slightly muddy bits</h2>'+''.join('<p>'+escape(p)+'</p>' for p in post['issues'])
    for shot in post['screenshots']:
        path = shot['path']
        if not re.fullmatch(r'assets/blog/[A-Za-z0-9_-]+\.(png|jpg|webp)', path):
            raise ValueError('Blog screenshot must be a named image inside Website/assets/blog: '+path)
        if not (website/path).is_file():
            raise ValueError('Missing blog screenshot: '+path)
        body += '<figure class="blog-photo"><img loading="lazy" src="../'+escape(path,quote=True)+'" alt="'+escape(shot['caption'],quote=True)+'"><figcaption>'+escape(shot['caption'])+'</figcaption></figure>'
    body += '<p class="change-note">'+('This preview may change before publication.' if preview else 'Release notes: <a href="../changelog.html#v'+escape(post['version'])+'">v'+escape(post['version'])+'</a>.')+'</p></article>'
    return page(post['title'],body,'../')


def build(website, release=None):
    data = json.loads((website/'changelog.json').read_text(encoding='utf-8'))
    folder = website/'blog'
    folder.mkdir(exist_ok=True)
    archive = folder/'posts.json'
    posts = json.loads(archive.read_text(encoding='utf-8')) if archive.exists() else []
    if release:
        if not re.fullmatch(r'\d+\.\d+\.\d+',release):
            raise ValueError('Expected a numeric release version')
        if not any(p['version']==release for p in posts):
            entry = next(e for e in data['entries'] if e['id']==release)
            post = make_post(entry)
            article(post,website)  # Validate before recording the immutable snapshot.
            posts.insert(0,post)
            archive.write_text(json.dumps(posts,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    body = '<div class="change-intro"><p class="eyebrow">WALDAS GAMER STUDIOS</p><h1>Notes from<br><em>the valley.</em></h1><p class="lede">Small improvements, honest mishaps, and occasional hedgehog-related paperwork. The stories behind each new release.</p></div>'
    pending = next((e for e in data['entries'] if e['id']=='unreleased' and e['sections']),None)
    if pending:
        post = make_post(pending)
        (folder/'preview.html').write_text(article(post,website,True),encoding='utf-8')
        body += '<aside class="blog-preview"><p class="eyebrow">ON THE WORKBENCH · NOT RELEASED</p><h2>'+escape(post['title'])+'</h2><p>By '+AUTHOR+'</p><a href="blog/preview.html">Read the development preview →</a></aside>'
    if not posts:
        body += '<h2>The kettle is on.</h2><p>Our first release story will appear here with the next published update. Until then, browse the development preview and <a href="changelog.html">changelog</a>.</p>'
    for post in posts:
        name='v'+post['version']+'.html'
        (folder/name).write_text(article(post,website),encoding='utf-8')
        body += '<article class="blog-card"><p class="eyebrow">v'+escape(post['version'])+' · '+escape(post['date'])+'</p><h2><a href="blog/'+name+'">'+escape(post['title'])+'</a></h2><p class="blog-byline">By '+AUTHOR+'</p><p>'+escape(post['intro'])+'</p></article>'
    (website/'blog.html').write_text(page('Notes from the valley',body),encoding='utf-8')
    return posts


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--release',help='Freeze the promoted changelog entry as a release post; used by manual publishing.')
    args=parser.parse_args()
    build(ROOT/'Website',args.release)
    print('Updated Website/blog.html')

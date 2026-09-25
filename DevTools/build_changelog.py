"""Render the static website changelog. Promotion is only called by a manual release."""
import argparse
import json
import re
from datetime import date
from html import escape
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'Website/changelog.json'

def promote(data, version):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Expected a version such as 0.1.12')
    if any(entry['id'] == version for entry in data['entries']):
        return  # A resumed manual publish must not duplicate an entry.
    pending = next((entry for entry in data['entries'] if entry['id'] == 'unreleased'), None)
    if pending is None or not pending['sections']:
        raise ValueError('Add player-facing notes to Website/changelog.json before releasing.')
    pending.update(id=version, label='v'+version, date=date.today().isoformat())
    data['entries'].insert(0, {'id':'unreleased','label':'Next update','date':None,
        'title':'In development','sections':[]})

def render(data):
    entries = data['entries']
    ids = [entry['id'] for entry in entries]
    if len(set(ids)) != len(ids):
        raise ValueError('Changelog entry IDs must be unique')
    cards = []
    for entry in entries:
        if not entry['sections']:
            continue
        pending = entry['id'] == 'unreleased'
        stamp = '<span class="change-status">Unreleased · development copy</span>' if pending else '<time datetime="{0}">{0}</time>'.format(escape(entry['date']))
        heading = '<span class="change-version">{}</span><h2>{}</h2>'.format(escape(entry['label']),escape(entry['title']))
        body = '<p class="change-meta">'+stamp+'</p>'
        if pending:
            body += '<p class="change-note">These changes are in development and are not yet included in the launcher’s published game.</p>'
        for section in entry['sections']:
            body += '<h3>'+escape(section['heading'])+'</h3><ul>'
            body += ''.join('<li>'+escape(item)+'</li>' for item in section['items'])+'</ul>'
        if not pending:
            body += '<p class="change-note">Release milestone from the local project history. <a href="https://github.com/johnawalkeruk-bot/Cwtch/releases/tag/v'+escape(entry['id'])+'">View release on GitHub</a></p>'
        anchor = 'unreleased' if pending else 'v'+entry['id']
        if pending:
            cards.append('<article class="change-card" id="'+anchor+'">'+heading+'<div class="change-body">'+body+'</div></article>')
        else:
            cards.append('<details class="change-card" id="'+anchor+'"'+(' open' if entry['id']==next(e['id'] for e in entries if e['id']!='unreleased') else '')+'><summary>'+heading+'</summary><div class="change-body">'+body+'</div></details>')
    return '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>CWTCH — Changelog</title><meta name="description" content="Follow CWTCH’s development: garden tools, valley life, wildlife, weather and fixes, from the first foundation to the newest changes.">
<meta name="theme-color" content="#213e35"><link rel="icon" href="favicon.ico"><link rel="stylesheet" href="style.css"></head>
<body><a class="skip" href="#main">Skip to content</a>
<header class="wrap"><a class="wordmark" href="./">CWTCH<span>YOUR SLICE OF THE VALLEY.</span></a><nav aria-label="Main navigation"><a href="./#valley">The Valley</a><a href="changelog.html" aria-current="page">Changelog</a><a href="./#download">Download</a></nav></header>
<main id="main" class="changelog wrap"><div class="change-intro"><p class="eyebrow">NOTES FROM THE VALLEY</p><h1>A little more<br><em>with every update.</em></h1><p class="lede">New arrivals, small improvements, and the work that makes the valley feel like home.</p><p>Newest changes first. Open an earlier milestone to explore its notes. Early development is grouped into the first release; later changes supersede older behaviour.</p><a href="./#download">Get the latest published game →</a></div>
<div class="change-list">'''+''.join(cards)+'''</div></main>
<footer class="wrap"><a class="wordmark" href="./">CWTCH</a><p>Made for the quieter moments.</p><a href="./#download">Download the launcher</a></footer></body></html>
'''

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--release')
    args=parser.parse_args()
    data=json.loads(DATA.read_text(encoding='utf-8'))
    if args.release:
        promote(data,args.release)
    html=render(data)
    if args.release:
        DATA.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (ROOT/'Website/changelog.html').write_text(html,encoding='utf-8')
    print('Updated Website/changelog.html')

if __name__=='__main__':main()

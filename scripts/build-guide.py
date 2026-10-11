#!/usr/bin/env python3
"""Build 24 GitHub-native Markdown guides and an optional offline HTML edition."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / 'docs'
LANGUAGES = ['en', 'zh-Hans', 'zh-Hant', 'ja', 'ko', 'es', 'fr', 'de', 'it', 'pt', 'ru', 'ar', 'hi', 'tr', 'vi', 'th', 'id', 'nl', 'pl', 'uk', 'sv', 'da', 'fi', 'he']
SCREENSHOTS = {'en': 'en', 'zh-Hans': 'zh', 'zh-Hant': 'zh-Hant', 'ja': 'ja', 'de': 'de', 'ar': 'ar'}

def shape(value):
    if isinstance(value, dict):
        return {k: shape(v) for k, v in value.items()}
    if isinstance(value, list):
        return [shape(v) for v in value]
    return type(value).__name__

def strings(value):
    if isinstance(value, dict):
        for child in value.values():
            yield from strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from strings(child)
    elif isinstance(value, str):
        yield value

def main():
    copy = {lang: json.loads((DOCS / 'guide-data' / (lang + '.json')).read_text()) for lang in LANGUAGES}
    canonical = shape(copy['en'])
    for lang, data in copy.items():
        assert shape(data) == canonical, f'{lang}: mismatched translation structure'
        assert data['lang'] == lang
        assert data['direction'] == ('rtl' if lang in ('ar', 'he') else 'ltr')
        assert all(v.strip() for v in strings(data)), f'{lang}: empty string'
        assert [v['id'] for v in data['gallery']] == ['home', 'languages', 'youtube']
        assert [v['priority'] for v in data['issues']] == ['P0', 'P1', 'P1', 'P2', 'P2', 'P2']
        # Reuse the translated practice description for the actual local-demo capture.
        data['gallery'].insert(1, {
            'id': 'study',
            'title': data['features'][1]['title'],
            'caption': 'demo.mp4 — ' + data['features'][1]['body'],
        })
    serialized = json.dumps(copy, ensure_ascii=False, separators=(',', ':')).replace('<', '\\u003c').replace('\u2028', '\\u2028').replace('\u2029', '\\u2029')
    template = (DOCS / 'guide-template.html').read_text()
    assert template.count('%%GUIDE_DATA%%') == 1
    (DOCS / 'product-guide.html').write_text(template.replace('%%GUIDE_DATA%%', serialized))
    output = DOCS / 'guides'
    output.mkdir(exist_ok=True)
    for lang, data in copy.items():
        label = data['labels']
        navigation = ' · '.join(
            '**' + edition['name'] + '**' if code == lang
            else '[' + edition['name'] + '](' + code + '.md)'
            for code, edition in copy.items()
        )
        lines = ['# AxonTube', '', navigation, '', '[README · English](../../README.md) · [README · 简体中文](../../README.zh-CN.md)', '', '**' + data['headline'] + '**', '', data['notice'], '', '[macOS DMG · ZIP · SHA-256](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3) · [Install / 安装](../INSTALL.md) · [GitHub Packages](https://github.com/users/axonvoss-labs/packages/container/package/axontube) · [Package guide](../PACKAGES.md)', '', data['intro'], '', '**' + data['badge'] + '**', '', label['languageScope'], '', '## ' + label['screenshots'], '', label['screenshotScope'], '']
        for item in data['gallery']:
            if item['id'] == 'home':
                path = 'interface-' + SCREENSHOTS.get(lang, 'en') + '.png'
                scope = label['localizedScreenshot'] if lang in SCREENSHOTS else label['fallbackScreenshot']
            else:
                path = {'study': 'interface-study.png', 'languages': 'interface-caption-languages.png', 'youtube': 'interface-youtube-dialog.png'}[item['id']]
                scope = label['fallbackScreenshot']
            lines += ['### ' + item['title'], '', '![' + item['title'] + '](../assets/' + path + ')', '', item['caption'] + ' — ' + scope, '']
        for key, title in [('steps', 'workflow'), ('features', 'features'), ('highlights', 'highlights')]:
            lines += ['## ' + label[title], '']
            for item in data[key]:
                lines += ['### ' + item['title'], '', item['body'], '']
        lines += ['## ' + label['issues'], '']
        for item in data['issues']:
            lines += ['### ' + item['priority'] + ' · ' + item['title'], '', '**' + item['category'] + '**', '', item['body'], '']
        lines += ['## ' + label['evidence'], '', data['evidenceSummary'], '', data['evidenceLimit'], '', '[' + label['verification'] + '](../VERIFICATION.md) · [README · EN](../../README.md) · [README · 简体中文](../../README.zh-CN.md)', '', '[HTML (offline)](../product-guide.html#' + lang + ')', '', label['license'], '', label['updated'], '']
        (output / (lang + '.md')).write_text('\n'.join(lines))
    print(f'Built {len(copy)} language editions, offline HTML, and {len(copy)} Markdown guides; schema and required sections passed')

if __name__ == '__main__':
    main()

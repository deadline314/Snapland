"""Render escaped design excerpts as local browser evidence, not game screenshots."""
import argparse
import html
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('source')
parser.add_argument('--output', required=True)
parser.add_argument('--lines', type=int, default=60)
args = parser.parse_args()
source = root / args.source
excerpt = '\n'.join(source.read_text(encoding='utf-8-sig').splitlines()[:args.lines])
page = '<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>Snapland 文件驗收預覽</title>'
page += '<style>body{background:#edf1f4;color:#182837;font-family:"Microsoft JhengHei",sans-serif;margin:36px}header{border-left:6px solid #238a82;padding:16px 24px;background:white}h1{margin:0;font-size:28px}p{line-height:1.6}pre{background:white;padding:24px;font:16px/1.75 "Microsoft JhengHei",monospace;white-space:pre-wrap;overflow-wrap:anywhere}small{color:#586978}</style>'
page += '<header><h1>Snapland · 設計文件驗收</h1><p>文件預覽 · 不是 Godot 遊戲畫面 · 尚未進行玩家試玩</p><small>' + html.escape(args.source) + '</small></header>'
page += '<pre>' + html.escape(excerpt) + '</pre></html>'
target = root / args.output
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(page, encoding='utf-8')
print(target)

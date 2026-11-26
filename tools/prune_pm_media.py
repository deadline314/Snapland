"""Keep pm/ evidence small: retain media only for open and recent tickets.

Retention rule (see pm/README.md):
  * every file linked from a ticket that is not finished stays;
  * every file linked from the newest ``--keep-recent`` finished tickets of each
    project stays;
  * every file linked from non-ticket documents (README, guides, design/) stays;
  * everything else under ``pm/<project>/images`` is removed, and links to it
    inside older finished tickets become plain text.

Dry run by default; pass ``--apply`` to modify files. History keeps the media.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
TICKET = re.compile(r"^\[([A-Z]+)-(\d+)\].*\.md$")
LINK = re.compile(r"(!?)\[([^\]\n]*)\]\(([^)\n]+)\)")
FINISHED = ("狀態：完成", "狀態：取消", "狀態：封存")
PRUNED_IMAGE_NOTE = "（畫面已精簡）"


def _link_target(source: Path, raw: str) -> Path | None:
    target = raw.strip().strip("<>")
    if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target) or target.startswith("#"):
        return None
    target = unquote(target.split("#")[0])
    return (source.parent / target).resolve() if target else None


def _links(path: Path) -> list[Path]:
    text = path.read_text(encoding="utf-8-sig")
    return [t for _, _, raw in LINK.findall(text) if (t := _link_target(path, raw))]


def _is_finished(path: Path) -> bool:
    head = path.read_text(encoding="utf-8-sig")[:400]
    return any(marker in head for marker in FINISHED)


def plan(root: Path, keep_recent: int) -> tuple[set[Path], list[Path], list[Path]]:
    """Return (kept files, files to delete, tickets whose links need rewriting)."""
    pm = root / "pm"
    keep: set[Path] = set()
    rewrite: list[Path] = []
    documents = [root / "README.md", root / "AGENTS.md", *sorted((root / "design").rglob("*.md"))]
    documents += [p for p in pm.glob("*.md")]
    for project in sorted(p for p in pm.iterdir() if p.is_dir() and p.name.startswith("Snapland-")):
        finished: list[tuple[int, Path]] = []
        for ticket in project.glob("*.md"):
            match = TICKET.match(ticket.name)
            if match and _is_finished(ticket):
                finished.append((int(match.group(2)), ticket))
            else:
                documents.append(ticket)
        finished.sort(reverse=True)
        documents += [ticket for _, ticket in finished[:keep_recent]]
        rewrite += [ticket for _, ticket in finished[keep_recent:]]
    for document in documents:
        if document.is_file():
            keep.update(_links(document))
    media = [f for f in pm.glob("Snapland-*/images/**/*") if f.is_file() and ".omc" not in f.parts]
    delete = [f for f in media if f.resolve() not in keep]
    return keep, delete, rewrite


def rewrite_links(ticket: Path, removed: set[Path], apply: bool) -> int:
    text = ticket.read_text(encoding="utf-8-sig")
    count = 0

    def replace(match: re.Match[str]) -> str:
        nonlocal count
        bang, label, raw = match.groups()
        target = _link_target(ticket, raw)
        if target is None or target not in removed:
            return match.group(0)
        count += 1
        label = label.strip() or Path(unquote(raw)).name
        return f"{label}{PRUNED_IMAGE_NOTE}" if bang else label

    updated = LINK.sub(replace, text)
    if apply and count:
        ticket.write_text(updated, encoding="utf-8", newline="\n")
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--keep-recent", type=int, default=5, help="finished tickets per project that keep their media")
    parser.add_argument("--apply", action="store_true", help="delete files and rewrite links (default: report only)")
    args = parser.parse_args()
    if args.keep_recent < 0:
        parser.error("--keep-recent must be zero or more")
    _, delete, rewrite = plan(ROOT, args.keep_recent)
    removed = {f.resolve() for f in delete}
    freed = sum(f.stat().st_size for f in delete)
    rewritten = sum(rewrite_links(ticket, removed, args.apply) for ticket in rewrite)
    if args.apply:
        for file in delete:
            file.unlink()
        for folder in sorted({f.parent for f in delete}, key=lambda p: len(p.parts), reverse=True):
            if folder.name != "images" and folder.is_dir() and not any(folder.iterdir()):
                folder.rmdir()
    verb = "Removed" if args.apply else "Would remove"
    print(f"{verb} {len(delete)} files ({freed / 1048576:.0f} MB); {rewritten} links in {len(rewrite)} older tickets become text.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

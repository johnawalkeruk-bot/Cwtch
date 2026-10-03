"""Audit every local published blog post and preview, without publishing anything."""
import json
from datetime import date
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_blog

SITE = Path(__file__).resolve().parents[1] / "Website"

class Links(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.links = []
        self.ids = set()
        self.feed(text)
    def handle_starttag(self, tag, attrs):
        data = dict(attrs)
        if "id" in data:
            self.ids.add(data["id"])
        for key in ("href", "src"):
            if data.get(key):
                self.links.append(data[key])

def audit():
    posts = json.loads((SITE / "blog/posts.json").read_text(encoding="utf-8"))
    entries = {e["id"]: e for e in json.loads((SITE / "changelog.json").read_text(encoding="utf-8"))["entries"]}
    assert len({p["version"] for p in posts}) == len(posts), "Duplicate release post"
    versions = [tuple(map(int, p["version"].split("."))) for p in posts]
    assert versions == sorted(versions, reverse=True), "Posts must be newest first"
    images = set()
    files = [SITE / "blog.html", SITE / "blog/preview.html"]
    for post in posts:
        entry = entries[post["version"]]
        assert post["author"] == build_blog.AUTHOR, post["version"] + ": incorrect author"
        date.fromisoformat(post["date"])
        for field in ("title", "date", "sections"):
            assert post[field] == entry[field], post["version"] + ": changelog mismatch for " + field
        path = SITE / ("blog/v" + post["version"] + ".html")
        assert path.read_text(encoding="utf-8") == build_blog.article(post, SITE), str(path) + ": stale generated page"
        files.append(path)
        for shot in post["screenshots"]:
            assert shot["caption"].strip(), "Missing screenshot caption"
            image = SITE / shot["path"]
            content = image.read_bytes()
            assert len(content) > 100 and (content.startswith(b"\x89PNG\r\n\x1a\n") or content.startswith(b"\xff\xd8") or content[8:12] == b"WEBP"), str(image) + ": invalid image"
            images.add(image)
    count = 0
    for file in files:
        text = file.read_text(encoding="utf-8")
        assert "\ufffd" not in text, str(file) + ": damaged text encoding"
        assert "Waldas Gamer Studios" not in text, str(file) + ": outdated studio name"
        for link in Links(text).links:
            parsed = urlsplit(link)
            if parsed.scheme or parsed.netloc:
                continue
            target = (file.parent / unquote(parsed.path)).resolve() if parsed.path else file
            assert target.is_relative_to(SITE.resolve()), "Link leaves website: " + link
            assert target.is_file(), str(file) + ": missing " + link
            if parsed.fragment and target.suffix == ".html":
                assert unquote(parsed.fragment) in Links(target.read_text(encoding="utf-8")).ids, str(file) + ": missing anchor " + link
            count += 1
    print(f"BLOG_AUDIT_PASS: {len(posts)} published posts, development preview, {len(images)} published images and {count} local links; authors, release details and encoding checked.")

if __name__ == "__main__":
    audit()

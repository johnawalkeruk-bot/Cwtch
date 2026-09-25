# CWTCH game page

Public address: https://johnawalkeruk-bot.github.io/Cwtch/

The page is hosted from the repository's `gh-pages` branch. Its download button
always points at the launcher asset in the latest public release. Version and
download sizes are read from GitHub; if that lookup fails the link still works.

Edit the HTML, CSS or JavaScript here, then publish from the CWTCH directory:

```
Launcher\Python\python.exe DevTools\publish_site.py
```

This publishes only the listed website assets. Game releases are published
separately with Publish Next Version.cmd.

## Changelog workflow

Edit `changelog.json` after every completed game change. Put unpublished work in the
`unreleased` entry, then run `Launcher/Python/python.exe DevTools/build_changelog.py`
from the project root. This builds a static, accessible `changelog.html` with no
JavaScript requirement. Do not edit the generated page by hand.

Publishing is manual at the user's request. The manual game publisher promotes notes
to the new version and publishes the website after the game release succeeds. For a
website-only update, run the publish_site.py command above manually. If that step
fails after a game release, retry website publication alone; do not recreate the tag.

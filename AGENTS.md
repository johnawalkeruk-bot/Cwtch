# CWTCH development

This desktop folder is the canonical project. Edit Game/ here, not older workspace copies.
Preserve source models in NPCS/, Trees/ and Tools/. Never commit .local/, credentials,
player saves, engine caches or generated release archives.

After every completed user-requested game change:
- Run appropriate checks and update Game/FULL_SOURCE.md.
- Add concise, player-facing notes to the unreleased entry in Website/changelog.json.
  Cover additions, changed behaviour, fixes and any save compatibility changes.
  Do not claim unfinished work or assign an unpublished change to a released version.
- Run Launcher/Python/python.exe DevTools/build_changelog.py to regenerate the website
  changelog. Update the website in the same working change, every time.
- The user now handles publishing manually. Do not commit, push, release, or run
  publish_site.py or Publish-Version.ps1 unless the user explicitly requests publishing.
  Report local completion and any remaining checks honestly.

The user's manual Publish Next Version.cmd promotes unreleased notes to its version,
publishes the game, and updates the website. Never force-push or rewrite released tags.

For every future completed update, also maintain the unreleased entry's `blog`
editorial notes: a humorous but factual introduction, reasons for the changes,
recorded issues/limitations, and real screenshots where possible. Author all posts
as Waldas Game Studios. Store uniquely named images in Website/assets/blog/ and
run DevTools/build_blog.py for the local preview. Manual publishing creates one
post per release automatically. Never invent issues, screenshots or test results;
never overwrite published post snapshots or their images while drafting an update.

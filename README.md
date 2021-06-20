## Sparkle+Github Release Integration

Blog post: http://yiqiu.me/2015/11/19/sparkle-update-on-github/

### Install

1. Switch to `gh-pages` branch, put `appcast.inc` into `_includes` directory (You may need to create it yourself.) Again, modify the project name (line 20) in the file to your need.
2. Put `appcast.xml` into the root directory
3. Put the URL to the `appcast.xml` into the `SUFeedURL` of your `Info.plist`.
4. Push the branches.

### Usages

1. Follow normal release process and upload the asset file to GitHub, with naming convention `<Project>.v.b.<CFBundleVersion>.{zip,dmg}`
2. Push to the `gh-pages` branch to trigger a rebuild. (http://stackoverflow.com/questions/24098792/how-to-force-github-pages-build)

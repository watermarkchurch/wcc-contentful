The home of multiple gems that Watermark Community Church uses to integrate with
Contentful.

* [wcc-contentful](./wcc-contentful)

## Deployment instructions:

1) Bump the version number using the appropriate rake task:

```
rake bump:major
rake bump:patch
rake bump:minor
rake bump:pre
```

Note: ensure that the versions of both gems are synchronized!  CI will run
`rake check` and will fail if this is not the case.  The bump tasks handle this
automatically.

2) Commit and tag the release:

```
git commit -m "Release vX.X.X
git tag -s vX.X.X
git push --follow-tags
```

3) Have a beer!  [CircleCI will handle the rest.](https://circleci.com/gh/watermarkchurch/workflows/wcc-contentful)
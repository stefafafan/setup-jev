# setup-jev

A small GitHub Action that installs a released
[`stefafafan/jev`](https://github.com/stefafafan/jev) binary and adds it to
`PATH`.

## Usage

Specify the Jev version explicitly:

```yaml
permissions:
  contents: read

steps:
  - uses: stefafafan/setup-jev@v1
    with:
      version: v0.1.1
  - run: jev --version
```

For security-sensitive workflows, pin this action to a full commit SHA instead
of the movable `v1` tag:

```yaml
- uses: stefafafan/setup-jev@FULL_COMMIT_SHA # v1.0.0
  with:
    version: v0.1.1
```

`latest` is also supported when reproducibility is not required:

```yaml
- uses: stefafafan/setup-jev@v1
  with:
    version: latest
```

The action version in `uses` and the Jev binary version in `version` are
independent.

## Using Jev

Provider credentials belong on the step that runs `jev`, not on the setup
step:

```yaml
- uses: stefafafan/setup-jev@v1
  with:
    version: v0.1.1

- name: Evaluate a diff
  env:
    AI_GATEWAY_API_KEY: ${{ secrets.AI_GATEWAY_API_KEY }}
  run: |
    git diff origin/main...HEAD |
      jev --provider vercel noul \
        'Could this change introduce a regression?'
```

See the [Jev CLI documentation](https://github.com/stefafafan/jev) for TypeSafe
AI and Cloudflare configuration and the available question primitives.

## Supported Runners

| Runner OS | Architectures |
| --- | --- |
| Linux | X64, ARM64 |
| macOS | X64, ARM64 |
| Windows | X64, ARM64 |

The action downloads the matching release archive and `checksums.txt` from
`stefafafan/jev`, verifies its SHA-256 checksum, checks the installed version,
and then adds the binary directory to `PATH`.

The resolved version is available as the `version` output:

```yaml
- id: setup-jev
  uses: stefafafan/setup-jev@v1
  with:
    version: latest
- run: echo "Installed Jev ${{ steps.setup-jev.outputs.version }}"
```

## License

[MIT](LICENSE)

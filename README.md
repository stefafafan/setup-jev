# setup-jev

GitHub Action that installs a released [`stefafafan/jev`](https://github.com/stefafafan/jev) binary and adds it to the `PATH` for later usage.

## Usage

Specify the stefafafan/jev version explicitly:

```yaml
- uses: stefafafan/setup-jev@ee163438b847a374ca9e4f44f08e376da69e2df9 # v1.0.0
  with:
    version: v0.1.1
- run: jev --version
```

## Classifying Pull Request Risk with Jev

The following workflow evaluates the diff when a pull request is opened or updated, then applies exactly one merge-risk label:

```yaml
name: Jev risk classification

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

permissions:
  contents: read
  pull-requests: write

concurrency:
  group: jev-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  classify:
    if: >-
      github.event.pull_request.draft == false &&
      github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: stefafafan/setup-jev@ee163438b847a374ca9e4f44f08e376da69e2df9 # v1.0.0
        with:
          version: v0.1.1

      - name: Classify merge risk
        id: classify
        env:
          TYPESAFE_API_KEY: ${{ secrets.TYPESAFE_API_KEY }}
          GH_TOKEN: ${{ github.token }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
        run: |
          instructions='Classify the merge risk of this pull request as low, medium, or high. '
          instructions+='Use high for likely regressions, backwards-incompatible changes, or changes to security-sensitive or persisted-data behavior. '
          instructions+='Use medium when focused human review is warranted but no concrete high-risk issue is apparent. '
          instructions+='Use low when no material merge risk is apparent from the diff.'

          result=$(gh pr diff "$PR_NUMBER" --repo "$GITHUB_REPOSITORY" | \
            jev --provider vercel choice \
              --option risk-low \
              --option risk-medium \
              --option risk-high \
              "$instructions")

          risk=$(jq -er '.answers.result.choice' <<< "$result")
          echo "risk=$risk" >> "$GITHUB_OUTPUT"

      - name: Apply risk label
        env:
          GH_TOKEN: ${{ github.token }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          RISK: ${{ steps.classify.outputs.risk }}
        run: |
          gh pr edit "$PR_NUMBER" --repo "$GITHUB_REPOSITORY" \
            --remove-label 'jev: risk-low,jev: risk-medium,jev: risk-high'
          gh pr edit "$PR_NUMBER" --repo "$GITHUB_REPOSITORY" \
            --add-label "jev: $RISK"
```

See the [Jev CLI documentation](https://github.com/stefafafan/jev) for Vercel and Cloudflare configuration and the available question primitives.

## Supported Runners

| Runner OS | Architectures |
| --- | --- |
| Linux | X64, ARM64 |
| macOS | X64, ARM64 |
| Windows | X64, ARM64 |

The action downloads the matching release archive and `checksums.txt` from `stefafafan/jev`, verifies its SHA-256 checksum, checks the installed version, and then adds the binary directory to `PATH`.

## License

[MIT](LICENSE)

# Query Doctor CI

Run this action after your test suite. It sends the SQL your tests ran to Query Doctor, which reports regressions, missing indexes and schema changes on the pull request. The step fails when the check does.

The same report appears on the job's Summary tab. That is the only place it appears on a push run, which has no pull request to comment on.

## Usage

Run your tests against a Postgres with `pg_stat_statements` enabled, then:

```yaml
- uses: query-doctor/ci@v1
  with:
    token: ${{ secrets.QUERYDOCTOR_TOKEN }}
    database-url: postgres://postgres:postgres@localhost:5432/myapp_test
```

Trigger the workflow on `pull_request` and on `push` to your main branch. For a complete workflow fitted to your repo, use the `setup_ci` MCP tool or copy the one on your project's CI page.

## Inputs

| Input          | Required | Default                         | Description                                                    |
| -------------- | -------- | ------------------------------- | -------------------------------------------------------------- |
| `token`        | yes      |                                 | Project token, stored as the secret `QUERYDOCTOR_TOKEN`.       |
| `database-url` | yes      |                                 | The database your tests ran against, as the runner reaches it. |
| `endpoint`     | no       | `https://cloud.querydoctor.com` | Your instance's address if you self-host.                      |

## Outputs

| Output    | Description                                                               |
| --------- | ------------------------------------------------------------------------- |
| `verdict` | `success`, `neutral`, `failure`, or `error` when no conclusion came back. |
| `run-url` | The run's page on your Query Doctor instance.                             |

The action asks your instance which Collector to run, so `@v1` keeps working whichever version your instance runs.

This repository is published from Query-Doctor/Site. Report issues there.

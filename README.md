# Query Doctor CI

Run this action after your test suite. It collects the SQL your tests executed, replays it against a real Postgres planner, and reports regressions, missing indexes, and schema problems on the pull request.

## Usage

Your job runs its tests against a Postgres instance with a supported query source enabled (`pg_stat_statements` or `auto_explain`), then hands over to the action:

```yaml
jobs:
  run:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      # ... start postgres with pg_stat_statements or auto_explain,
      #     run migrations and seeds, run your tests ...
      - name: Run Query Doctor
        uses: query-doctor/ci@v1
        with:
          postgres-version: "18"
        env:
          GITHUB_TOKEN: ${{ github.token }}
          TOKEN: ${{ secrets.QUERY_DOCTOR_TOKEN }}
          SOURCE_DATABASE_URL: postgres://postgres:postgres@localhost/myapp_test
          LOG_PATH: /var/log/postgresql/postgres.log
```

Trigger the workflow on `pull_request` and on `push` to your main branch: PR runs are compared against the baseline the main-branch runs establish.

The action starts its own analysis Postgres (`ghcr.io/query-doctor/postgres`, a fork instrumented for planner work), copies the schema from `SOURCE_DATABASE_URL` into it, and does all analysis there. Your database is only read.

## Inputs

| Input              | Required | Default | Description                                        |
| ------------------ | -------- | ------- | -------------------------------------------------- |
| `postgres-version` | yes      | `18`    | `14`, `17`, or `18`. Match your production major.  |

## Environment variables

| Variable              | Required | Description                                                                  |
| --------------------- | -------- | ---------------------------------------------------------------------------- |
| `TOKEN`               | yes      | Project token from [app.querydoctor.com](https://app.querydoctor.com). Store it as a repository secret. |
| `SOURCE_DATABASE_URL` | yes      | Connection string of the database your tests ran against.                    |
| `GITHUB_TOKEN`        | yes      | `${{ github.token }}`. Used to comment on the pull request.                  |
| `LOG_PATH`            | no       | Path to the postgres log file, when `auto_explain` is the query source.      |
| `SITE_API_ENDPOINT`   | no       | Defaults to `https://api.querydoctor.com`. Set it for self-hosted deployments. |

## About this repository

`dist/` is the compiled collector, synced from the private Query-Doctor/Site monorepo by its Publish CI Action workflow. There is no buildable source here; changes arrive as dist syncs, and releases are tags cut from `main`.

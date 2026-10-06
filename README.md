# Query Doctor CI

> **This repository's action is not the current setup.** Query Doctor CI runs the Collector image `ghcr.io/query-doctor/collector:latest` as a container step. There is no `query-doctor/ci@v1` to pin. Follow the setup below, or the full guide at [docs.querydoctor.com/guides/ci-integration](https://docs.querydoctor.com/guides/ci-integration/).

The Collector reads the SQL your tests executed from the job's Postgres, submits it to Query Doctor, waits for the analysis, and exits on the verdict. The platform plans the queries and posts regressions, missing indexes and schema problems on the pull request.

## Usage

Run your tests against a Postgres service with `pg_stat_statements` enabled, then hand over to the Collector:

```yaml
name: Query Doctor

on:
  pull_request:
  push:
    branches: [main]

jobs:
  query-doctor:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    services:
      postgres:
        image: postgres:17
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: myapp_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        command: >-
          postgres
          -c shared_preload_libraries=pg_stat_statements
    steps:
      - uses: actions/checkout@v4
      - name: Enable pg_stat_statements
        run: psql -h localhost -U postgres -d myapp_test -c "CREATE SCHEMA IF NOT EXISTS ext; CREATE EXTENSION IF NOT EXISTS pg_stat_statements SCHEMA ext;"
        env:
          PGPASSWORD: postgres
      # ... install dependencies, run migrations and seeds, run your tests
      #     against postgres://postgres:postgres@localhost/myapp_test ...
      - name: Run Query Doctor
        uses: docker://ghcr.io/query-doctor/collector:latest
        env:
          CI: "true"
          GITHUB_TOKEN: ${{ github.token }}
          TOKEN: ${{ secrets.QUERYDOCTOR_TOKEN }}
          SOURCE_DATABASE_URL: postgres://postgres:postgres@postgres:5432/myapp_test
          SITE_API_ENDPOINT: https://cloud.querydoctor.com
```

Trigger the workflow on `pull_request` and on `push` to your main branch: PR runs are compared against the baseline the main-branch runs establish.

The Collector step runs as a container on the job's network, so it reaches the database at the service name (`postgres`), not `localhost`. A container step does not inherit `CI` from the runner, so set it on the step.

The easiest way to get a workflow that fits your repo is to ask the Query Doctor MCP server's `setup_ci` tool, or copy the one shown on your project's CI page. Both render the same template as the block above.

## Environment variables

| Variable              | Required | Description |
| --------------------- | -------- | ----------- |
| `TOKEN`               | yes      | Project token from [cloud.querydoctor.com](https://cloud.querydoctor.com). Store it as the repository secret `QUERYDOCTOR_TOKEN`. |
| `SOURCE_DATABASE_URL` | yes      | Connection string of the database your tests ran against, as seen from the container: host `postgres`. |
| `GITHUB_TOKEN`        | yes      | `${{ github.token }}`. Used to comment on the pull request. |
| `CI`                  | yes      | `"true"`. Makes the Collector capture once and exit on the verdict. |
| `SITE_API_ENDPOINT`   | yes      | `https://cloud.querydoctor.com` on the hosted service, or your instance's address if you self-host. |

## Moving off api.querydoctor.com

A workflow that uses `query-doctor/analyzer@main`, `query-doctor/ci`, the secret `QUERY_DOCTOR_TOKEN` or the endpoint `https://api.querydoctor.com` is on the old platform. Replace its Query Doctor step with the one above, create a project on cloud.querydoctor.com, and store its token as `QUERYDOCTOR_TOKEN`.

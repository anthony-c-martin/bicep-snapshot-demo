# `bicep snapshot` Demo

This repo exists to demonstrate an example use-case for the [`bicep snapshot` experimental CLI command](https://github.com/Azure/bicep/blob/main/docs/experimental/snapshot-command.md), which will be available in Bicep version 0.36 (see [Installing Nightly](https://github.com/Azure/bicep/blob/main/docs/installing-nightly.md) if you want to preview this before it is released). It contains some existing infrastructure files for deploying a medium-level complexity containerized application under [handler.bicepparam](https://github.com/anthony-c-martin/bicep-snapshot-demo/blob/main/infra/handler.bicepparam) and [registry.bicepparam](https://github.com/anthony-c-martin/bicep-snapshot-demo/blob/main/infra/registry.bicepparam).

## What is a snapshot?
The snapshot file (`*.snapshot.json`) contains a normalized view of all of the resource operations that'll take place if the given `.bicepparam` file is deployed to Azure, with all possible expresissions evaluated and expanded. Because this format is resilient to code refactoring, it gives a very quick visual understanding of the actualized impact to resource state of a single code change.

This format is intended to be used for diffing, so that reviewers are able to quickly analyze the impact of a change without requiring a connection to Azure, and can also be used when developing locally as a means of quickly verifying that the code you wrote has the intended impact.

## Usage in CI
When submitting a PR, developers must update their snapshots as well as their infra files, by running the `bicep snapshot` CLI command with `--mode overwrite`. The CI in this repo is configured to run `bicep snapshot` with `--mode validate`, which verifies that the checked-in snapshots exactly match the generated ones. This will block CI from passing **unless** a developer also checks in the correct snapshots as part of the same commit.

### Example of failing PR
[Here](https://github.com/anthony-c-martin/bicep-snapshot-demo/pull/1) is an example of a PR where a developer has forgotten to update the snapshot and is informed that an unexpected change to the predicted state will happen as a result of their PR, which blocks merging:

<img width="757" alt="image" src="https://github.com/user-attachments/assets/37cd5872-16be-4c5c-a1a6-b3e4c2feda23" />

### Example of passing PR
[Here](https://github.com/anthony-c-martin/bicep-snapshot-demo/pull/2) is an example of a PR where a developer has remembered to update the snapshot. The CI checks pass, and a reviewer is able to inspect the differences in the code review:

<img width="1229" alt="image" src="https://github.com/user-attachments/assets/4c4bdef9-9042-4aeb-a604-314b6f0d501f" />

As you can see, the changes to the predicted state of the resource are visible, as opposed to just unevaluated expressions.

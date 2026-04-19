# LedgerRun Terraform Modules Monorepo

See the Wiki for the most up-to-date module versions.

## New Module Development

This repository uses Conventional Commit messages to automatically determine the next semversion.

Make sure that you have the following programs installed and in your $PATH:

- tfenv
- tflint
- terraform-docs
- pre-commit
- tfsec
- coreutils
- bash

This can be done on MacOS by running the `bin/install-macos.zsh` script included in this repository.

Once everything is installed, create your new module by copying the `template` directory and renaming it to your module's name. Create and edit the files as needed.

When you try to push your code, a `pre-commit` hook will run and validate that the terraform is correct and will automatically update the `README.md` of your module. If any test fails or your README is updated, the code will not be pushed. You'll need to git add and git commit any changes until all the tests pass before the code will be pushed up to Github.

Once in Github, an Action will run to determine the next version and will dispaly this output to you in the PR. If everything looks good, a new release will be built on merge. You may then use this versioned module.

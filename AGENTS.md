# Repository Instructions

## Commit messages

- Use a Conventional Commit subject for every non-merge commit.
- Use this format: `<type>[optional scope][!]: <description>`.
- Use a lowercase type. Common types include `feat`, `fix`, `docs`, `test`,
  `refactor`, `build`, `ci`, and `chore`.
- Check the proposed subject before you create the commit:

  ```bash
  sh tools/ci/check_conventional_commits.sh --subject "feat(flags): add initialization timeout"
  ```

- Change an invalid subject before you create the commit.
- Do not amend, rebase, or force-push only to repair a commit subject.
- If a pushed commit has an invalid subject, stop and ask the user for the
  recovery method.

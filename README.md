# shortcuts

Handy bash shortcuts. Each shortcut can also set up bash completion for itself, if the `complete` command is available

# Usage

## Enabling all shortcuts

Add the following to your `~/.bash_profile`

```bash
source "<path-to-repo>/all.sh"
```

## Enabling only certain shorcuts

Add the following to your `~/.bash_profile`

```bash
source "<path-to-repo>/shortcuts/<shortcut>.sh"
```

# Available Shortcuts

### [`git-prune`](./shortcuts/git-prune.sh)

Prune git branches which have not been touched in 30 days, or had their upstream deleted.

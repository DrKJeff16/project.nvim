<div align="center">

# CONTRIBUTING

</div>

## Table of Contents

1. [What I Will Not Accept](#what-i-will-not-accept)

---

## What I Will Not Accept

- **UNCREDITED CODE**. If pulling from somewhere else, _**paste the reference URL in a comment**_
- **NO LUA ANNOTATIONS**. Annotate your Lua code, follow [this reference](https://luals.github.io/wiki/annotations/)
- **UNSIGNED COMMITS**. Read [this guide](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key)
  to sign your commits
- **UNTESTED CHANGES** (if warranted). Make sure to test your changes before making a PR
- **UNFORMATTED CODE**. Run `stylua` in the root of the repository (`stylua .`). See [`.stylua.toml`](./.stylua.toml)
- **NON-`LF` LINE ENDINGS**. Make sure to set the following through `git config`:
    ```sh
    # If you want to enforce this only in this repository
    git config --local core.autocrlf false
    git config --local core.eol lf

    # If you want to enforce this in your global settings
    git config --global core.autocrlf false
    git config --global core.eol lf
    ```
    (Recommended) and set this in your Nvim config:
    ```lua
    -- init.lua, for instance
    vim.opt.fileformat = 'unix'
    ```
    or
    ```vim
    " init.vim, for instance
    set fileformat=unix
    ```

## Instructions

> **TODO**

<div align="center">

# CONTRIBUTING

</div>

---

## Table of Contents

1. [Note For Co-Maintainers](#note-for-co-maintainers)
2. [What I Will Not Accept](#what-i-will-not-accept)
3. [Recommendations](#recommendations)
    1. [StyLua](#stylua)
    2. [`pre-commit`](#pre-commit)
    3. [`selene`](#selene)
4. [Code Annotations](#code-annotations)

---

## Note For Co-Maintainers

First of all thank you for being passionate about this plugin as I am.
It means the world to me.

Please follow the instructions stated below. These are not set in stone.
For transparency if yow have any suggestions, even regarding this very document,
open a blank issue so we can discuss these publicly.

---

## What I Will Not Accept

- **UNCREDITED CODE**. If pulling from somewhere else, _**paste the reference URL in a comment**_
- **MISSING LUA ANNOTATIONS**. See [Code Annotations](#code-annotations)
- **MERGE COMMITS**. Favour `git rebase` instead
- **UNSIGNED COMMITS**. Read the guide on signing your commits[^2]
- **UNTESTED CHANGES** _(if warranted)_. Make sure to test your changes before making a PR
- **UNFORMATTED CODE**. See the [StyLua](#stylua) section
- **NON-UNIX LINE ENDINGS**. Make sure to set your config in your CLI:
    ```sh
    # If you want to enforce this only in this repository
    git config --local core.autocrlf false
    git config --local core.eol lf

    # If you want to enforce this in your global settings
    git config --global core.autocrlf false
    git config --global core.eol lf
    ```
    And set this in your nvim config (recommended):
    ```lua
    -- init.lua, for instance
    vim.o.fileformat = 'unix'
    ```
    or
    ```vim
    " init.vim, for instance
    set fileformat=unix
    ```

---

## Recommendations

### StyLua

> [!IMPORTANT]
> **This one's a requirement.**

This will format any Lua file that needs it.

You can install StyLua through your package manager or by following
[these instructions](https://github.com/JohnnyMorganz/StyLua#installation).

> [!TIP]
> To run it, you must be **in the root of the repository**.
> Simply run the following command:
>
> ```sh
> stylua .
> ```

> [!WARNING]
> **I will NOT accept any changes to** `.stylua.toml`.

### `pre-commit`

Preferably use `pre-commit` to run the hooks contained in [`.pre-commit-config.yaml`](./.pre-commit-config.yaml).

To install it, follow [these instructions](https://pre-commit.com/#install) in the `pre-commit` website.
After that, run the following command in your terminal:

> [!IMPORTANT]
> Make sure to be in the root of the repository.

```sh
pre-commit install
```

And now every time you run `git commit` the hooks contained in `.pre-commit-config.yaml` will run.

> [!TIP]
> It is recommended for you to update the hooks if required to:
>
> ```sh
> pre-commit autoupdate
> ```
>
> You must then commit the changes to `.pre-commit-config.yaml`.

### selene

[`selene`](https://github.com/Kampfkarren/selene) is used for linting Lua code.

The configuration is already set, you only need to install it through `cargo`:

```sh
cargo install selene
```

or your package manager of preference.

> [!TIP]
> To use it, just run it **from the root of the repository**:
>
> ```sh
> selene .
> ```

> [!WARNING]
> I will not accept any changes to `selene.toml` or `vim.yml`.

---

## Code Annotations

> [!WARNING]
> **Undocumented code will be either asked for corrections or,
> if not willing to document, _rejected_.**

> [!IMPORTANT]
> Please refer to LuaLS' code annotations to understand the syntax.[^1]

Let's say you create a new submodule `lua/project_nvim/foo.lua`. If said module returns a table
with fields, the optimal way to document is to do it **in the same file**, and following this format:

```lua
---A table that contains `foo`.
---@class Project.Foo
local Foo = {}

return Foo
```

If any fields are defined, preferably define them as below:

```lua
---A table that contains `foo` and more.
--- ---
---@class Project.Foo
---An **OPTIONAL** data field containing things.
--- ---
---@field things? table
local Foo = {}

---A data field containing stuff.
--- ---
Foo.stuff = 1.0 -- Or whatever data should go here

---A function that does `Foo`.
---@param x any Data containing whatever
---@param y_optional? table OPTIONAL table containing riches
function Foo.do_foo(x, y_optional)
  -- Blah blah blah
  Foo.things = true
end

---A function that does `Bar`.
--- ---
---@param verbose? boolean OPTIONAL flag that enables verbose behaviour
function Foo.do_bar(verbose)
  -- Blah blah blah
  Foo.things = false
end

-- Blah blah blah

return Foo
```

> [!IMPORTANT]
> **BEAR IN MIND THAT ANY FIELD THAT'S NOT EXPLICITLY DEFINED
> SHOULD GO UNDER THE** `---@class` **ANNOTATION**.
> e.g. `Foo.things` from above.

---

## Footnotes

[^1]: https://luals.github.io/wiki/annotations/
[^2]: https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key

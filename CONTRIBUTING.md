# Contributing

Thank you for your contribution!
Here you will find some tips, guidelines and other resources for contributing to `project.nvim`.

---

## Note For Co-Maintainers

First of all thank you for being passionate about this plugin as I am.
It means the world to me.

Please follow the instructions stated below. These are not set in stone.
For transparency's sake if yow have any suggestions, even regarding this very document,
you may open a blank issue.

---

## Table of Contents

- [Guidelines](#guidelines)
  - [What I Will Not Accept](#what-i-will-not-accept)
- [Recommendations](#recommendations)
  - [StyLua](#stylua)
  - [`pre-commit`](#pre-commit)
  - [`selene`](#selene)
- [Code Annotations](#code-annotations)

---

## Guidelines

### What I Will Not Accept

- **BAD COMMIT MESSAGES**. Read [this guide](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13) to get familiarized
- **UNCREDITED CODE**. If pulling from somewhere else, _**paste the reference URL in a comment**_
- **AI-GENERATED CODE**. The code here must be up to date and made with effort
- **MISSING LUA ANNOTATIONS**. See [Code Annotations](#code-annotations)
- **MERGE COMMITS**. Favour `git rebase` instead
- **UNSIGNED COMMITS**. Read [this guide](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key) to sign your commits. Unsigned commits will be squashed,
  manually rebased by the author or rejected altogether if the occasion warrants it.
- **UNTESTED CHANGES** _(if warranted)_. Make sure to test your changes before making a Pull Request
- **UNFORMATTED CODE**. See the [StyLua](#stylua) section
- **NON-UNIX LINE ENDINGS**. Make sure to set your config in your CLI:
    ```bash
    # If you want to enforce this only in this repository
    git config --local core.autocrlf false
    git config --local core.eol lf

    # If you want to enforce this in your global settings
    git config --global core.autocrlf false
    git config --global core.eol lf
    ```
    And set this in your Neovim config (recommended):
    ```lua
    -- init.lua
    vim.opt.fileformat = 'unix' -- WRONG
    vim.o.fileformat = 'unix' -- CORRECT
    ```

---

## Recommendations

### StyLua

This will format any Lua file that needs it. **I WILL NOT ACCEPT ANY CHANGES TO** `.stylua.toml`,
create an issue instead.

You can install StyLua through your package manager or by following
[these instructions](https://github.com/JohnnyMorganz/StyLua#installation).

To run it, you must be **in the root of the repository**.
Simply run the following command:

```bash
stylua .
```

### `pre-commit`

**Make sure to be in the root of the repository.**

I encourage you to use `pre-commit` to run the hooks contained in [`.pre-commit-config.yaml`](./.pre-commit-config.yaml).

To install it, follow [these instructions](https://pre-commit.com/#install) in the `pre-commit` website.
After that, run the following command in your terminal:

```bash
pre-commit install
```

Now every time you run `git commit` the hooks contained in `.pre-commit-config.yaml` will run.

It is recommended for you to update the hooks if required to:

```bash
pre-commit autoupdate
```

You must then commit the changes to `.pre-commit-config.yaml`.

### selene

[`selene`](https://github.com/Kampfkarren/selene) is used for linting Lua code.

The configuration is already set in [`vim.yml`](./vim.yml) and [`selene.toml`](./selene.toml).
You only need to install it through `cargo`:

```bash
cargo install selene
```

or your package manager of preference.

To use it, just run it **from the root of the repository**:

```bash
selene lua/
```

---

## Code Annotations

> [!WARNING]
> **Undocumented code will be either asked for corrections or,
> if not willing to document, _rejected_.**

Please refer to LuaLS' [code annotations](https://luals.github.io/wiki/annotations/)
to understand the syntax.

Let's say you create a new submodule `lua/project/foo.lua`. If said module returns a table
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

Bear in mind that any field that's not explicitly defined should go under the**
`---@class` annotation, e.g. `Foo.things` from above.

Any instance of wrapping already existing data types will be rejected.

```lua
---NOT ALLOWED
---@alias StringType string
---@alias Int integer

---ALLOWED
---@alias StringDict table<string, any>
---@alias IntList integer[]
```

<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->

# Notes made during development

## Vanilla way

Vanilla version is not building because pyproject is expecting sort of "vanilla"
approach from developer to maintain instead of poetry or uv and refer to whatever
x2nix for proper support.

### The last crashout

```
> * Getting build dependencies for wheel...
>
> Traceback (most recent call last):
>   File "/nix/store/m3ppxy345vbsincqmc3irvg70gvglmzl-python3.13-pyproject-hooks-1.2.0/lib/python3.13/site-packages/pyproject_hooks/_impl.py", line 402, in _call_hook
>     raise BackendUnavailable(
>     ...<4 lines>...
>     )
> pyproject_hooks._impl.BackendUnavailable: Cannot import 'poetry.core.masonry.api'
>
> ERROR Backend 'poetry.core.masonry.api' is not available.
```

### Possible solution

For the original element-hq/sygnal project and rewrite it to "vanilla" way of managing dependencies.

### Updates

Tried changing build-tools and got another warning, yikes! Some progress, but this one is irrecoverable, meaningly, gotta hunt different nixpkgs to match every dependency in poetry. I'll attempt to find versions but can't promise, `www.nixhub.io` save my day!

```
Executing pythonRuntimeDepsCheck
Checking runtime dependencies for matrix_sygnal-0.17.0-py3-none-any.whl
  - aioapns<4.0,>=3.0 not satisfied by version 4.0
  - prometheus-client<0.8,>=0.7.0 not satisfied by version 0.22.1
```

...

So, found aioapns, butt... prometheus one is way too ancient to be even considered adding: https://www.nixhub.io/packages/python27Packages.prometheus_client. Is there any way to combine python2 deps with python3 and expect it to work?

## Poetry2nix way

Poetry depends on very outdated nixpkgs. Also, due to the project being deprecated,
hashes and many library references are lacking such as rust reliant dependency hashes.

### The last crashout

```
error: No hash was found while vendoring the git dependency unicode_names2-0.6.0. You can add
a hash through the `outputHashes` argument of `importCargoLock`:

outputHashes = {
  "unicode_names2-0.6.0" = "<hash>";
};

If you use `buildRustPackage`, you can add this attribute to the `cargoLock`
attribute set.
```

### Possible solution

Forking poetry2nix and keeping hashes and whatever signatures up-to-date.

### Updates

I went through poetry2nix overrides and see how they patch cargo hashes and behold and lo, I came across [this](https://github.com/nix-community/poetry2nix/blob/ce2369db77f45688172384bbeb962bc6c2ea6f94/overrides/default.nix#L3440C1-L3440C72). When I `nix run .#poetry`,  it throws eval warning stating that `0.0.291` version is not covered but it is. I'm confused.

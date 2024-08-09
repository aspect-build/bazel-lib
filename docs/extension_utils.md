<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API

<a id="extension_utils.toolchain_repos_bfs"></a>

## extension_utils.toolchain_repos_bfs

<pre>
extension_utils.toolchain_repos_bfs(<a href="#extension_utils.toolchain_repos_bfs-mctx">mctx</a>, <a href="#extension_utils.toolchain_repos_bfs-get_tag_fn">get_tag_fn</a>, <a href="#extension_utils.toolchain_repos_bfs-toolchain_name">toolchain_name</a>, <a href="#extension_utils.toolchain_repos_bfs-toolchain_repos_fn">toolchain_repos_fn</a>,
                                    <a href="#extension_utils.toolchain_repos_bfs-default_repository">default_repository</a>, <a href="#extension_utils.toolchain_repos_bfs-get_name_fn">get_name_fn</a>, <a href="#extension_utils.toolchain_repos_bfs-get_version_fn">get_version_fn</a>)
</pre>

Create toolchain repositories from bzlmod extensions using a breadth-first resolution strategy.

Toolchains are assumed to have a "default" or canonical repository name so that across
all invocations of the module extension with that name only a single toolchain repository
is created. As such, it is recommended to default the toolchain name in the extension's
tag class attributes so that diverging from the canonical name is a special case.

The resolved toolchain version will be the one invoked closest to the root module, following
Bazel's breadth-first ordering of modules in the dependency graph.

For example, given the module extension usage in a MODULE file:

```starlark
ext = use_extension("@my_lib//lib:extensions.bzl", "ext")

ext.foo_toolchain(version = "1.2.3") # Default `name = "foo"`

use_repo(ext, "foo")

register_toolchains(
    "@foo//:all",
)
```

This macro would be used in the module extension implementation as follows:

```starlark
extension_utils.toolchain_repos(
    mctx = mctx,
    get_tag_fn = lambda tags: tags.foo_toolchain,
    toolchain_name = "foo",
    toolchain_repos_fn = lambda name, version: register_foo_toolchains(name = name, register = False),
    get_version_fn = lambda attr: None,
)
```

Where `register_foo_toolchains` is a typical WORKSPACE macro used to register
the foo toolchain for a particular version, minus the actual registration step
which is done separately in the MODULE file.

This macro enforces that only root MODULEs may use a different name for the toolchain
in case several versions of the toolchain repository is desired.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="extension_utils.toolchain_repos_bfs-mctx"></a>mctx |  The module context   |  none |
| <a id="extension_utils.toolchain_repos_bfs-get_tag_fn"></a>get_tag_fn |  A function that takes in <code>module.tags</code> and returns the tag used for the toolchain. For example, <code>tag: lambda tags: tags.foo_toolchain</code>. This is required because <code>foo_toolchain</code> cannot be accessed as a simple string key from <code>module.tags</code>.   |  none |
| <a id="extension_utils.toolchain_repos_bfs-toolchain_name"></a>toolchain_name |  Name of the toolchain to use in error messages   |  none |
| <a id="extension_utils.toolchain_repos_bfs-toolchain_repos_fn"></a>toolchain_repos_fn |  A function that takes (name, version) and creates a toolchain repository. This lambda should call a typical reposotiory rule to create toolchains.   |  none |
| <a id="extension_utils.toolchain_repos_bfs-default_repository"></a>default_repository |  Default name of the toolchain repository to pass to the repos_fn. By default, it equals <code>toolchain_name</code>.   |  <code>None</code> |
| <a id="extension_utils.toolchain_repos_bfs-get_name_fn"></a>get_name_fn |  A function that extracts the module name from the toolchain tag's attributes. Defaults to grabbing the <code>name</code> attribute.   |  <code>None</code> |
| <a id="extension_utils.toolchain_repos_bfs-get_version_fn"></a>get_version_fn |  A function that extracts the module version from the a tag's attributes. Defaults to grabbing the <code>version</code> attribute. Override this to a lambda that returns <code>None</code> if version isn't used as an attribute.   |  <code>None</code> |



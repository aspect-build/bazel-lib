BinaryInfo = provider(
    doc = "Provide info for binary",
    fields = {
        "bin": "Target for the binary",
    },
)

def _toolchain_impl(ctx):
    binary_info = BinaryInfo(
        bin = ctx.attr.bin,
    )

    toolchain_info = platform_common.ToolchainInfo(
        binary_info = binary_info,
    )

    return [toolchain_info]

binary_toolchain = rule(
    implementation = _toolchain_impl,
    attrs = {
        "bin": attr.label(
            mandatory = True,
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),
    },
)

binary_runtime_toolchain = rule(
    implementation = _toolchain_impl,
    attrs = {
        "bin": attr.label(
            mandatory = True,
            allow_single_file = True,
            executable = True,
            cfg = "target",
        ),
    },
)

def _resolved_binary_rule_impl(ctx, toolchain_type, template_variable):
    bin = ctx.toolchains[toolchain_type].binary_info.bin[DefaultInfo]

    out = ctx.actions.declare_file(ctx.attr.name + ".exe")
    ctx.actions.symlink(
        target_file = bin.files_to_run.executable,
        output = out,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = out,
            files = bin.files,
            runfiles = bin.default_runfiles,
        ),
        platform_common.TemplateVariableInfo({
            template_variable: out.path,
        } if template_variable != None else {}),
    ]

def resolved_binary_rule(*, toolchain_type, template_variable = None):
    return rule(
        implementation = lambda ctx: _resolved_binary_rule_impl(ctx, toolchain_type, template_variable),
        executable = True,
        toolchains = [toolchain_type],
    )

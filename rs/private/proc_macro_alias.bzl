"""Keep renamed procedural macros in their compiler's execution configuration."""

load("@rules_rust//rust:defs.bzl", "rust_common")

def _proc_macro_alias_impl(ctx):
    # rules_rust looks up aliases by CrateInfo.owner, which must stay unchanged.
    return [ctx.attr.actual[rust_common.crate_info]]

proc_macro_alias = rule(
    implementation = _proc_macro_alias_impl,
    attrs = {
        "actual": attr.label(cfg = "exec", providers = [rust_common.crate_info]),
    },
    doc = "Supply exec-configured macro metadata to rules_rust's target-configured aliases attribute.",
)

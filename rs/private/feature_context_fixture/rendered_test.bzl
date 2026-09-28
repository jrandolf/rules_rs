"""Exercise the standard compiler's Cargo target markers and macro aliases."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_rust//rust:rust_common.bzl", "CrateInfo")

# buildifier: disable=bzl-visibility
load("@rules_rust//rust/private:rust_analyzer.bzl", "rust_analyzer_aspect")

_SETTING = str(Label("@rules_rust//cargo/settings:cargo_target_triple"))
_WINDOWS = "x86_64-pc-windows-msvc"
_WINDOWS_ARM = "aarch64-pc-windows-msvc"

def _consumer_impl(ctx):
    env = analysistest.begin(ctx)
    crate = analysistest.target_under_test(env)[CrateInfo]
    asserts.equals(env, "consumer.rs", crate.root.basename)
    rustc_args = [arg for action in analysistest.target_actions(env) for arg in (action.argv or [])]
    asserts.true(env, any([arg.removeprefix("--extern=").startswith("renamed_macro=") for arg in rustc_args]), str(rustc_args))
    dylibs = analysistest.target_under_test(env)[OutputGroupInfo].rust_analyzer_proc_macro_dylib.to_list()
    asserts.true(env, any([file.owner.name == "generated_macro" for file in dylibs]), str(dylibs))
    asserts.false(env, any(["__cargo_unresolved" in file.owner.name for file in dylibs]), str(dylibs))
    return analysistest.end(env)

_consumer_test = analysistest.make(_consumer_impl, extra_target_under_test_aspects = [rust_analyzer_aspect], config_settings = {
    "//command_line_option:platforms": str(Label("//rs/platforms:" + _WINDOWS)),
    _SETTING: "target/" + _WINDOWS,
})
_consumer_arm_test = analysistest.make(_consumer_impl, extra_target_under_test_aspects = [rust_analyzer_aspect], config_settings = {
    "//command_line_option:platforms": str(Label("//rs/platforms:" + _WINDOWS_ARM)),
    _SETTING: "target/" + _WINDOWS_ARM,
})

def rendered_tests():
    _consumer_test(name = "rendered_context_test", target_under_test = "@feature_context_rendered//:consumer")
    _consumer_arm_test(name = "rendered_arm_context_test", target_under_test = "@feature_context_rendered//:consumer")

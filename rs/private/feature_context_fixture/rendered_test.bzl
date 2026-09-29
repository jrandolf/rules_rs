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

def _workspace_dependencies_impl(ctx):
    env = analysistest.begin(ctx)
    files = analysistest.target_under_test(env)[DefaultInfo].files.to_list()
    shared = [f.path for f in files if f.basename.startswith("libshared-") and f.extension == "rlib"]
    asserts.equals(env, 2, len(shared), str(files))
    asserts.equals(env, 2, len(set(shared)))
    asserts.true(env, any(["host_only" in f.basename for f in files]), str(files))
    asserts.true(env, any(["generated_macro" in f.basename for f in files]), str(files))
    asserts.false(env, any([f.owner.name.endswith("__cargo_unresolved") for f in files]), str(files))
    return analysistest.end(env)

_workspace_dependencies_test = analysistest.make(_workspace_dependencies_impl, config_settings = {
    "//command_line_option:platforms": str(Label("//rs/platforms:" + _WINDOWS)),
    _SETTING: "",
})

def _single_host_dependency_impl(ctx):
    env = analysistest.begin(ctx)
    files = analysistest.target_under_test(env)[DefaultInfo].files.to_list()
    asserts.equals(env, 1, len(files))
    asserts.true(env, "host_only" in files[0].basename, str(files))
    return analysistest.end(env)

_single_host_dependency_test = analysistest.make(_single_host_dependency_impl, config_settings = {
    "//command_line_option:platforms": str(Label("//rs/platforms:" + _WINDOWS)),
    _SETTING: "",
})

_consumer_test = analysistest.make(_consumer_impl, extra_target_under_test_aspects = [rust_analyzer_aspect], config_settings = {
    "//command_line_option:platforms": str(Label("//rs/platforms:" + _WINDOWS)),
    _SETTING: "target/" + _WINDOWS,
})
_consumer_arm_test = analysistest.make(_consumer_impl, extra_target_under_test_aspects = [rust_analyzer_aspect], config_settings = {
    "//command_line_option:platforms": str(Label("//rs/platforms:" + _WINDOWS_ARM)),
    _SETTING: "target/" + _WINDOWS_ARM,
})

def rendered_tests():
    _single_host_dependency_test(name = "single_host_dependency_test", target_under_test = "@feature_context_rendered//:single_host_dependency")
    _workspace_dependencies_test(name = "workspace_dependencies_test", target_under_test = "@feature_context_rendered//:workspace_dependencies")
    _consumer_test(name = "rendered_context_test", target_under_test = "@feature_context_rendered//:consumer")
    _consumer_arm_test(name = "rendered_arm_context_test", target_under_test = "@feature_context_rendered//:consumer")

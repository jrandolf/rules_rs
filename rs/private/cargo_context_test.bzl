"""Test the Cargo context transition used with the standard compiler rules."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@rules_rust//rust/private:cargo_context.bzl", "CARGO_TARGET", "cargo_context")

_LINUX = "x86_64-unknown-linux-gnu"
_MACOS = "aarch64-apple-darwin"

def _cargo_target_triple_mapping_impl(ctx):
    env = unittest.begin(ctx)
    for incoming, mapping, expected in [
        (_MACOS, {_MACOS: ""}, ""),
        (_MACOS, {}, _MACOS),
        (_MACOS, {_LINUX: ""}, _MACOS),
        ("target/" + _MACOS, {}, _MACOS),
        ("target/" + _MACOS, {_MACOS: ""}, ""),
    ]:
        attr = struct(cargo_target_triple_map = mapping)
        for execution in [False, True]:
            settings = {CARGO_TARGET: incoming, "//command_line_option:is exec configuration": execution}
            result = cargo_context(settings, attr)
            asserts.equals(env, {CARGO_TARGET: expected if execution else incoming}, result)
            asserts.equals(env, incoming, settings[CARGO_TARGET])
            asserts.equals(env, result, cargo_context(settings | result, attr))
    return unittest.end(env)

cargo_target_triple_mapping_test = unittest.make(_cargo_target_triple_mapping_impl)

def cargo_context_tests():
    return unittest.suite("cargo_context_tests", cargo_target_triple_mapping_test)

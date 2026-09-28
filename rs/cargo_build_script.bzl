load("@rules_rust//cargo/private:cargo_build_script_wrapper.bzl", _cargo_build_script = "cargo_build_script")

def cargo_build_script(*args, allow_build_script_to_detect_nonhermetic_paths = False, **kwargs):
    if allow_build_script_to_detect_nonhermetic_paths:
        fail("The selected compiler rules do not support nonhermetic build-script paths")
    kwargs.setdefault("use_cc_toolchain", 1)
    _cargo_build_script(*args, **kwargs)

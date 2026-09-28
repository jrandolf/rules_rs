"""Small generated Cargo repositories for visibility integration tests."""

load("//rs/platforms:triples.bzl", "SUPPORTED_EXEC_TRIPLES")
load("//rs/private:repository_utils.bzl", "render_rust_crate_call", "rust_crate_attrs")
load("//rs/private:visibility.bzl", "visibility_for")

def _repo_impl(rctx):
    crate_name = "dependent" if rctx.attr.deps else "sample"
    rctx.file("Cargo.toml", "[package]\nname = 'sample'\nversion = '1.0.0'\nedition = '2021'\n")
    rctx.file("cargo_toml_env_vars.env", "")
    rctx.file("lib.rs", "extern crate proc_macro;\n#[proc_macro] pub fn marker(_: proc_macro::TokenStream) -> proc_macro::TokenStream { proc_macro::TokenStream::new() }\n" if rctx.attr.macro else ("renamed_macro::marker!();\npub fn value() -> u8 { 1 }\n" if rctx.attr.deps else "pub fn value() -> u8 { 1 }\n"))
    rctx.file("main.rs", """#[no_mangle] pub extern "C" fn original() -> u8 { 7 }
extern "C" { fn aliased() -> u8; }
fn main() { assert_eq!(unsafe { aliased() }, 7); }
""" if crate_name == "sample" and not rctx.attr.macro else "fn main() {}\n")
    rctx.file("build.rs", """fn main() {
    let flag = match std::env::var("CARGO_CFG_TARGET_OS").unwrap().as_str() {
        "macos" => "-Wl,-alias,_original,_aliased",
        "windows" => "/alternatename:aliased=original",
        _ => "-Wl,--defsym=aliased=original",
    };
    println!("cargo::rustc-link-arg-bin=cargo-probe={flag}");
}
""")
    rctx.file("BUILD.bazel", """load("@rules_rs//rs/private:rust_crate.bzl", "rust_crate")
load("@rules_rs//rs/private:proc_macro_alias.bzl", "proc_macro_alias")
RESOLVED_PLATFORMS = []
""" + render_rust_crate_call(rctx.attr, {
        "name": repr(crate_name),
        "crate_name": repr(crate_name),
        "purl": repr("pkg:cargo/sample@1.0.0"),
        "version": repr("1.0.0"),
        "binaries": repr({} if rctx.attr.macro else {"cargo-probe": "main.rs"}),
        "build_script": repr("build.rs") if crate_name == "sample" and not rctx.attr.macro else "None",
        "crate_root": repr("lib.rs"),
        "edition": repr("2021"),
        "has_lib": "True",
        "is_proc_macro": repr(rctx.attr.macro),
        "links": "None",
    }) + ('\nproc_macro_alias(name = "sample__alias", actual = ":sample", visibility = %r)\n' % rctx.attr.crate_visibility if rctx.attr.macro else ""))

_repo = repository_rule(implementation = _repo_impl, attrs = rust_crate_attrs | {"macro": attr.bool()})

def _fixtures_impl(_mctx):
    internal = ["@visibility_dependent//:__pkg__"]
    settings = [struct(crates = ["*"], repositories = [], visibility = ["@rules_rs//rs/private/visibility_fixture/allowed:__pkg__"])]
    for name, macro in [("visibility_lib", False), ("visibility_macro", True), ("visibility_dependent", False)]:
        _repo(
            name = name,
            macro = macro,
            configurations = json.encode({"": {
                "deps_by_triple": {t: ({"@visibility_macro//:sample": "renamed_macro"} if name == "visibility_dependent" else {}) for t in SUPPORTED_EXEC_TRIPLES},
                "crate_features_by_triple": {t: [] for t in SUPPORTED_EXEC_TRIPLES},
                "build_deps_by_triple": {},
                "build_cargo_target_triple_required_on": [],
            }}),
            proc_macro_labels = ["@visibility_macro//:sample"],
            use_legacy_rules_rust_platforms = True,
            crate_visibility = visibility_for(settings, "fixtures", name, internal),
            deps = ["@visibility_lib//:sample"] if name == "visibility_dependent" else [],
        )

fixtures = module_extension(implementation = _fixtures_impl)

load("@package_metadata//licenses:defs.bzl", "license", "license_kind")
load("@package_metadata//rules:package_metadata.bzl", "package_metadata")
load(
    "@rules_rust//rust:defs.bzl",
    _rust_library = "rust_library",
    _rust_proc_macro = "rust_proc_macro",
)
load("//rs:rust_binary.bzl", "rust_binary")
load("//rs:rust_library.bzl", "rust_library")
load("//rs:rust_proc_macro.bzl", "rust_proc_macro")
load(":cargo_build_script_variants.bzl", "cargo_build_script_for_configurations")
load(":cargo_select.bzl", "cargo_select")

def rust_crate(
        name,
        crate_name,
        purl,
        version,
        configurations,
        cargo_target_triple_map,
        hub_name,
        deps,
        link_deps,
        data,
        crate_root,
        edition,
        rustc_flags,
        tags,
        links,
        build_script,
        build_script_data,
        build_script_env,
        build_script_env_files,
        allow_build_script_to_detect_nonhermetic_paths,
        build_script_toolchains,
        build_script_tools,
        build_script_tags,
        is_proc_macro,
        has_lib,
        binaries,
        use_legacy_rules_rust_platforms,
        license_expression = "",
        license_file = None,
        extra_compile_data = [],
        rustc_env = {},
        skip_deps_verification = False,
        crate_visibility = ["//visibility:public"],
        proc_macro_labels = []):
    if allow_build_script_to_detect_nonhermetic_paths:
        fail("The selected compiler rules do not support nonhermetic build-script paths")
    crate_name = crate_name or name.replace("-", "_")
    package_metadata_name = name + "_package_metadata"
    license_attributes = []
    if license_expression or license_file:
        license_kind(
            name = name + "_license_kind",
            identifier = license_expression or "NOASSERTION",
            full_name = license_expression or "License specified in Cargo license-file",
        )
        license(
            name = name + "_license",
            kind = ":" + name + "_license_kind",
            text = license_file,
        )
        license_attributes.append(":" + name + "_license")
    package_metadata(
        name = package_metadata_name,
        purl = purl,
        attributes = license_attributes,
        visibility = ["//visibility:public"],
    )

    if deps:
        deps = set([native.package_relative_label(dep) for dep in deps])
        resolved_deps = {}
        for cargo_target_triple, configuration in configurations.items():
            resolved_deps[cargo_target_triple] = {}
            for platform_triple, labels in configuration["deps_by_triple"].items():
                selected = []
                for label in labels:
                    label = native.package_relative_label(label)
                    if label not in deps:
                        selected.append(label)
                resolved_deps[cargo_target_triple][platform_triple] = selected
        deps = list(deps)
    else:
        resolved_deps = {
            cargo_target_triple: {platform_triple: list(deps) for platform_triple, deps in configuration["deps_by_triple"].items()}
            for cargo_target_triple, configuration in configurations.items()
        }
    macro_labels = {native.package_relative_label(label): True for label in proc_macro_labels}
    macro_deps = [dep for dep in deps if native.package_relative_label(dep) in macro_labels] + cargo_select({cargo_target: {triple: [dep for dep in values if native.package_relative_label(dep) in macro_labels] for triple, values in by_triple.items()} for cargo_target, by_triple in resolved_deps.items()}, hub_name, use_legacy_rules_rust_platforms, default = [])
    resolved_deps = {cargo_target: {triple: [dep for dep in values if native.package_relative_label(dep) not in macro_labels] for triple, values in by_triple.items()} for cargo_target, by_triple in resolved_deps.items()}
    deps = [dep for dep in deps if native.package_relative_label(dep) not in macro_labels] + cargo_select(resolved_deps, hub_name, use_legacy_rules_rust_platforms, default = [])
    crate_features = cargo_select(
        {cargo_target_triple: configuration["crate_features_by_triple"] for cargo_target_triple, configuration in configurations.items()},
        hub_name,
        use_legacy_rules_rust_platforms,
        default = [],
    )
    aliases = cargo_select(
        {
            cargo_target_triple: {
                platform_triple: {
                    (dep + "__alias" if native.package_relative_label(dep) in macro_labels else dep): alias
                    for dep, alias in deps.items()
                    if alias
                }
                for platform_triple, deps in configuration["deps_by_triple"].items()
            }
            for cargo_target_triple, configuration in configurations.items()
        },
        hub_name,
        use_legacy_rules_rust_platforms,
        default = {},
    )
    target_compatible_with = cargo_select(
        {
            cargo_target_triple: {platform_triple: [] for platform_triple in configuration["crate_features_by_triple"]}
            for cargo_target_triple, configuration in configurations.items()
        },
        hub_name,
        use_legacy_rules_rust_platforms,
        default = ["@platforms//:incompatible"],
    ) if hub_name else []

    compile_data = native.glob(
        include = ["**"],
        exclude = [
            "**/* *",
            ".git",
            ".tmp_git_root/**/*",
            "BUILD",
            "BUILD.bazel",
            "REPO.bazel",
            "Cargo.toml.orig",
            "WORKSPACE",
            "WORKSPACE.bazel",
        ],
        allow_empty = True,
    ) + extra_compile_data

    srcs = native.glob(
        include = ["**/*.rs"],
        allow_empty = True,
    )

    default_tags = [
        "crate-name=" + name,
        "manual",
        "noclippy",
        "norustfmt",
    ]
    crate_tags = default_tags + tags

    if build_script:
        deps = deps + cargo_build_script_for_configurations(
            configurations = configurations,
            proc_macro_labels = proc_macro_labels,
            hub_name = hub_name,
            name = "_bs",
            use_legacy_rules_rust_platforms = use_legacy_rules_rust_platforms,
            emit_warnings = False,
            compile_data = compile_data,
            crate_name = "build_script_build",
            crate_root = build_script,
            links = links,
            data = compile_data + build_script_data,
            link_deps = deps,
            build_script_env = build_script_env,
            build_script_env_files = build_script_env_files,
            toolchains = build_script_toolchains,
            tools = build_script_tools,
            edition = edition,
            pkg_name = crate_name,
            rustc_env = rustc_env | {"CARGO_CRATE_NAME": "build_script_build"},
            rustc_env_files = ["cargo_toml_env_vars.env"],
            rustc_flags = ["--cap-lints=allow"],
            srcs = srcs,
            target_compatible_with = target_compatible_with,
            tags = crate_tags + build_script_tags,
            version = version,
        )

    rustc_flags = rustc_flags + ["--cap-lints=allow"]
    if not has_lib:
        # Keep the hub's library label incompatible for binary-only crates.
        native.filegroup(
            name = name,
            tags = crate_tags,
            target_compatible_with = ["@platforms//:incompatible"],
            visibility = crate_visibility,
        )
    else:
        kwargs = dict(
            name = name,
            cargo_target_triple_map = cargo_target_triple_map,
            crate_name = crate_name,
            version = version,
            srcs = srcs,
            compile_data = compile_data,
            aliases = aliases,
            deps = deps,
            proc_macro_deps = macro_deps,
            data = data,
            crate_features = crate_features,
            crate_root = crate_root,
            edition = edition,
            rustc_env = rustc_env,
            rustc_env_files = ["cargo_toml_env_vars.env"],
            rustc_flags = rustc_flags,
            tags = crate_tags,
            target_compatible_with = target_compatible_with,
            package_metadata = [package_metadata_name],
            visibility = crate_visibility,
        )

        if is_proc_macro:
            # rules_rust's rust_proc_macro rule has no link_deps attribute.
            # Preserve link_deps for any binaries generated by the same package.
            (_rust_proc_macro if skip_deps_verification else rust_proc_macro)(**kwargs)
        else:
            kwargs["link_deps"] = link_deps
            (_rust_library if skip_deps_verification else rust_library)(**kwargs)

    if binaries and has_lib:
        deps = [name] + deps
    for binary, crate_root in binaries.items():
        rust_binary(
            name = binary + "__bin",
            cargo_bin_name = binary,
            cargo_target_triple_map = cargo_target_triple_map,
            compile_data = compile_data,
            aliases = aliases,
            deps = deps,
            proc_macro_deps = macro_deps,
            link_deps = link_deps,
            data = data,
            crate_features = crate_features,
            crate_root = crate_root,
            edition = edition,
            rustc_env = rustc_env,
            rustc_env_files = ["cargo_toml_env_vars.env"],
            rustc_flags = rustc_flags,
            srcs = srcs,
            tags = crate_tags,
            target_compatible_with = target_compatible_with,
            version = version,
            visibility = crate_visibility,
        )

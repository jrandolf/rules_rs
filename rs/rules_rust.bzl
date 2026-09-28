"""Module extension that provisions the rules_rust repository."""

def _rules_rust_repository_impl(rctx):
    rctx.download_and_extract(
        integrity = "sha256-4rVCuxSPIKiAS0uLQ6IILyL6bYR5ypYtuKTttXi5VMg=",
        stripPrefix = "rules_rust-fd521efe16c03e4cd169453eb44fb98d73ebb7aa",
        url = "https://github.com/hermeticbuild/rules_rust/releases/download/source-fd521efe16c03e4cd169453eb44fb98d73ebb7aa/rules_rust-fd521efe16c03e4cd169453eb44fb98d73ebb7aa.tar.gz",
    )
    rctx.patch(rctx.attr._cargo_context_patch, strip = 1)
    for patch in rctx.attr.patches:
        rctx.patch(patch, strip = rctx.attr.patch_strip)

_rules_rust_repository = repository_rule(
    implementation = _rules_rust_repository_impl,
    attrs = {
        "patches": attr.label_list(),
        "patch_strip": attr.int(),
        "_cargo_context_patch": attr.label(default = "//rs/patches:rules_rust_cargo_context.patch"),
    },
)

_patch = tag_class(
    doc = "Additional patches to apply to the pinned rules_rust archive.",
    attrs = {
        "patches": attr.label_list(
            doc = "Additional patch files to apply to rules_rust.",
        ),
        "strip": attr.int(
            doc = "Equivalent to adding `-pN` when applying `patches`.",
            default = 0,
        ),
    },
)

def _rules_rust_impl(mctx):
    patches = []
    strip_values = set()

    for mod in mctx.modules:
        for tag in mod.tags.patch:
            patches.extend(tag.patches)
            strip_values.add(tag.strip)

    if len(strip_values) > 1:
        fail("Found conflicting strip values in rules_rust.patch tags")

    strip = list(strip_values)[0] if strip_values else 0

    _rules_rust_repository(
        name = "rules_rust",
        patches = patches,
        patch_strip = strip,
    )

    return mctx.extension_metadata(reproducible = True)

rules_rust = module_extension(
    implementation = _rules_rust_impl,
    tag_classes = {
        "patch": _patch,
    },
)

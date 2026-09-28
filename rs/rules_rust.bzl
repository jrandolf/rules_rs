"""Module extension that provisions the rules_rust repository."""

def _rules_rust_repository_impl(rctx):
    rctx.download_and_extract(
        sha256 = "ad47870bcd02acb76ff0d458fef5c691f061047dbae3145d5ed9eaf9ebb1915f",
        stripPrefix = "rules_rust-1c7bcfff56668ffd5f5496a1914c93ae5cf3c818",
        url = "https://codeload.github.com/jrandolf/rules_rust/tar.gz/1c7bcfff56668ffd5f5496a1914c93ae5cf3c818",
        type = "tar.gz",
    )
    for patch in rctx.attr.patches:
        rctx.patch(patch, strip = rctx.attr.patch_strip)

_rules_rust_repository = repository_rule(
    implementation = _rules_rust_repository_impl,
    attrs = {
        "patches": attr.label_list(),
        "patch_strip": attr.int(),
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

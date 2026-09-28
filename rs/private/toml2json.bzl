"""Read Cargo manifests, including TOML 1.1 multiline inline tables."""

load("@toml.bzl", "toml")

def run_toml2json(ctx, toml_file):
    return toml.decode(ctx.read(toml_file))

"""Test interfaces for Cargo resolution and source-repair integration contracts.

These aliases keep provider and helper identity with the repository implementation.
Consumers use them to verify local dependency patches against declared fixtures.
"""

load("//rs/private:cargo_workspace_graph.bzl", _cargo_toml_fact = "cargo_toml_fact", _fq_crate = "fq_crate", _locked_packages = "locked_packages", _resolve_cargo_workspace_members = "resolve_cargo_workspace_members", _resolve_packages = "resolve_packages")
load("//rs/private:cfg_parser.bzl", _cfg_matches_expr_for_triples = "cfg_matches_expr_for_triples")
load("//rs/private:repository_utils.bzl", _inherit_workspace_package_fields = "inherit_workspace_package_fields")
load("//rs/private:source_patches.bzl", _source_patch_paths = "source_patch_paths")
load("//rs/private:visibility.bzl", _visibility_with_internal_access = "visibility_with_internal_access")

visibility_with_internal_access = _visibility_with_internal_access
cargo_toml_fact = _cargo_toml_fact
fq_crate = _fq_crate
locked_packages = _locked_packages
resolve_cargo_workspace_members = _resolve_cargo_workspace_members
resolve_packages = _resolve_packages
cfg_matches_expr_for_triples = _cfg_matches_expr_for_triples
inherit_workspace_package_fields = _inherit_workspace_package_fields
source_patch_paths = _source_patch_paths

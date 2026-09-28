"""Machine-readable, unactivated workspace bindings for BUILD generators."""

load(":cargo_workspace_graph.bzl", "cfg_match_info_for_target", "fq_crate", "normalize_path")
load(":cfg_parser.bzl", "triple_to_cfg_attrs")

def workspace_index(hub, metadata, packages, facts, resolutions, execution, target_hosts, lint_configs = {}):
    root = normalize_path(metadata["workspace_root"])
    members = {normalize_path(p["manifest_path"]).removesuffix("/Cargo.toml"): p for p in metadata["packages"]}
    by_label = {"@%s//:%s" % (hub, fq_crate(p["name"], p["version"])): p for p in packages}
    names = {}
    for package in packages:
        names.setdefault(package["name"], []).append(package["version"])
    configurations = []
    for target, host in target_hosts.items():
        for domain, compilation in [("target", target), ("host", host)]:
            configurations.append({
                "key": domain + "/" + target,
                "triple": target,
                "host": host,
                "domain": domain,
                "condition": "//:__cargo/" + ("default" if domain == "target" else target) + "/" + compilation,
            })
    indexed = {}
    for package in packages:
        fq = fq_crate(package["name"], package["version"])
        label = "//:" + (package["name"] if len(names[package["name"]]) == 1 else fq)
        contexts = {}
        for target, host in target_hosts.items():
            context = {}
            if target in resolutions[fq].active:
                context["target"] = {"label": label}
            if host in execution[target].resolutions[fq].active:
                context["host"] = {"label": label}
            contexts[target] = {host: context}
        indexed[_identity(package)] = {"name": package["name"], "label": label, "contexts": contexts}
    indexed_members = {}
    for directory, member in members.items():
        edges = {}
        member_fq = fq_crate(member["name"], member["version"])
        member_macro = any(["proc-macro" in target["kind"] for target in member["targets"]])
        for configuration in configurations:
            if configuration["domain"] == "host" and configuration["host"] not in execution[configuration["triple"]].resolutions[member_fq].active:
                continue
            compilation = configuration["host"] if configuration["domain"] == "host" or member_macro else configuration["triple"]
            applicable = []
            for dep in member["dependencies"]:
                kind = dep.get("kind") or "normal"
                triple = configuration["host"] if kind == "build" else compilation
                match = cfg_match_info_for_target(dep.get("target"), [triple_to_cfg_attrs(triple)], {None: struct(matches = [triple], uses_feature_cfg = False)})
                if not match.matches:
                    continue
                path = normalize_path(dep["path"]) if dep.get("path") else None
                local = members.get(path)
                package = by_label.get(dep.get("bazel_target"))
                if local:
                    libraries = [t for t in local["targets"] if "lib" in t["kind"] or "proc-macro" in t["kind"]]
                    library = libraries[0] if libraries else {}
                    proc_macro = "proc-macro" in library.get("kind", [])
                    crate_name = library.get("name", local["name"].replace("-", "_"))
                else:
                    fact = facts[fq_crate(package["name"], package["version"])] if package else {}
                    proc_macro = fact.get("proc_macro", False)
                    crate_name = fact.get("crate_name", dep["name"].replace("-", "_"))
                applicable.append({
                    "alias": dep.get("rename") or dep["name"],
                    "crate_name": dep["rename"].replace("-", "_") if dep.get("rename") else crate_name,
                    "kind": {"normal": "dependencies", "dev": "dev-dependencies", "build": "build-dependencies"}[kind],
                    "optional": dep.get("optional", False),
                    "domain": "host" if kind == "build" or proc_macro or member_macro else configuration["domain"],
                    "proc_macro": proc_macro,
                    "package": _identity(package) if package else None,
                    "rel": ("" if path == root else path.removeprefix(root + "/")) if local else None,
                    "unsupported": ["artifact"] if dep.get("artifact") else [],
                })
            edges[configuration["key"]] = applicable
        member = "" if directory == root else directory.removeprefix(root + "/")
        indexed_members[member] = {"edges": edges, "lint_config": lint_configs.get(member)}
    return {"schema": 2, "repository": hub, "configurations": configurations, "packages": indexed, "members": indexed_members}

def _identity(package):
    return "%s %s (%s)" % (package["name"], package["version"], package.get("lock_source") or package.get("source") or "path")

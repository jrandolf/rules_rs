"""Validate source-only repairs before Bazel applies their hunks."""

def validate_source_patches(ctx, patches, patch_args):
    if patches and ctx.attr.patch_tool:
        fail("Source repairs require Bazel native patch application")
    strip = 0
    for arg in patch_args:
        if not arg.startswith("-p") or not arg[2:].isdigit():
            fail("Source repairs support only a -p strip argument")
        strip = int(arg[2:])
    for patch in patches:
        for path in source_patch_paths(ctx.read(patch), strip):
            destination = ctx.path(path)
            if not destination.exists or destination.is_dir:
                fail("Source repair must name an existing regular file: " + path)
            if str(destination.realpath) != str(ctx.path(".").realpath.get_child(path)):
                fail("Source repair cannot follow a symlink: " + path)
            if not ctx.read(destination).endswith("\n"):
                fail("Cargo patches require newline-terminated source files: " + path)

def source_patch_paths(content, strip):
    """Validate git-format text modifications and return their source paths.

    Hunk lengths distinguish removed/added header-looking source lines from
    writable file headers. Native Bazel still owns hunk matching and application.

    Args:
        content: Authored git-format unified text diff.
        strip: Number of leading patch path components to strip.

    Returns:
        Repository-relative paths touched by the patch.
    """
    if strip < 0 or not content.endswith("\n"):
        fail("Cargo patches require nonnegative patch_strip and a final newline")
    files = []
    expected = "diff"
    old = 0
    new = 0
    hunks = 0
    filename = ""
    for line in content.split("\n")[:-1]:
        if line == "\\ No newline at end of file":
            fail("Cargo patches require newline-terminated source files")
        if old or new:
            if not line or line[0] not in " +-":
                fail("Malformed Cargo patch hunk")
            old -= 1 if line[0] in " -" else 0
            new -= 1 if line[0] in " +" else 0
            if old < 0 or new < 0:
                fail("Malformed Cargo patch hunk lengths")
        elif line.startswith("diff --git "):
            if expected not in ["diff", "hunk"] or (expected == "hunk" and not hunks):
                fail("Incomplete Cargo patch file section")
            fields = line.split(" ")
            if len(fields) != 4:
                fail("Cargo patches require unquoted, whitespace-free paths")
            filename = _path(fields[2], strip)
            if _path(fields[3], strip) != filename:
                fail("Cargo patches support only same-path text modifications")
            files.append(filename)
            expected = "old"
            hunks = 0
        elif expected == "old" and line.startswith("index "):
            # Object hashes do not affect native hunk application.
            continue
        elif expected == "old" and line.startswith("--- "):
            if _path(line[4:], strip) != filename:
                fail("Cargo patch headers disagree")
            expected = "new"
        elif expected == "new" and line.startswith("+++ "):
            if _path(line[4:], strip) != filename:
                fail("Cargo patch headers disagree")
            expected = "hunk"
        elif expected == "hunk" and line.startswith("@@ "):
            fields = line.split(" ")
            if len(fields) < 4 or fields[3] != "@@":
                fail("Malformed Cargo patch hunk header")
            old = _length(fields[1], "-")
            new = _length(fields[2], "+")
            if not old and not new:
                fail("Empty Cargo patch hunk")
            hunks += 1
        else:
            fail("Unsupported Cargo patch format or operation: " + line)
    if old or new or expected != "hunk" or not hunks:
        fail("Incomplete Cargo patch")
    return files

def _path(value, strip):
    parts = value.split("/")
    if any([char <= " " or char == json.decode('"\\u007f"') or char in "\\:\"'" for char in value.elems()]) or any([part in ["", ".", ".."] for part in parts]) or len(parts) <= strip:
        fail("Unsafe or ambiguous Cargo patch path: " + value)
    relative = "/".join(parts[strip:])
    if any([part.lower() == ".git" for part in parts[strip:]]):
        fail("Cargo patches must not change Git metadata")
    if parts[-1].lower() in ["cargo.toml", "cargo.lock", ".gitmodules"]:
        fail("Cargo patches must not change Cargo.toml, Cargo.lock or .gitmodules")
    return relative

def _length(value, sign):
    fields = value[1:].split(",")
    if not value.startswith(sign) or len(fields) not in [1, 2] or any([not field or any([char not in "0123456789" for char in field.elems()]) for field in fields]):
        fail("Malformed Cargo patch hunk range: " + value)
    return int(fields[1]) if len(fields) == 2 else 1

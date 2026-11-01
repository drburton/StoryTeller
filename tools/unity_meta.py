#!/usr/bin/env python3
"""Writes the .meta files Unity needs for the package in unity/.

Unity reads a package added from a Git URL as read only and ignores any file
without a .meta file, so every file and folder in the package needs one in
the repository. Each GUID comes from the file's path, so running this again
gives the same files.

    python3 tools/unity_meta.py          write missing .meta files
    python3 tools/unity_meta.py --check  list missing or extra ones, exit 1 if any
"""
import hashlib
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "unity")
PACKAGES = ["com.visualnovelteller.unity"]

FOOTER = "  userData: \n  assetBundleName: \n  assetBundleVariant: \n"


def importer(path):
    if os.path.isdir(path):
        return "folderAsset: yes\nDefaultImporter:\n  externalObjects: {}\n" + FOOTER
    ext = os.path.splitext(path)[1].lower()
    if ext == ".cs":
        return ("MonoImporter:\n  externalObjects: {}\n  serializedVersion: 2\n  defaultReferences: []\n"
                "  executionOrder: 0\n  icon: {instanceID: 0}\n" + FOOTER)
    if ext == ".asmdef":
        return "AssemblyDefinitionImporter:\n  externalObjects: {}\n" + FOOTER
    if ext in (".uxml",):
        return ("ScriptedImporter:\n  internalIDToNameTable: []\n  externalObjects: {}\n  serializedVersion: 2\n"
                + FOOTER + "  script: {fileID: 13804, guid: 0000000000000000e000000000000000, type: 0}\n")
    if ext in (".uss",):
        return ("ScriptedImporter:\n  internalIDToNameTable: []\n  externalObjects: {}\n  serializedVersion: 2\n"
                + FOOTER + "  script: {fileID: 12385, guid: 0000000000000000e000000000000000, type: 0}\n"
                "  disableValidation: 0\n")
    if ext in (".md", ".json", ".txt"):
        return "TextScriptImporter:\n  externalObjects: {}\n" + FOOTER
    return "DefaultImporter:\n  externalObjects: {}\n" + FOOTER


def wanted(package):
    """Every path in the package that needs a .meta file, relative to unity/."""
    base = os.path.join(ROOT, package)
    for folder, dirs, files in os.walk(base):
        dirs[:] = sorted(d for d in dirs if not d.startswith(".") and not d.endswith("~"))
        rel_folder = os.path.relpath(folder, ROOT)
        if folder != base:
            yield rel_folder
        for name in sorted(files):
            if name.startswith(".") or name.endswith(".meta") or name.endswith("~"):
                continue
            yield os.path.join(rel_folder, name)


def meta_text(rel):
    guid = hashlib.md5(("visualnovelteller:" + rel.replace(os.sep, "/")).encode()).hexdigest()
    return "fileFormatVersion: 2\nguid: %s\n%s" % (guid, importer(os.path.join(ROOT, rel)))


def main():
    check = "--check" in sys.argv
    problems = []
    for package in PACKAGES:
        paths = set(wanted(package))
        for rel in sorted(paths):
            meta = os.path.join(ROOT, rel + ".meta")
            if not os.path.exists(meta):
                if check:
                    problems.append("missing: unity/%s.meta" % rel)
                else:
                    with open(meta, "w", newline="\n") as f:
                        f.write(meta_text(rel))
        for folder, dirs, files in os.walk(os.path.join(ROOT, package)):
            for name in files:
                if name.endswith(".meta"):
                    rel = os.path.relpath(os.path.join(folder, name[:-5]), ROOT)
                    if rel not in paths:
                        problems.append("extra: unity/%s.meta" % rel)
    for problem in problems:
        print(problem)
    if check and problems:
        print("Run python3 tools/unity_meta.py to add the missing ones, and delete the extra ones.")
        return 1
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

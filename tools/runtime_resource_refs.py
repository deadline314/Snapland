"""Literal resource dependencies shared by the isolated character audit stages.

Match the entire supported extension: raw PNG data is not an imported PNG, and
an unsupported suffix must never be truncated into a different resource path.
"""
import re

_REFERENCE = re.compile(r'''res://([^"'\s]+\.(?:gd|json|pngdata|png))(?=["'\s])''')


def referenced_resources(source: str) -> set[str]:
    return set(_REFERENCE.findall(source))

#!/usr/bin/env python3
"""
Quick lookup for Raspberry Pi server OS info.

This script loads server metadata from a JSON file and provides helpers to
quickly look up a host's OS details by hostname. It can also be used as a
command-line tool.

Example:
    List all hostnames:

        $ python server_lookup.py

    Look up a specific host:

        $ python server_lookup.py --host SPINAL-TAP.lan

Attributes:
    DEFAULT_JSON (Path): Default path to `server-informations.json` located
        next to this script.
"""

from __future__ import annotations
import argparse
import json
from pathlib import Path
from typing import Dict, List

DEFAULT_JSON = Path(__file__).with_name("server-informations.json")


def load_index(json_path: Path | str = DEFAULT_JSON) -> Dict[str, dict]:
    """Load the JSON list and return a dict keyed by hostname (lowercased).

    Args:
        json_path (Path | str, optional): Path to the JSON file containing
            server information. Defaults to `DEFAULT_JSON`.

    Returns:
        Dict[str, dict]: A dictionary where each key is a lowercase hostname,
        and each value is the corresponding server metadata dictionary.

    Raises:
        FileNotFoundError: If the JSON file does not exist.
        ValueError: If the JSON content is not a list of dictionaries.
    """
    p = Path(json_path)
    if not p.exists():
        raise FileNotFoundError(f"JSON file not found: {p}")

    with p.open("r", encoding="utf-8") as f:
        data: List[dict] = json.load(f)

    if not isinstance(data, list):
        raise ValueError("Expected a list of server objects in the JSON.")

    index: Dict[str, dict] = {}
    for row in data:
        hostname = row.get("hostname")
        if not hostname:
            # Skip rows without a hostname
            continue
        key = hostname.lower()
        # Last one wins if duplicates—customize if you prefer to error out
        index[key] = row
    return index


def lookup(index: Dict[str, dict], hostname: str) -> dict:
    """Return the server info for a hostname (case-insensitive).

    Args:
        index (Dict[str, dict]): The dictionary returned by `load_index`.
        hostname (str): The hostname to look up.

    Returns:
        dict: The server metadata for the given hostname.

    Raises:
        KeyError: If the hostname is not found in the index.
    """
    key = hostname.lower()
    if key not in index:
        raise KeyError(f"Hostname not found: {hostname}")
    return index[key]


def main() -> None:
    """Command-line interface for looking up server info.

    Parses command-line arguments, loads the JSON file, and either lists all
    available hostnames or prints the details for a specified hostname.

    Args:
        None

    Returns:
        None

    Raises:
        SystemExit: If the hostname is not found.
    """
    ap = argparse.ArgumentParser(description="Lookup server info by hostname.")
    ap.add_argument(
        "--json",
        type=Path,
        default=DEFAULT_JSON,
        help=f"Path to server-informations.json (default: {DEFAULT_JSON.name})",  # noqa: E501
    )
    ap.add_argument(
        "--host",
        help="Hostname to look up (e.g., SPINAL-TAP.lan). If omitted, prints all hostnames.",  # noqa: E501
    )
    args = ap.parse_args()

    index = load_index(args.json)

    if not args.host:
        # Print all known hostnames to help discover what's available
        for name in sorted(index):
            print(index[name]["hostname"])
        return

    try:
        info = lookup(index, args.host)
    except KeyError as e:
        print(str(e))
        raise SystemExit(1)

    # Pretty-print the server info JSON for the requested host
    print(json.dumps(info, indent=2))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Terraform `external` data source adapter for build_layer.py.

Builds the layer ZIP while Terraform *plans* (data sources are read during
plan), so the ZIP exists whenever `aws_lambda_layer_version` needs it - also
on ephemeral CI agents where plan and apply run in separate jobs and only the
terraform folder (including .layer-build/) is handed over.

Unlike a `null_resource` with a `timestamp()` trigger, a data source never
shows up as a change in the plan.

Protocol (https://registry.terraform.io/providers/hashicorp/external):
  stdin  - JSON object of strings (the data source `query`)
  stdout - JSON object of strings (exposed as `result`)
  stderr - shown by Terraform only when the program fails

Query keys:
  output                 absolute ZIP path
  source_dir             absolute intermediate layer source folder
  inputs_hash            module-computed hash of all build inputs
  args                   JSON list of build_layer.py arguments
  pip_requirements_json  passed through as PIP_REQUIREMENTS_JSON
  inline_files_json      passed through as INLINE_FILES_JSON
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_layer  # noqa: E402


def _build(query: dict[str, str], output: Path) -> None:
    os.environ["PIP_REQUIREMENTS_JSON"] = query.get("pip_requirements_json", "")
    os.environ["INLINE_FILES_JSON"] = query.get("inline_files_json", "")
    # build_layer.py's own fingerprint ignores the acai library sources; drop it
    # so a changed inputs_hash always produces a fresh ZIP.
    Path(f"{output}.fingerprint").unlink(missing_ok=True)
    sys.argv = [
        "build_layer.py",
        *json.loads(query["args"]),
        "--source-dir",
        query["source_dir"],
        "--output",
        str(output),
    ]
    build_layer.main()


def main() -> None:
    query = json.load(sys.stdin)
    output = Path(query["output"])
    inputs_hash = query["inputs_hash"]
    stamp = Path(f"{output}.inputs")

    up_to_date = (
        output.exists()
        and stamp.exists()
        and stamp.read_text(encoding="utf-8").strip() == inputs_hash
    )

    if not up_to_date:
        # stdout is reserved for the JSON result: send everything the build
        # prints (including the pip subprocess, hence fd level) to stderr.
        sys.stdout.flush()
        saved_stdout = os.dup(1)
        os.dup2(2, 1)
        try:
            _build(query, output)
        finally:
            sys.stdout.flush()
            os.dup2(saved_stdout, 1)
            os.close(saved_stdout)
        stamp.write_text(inputs_hash, encoding="utf-8")

    json.dump({"filename": str(output), "inputs_hash": inputs_hash}, sys.stdout)


if __name__ == "__main__":
    main()

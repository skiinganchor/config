"""Reconcile private recurring jobs through the pinned Hermes cron API."""

import contextlib
import io
import json
import logging
import re
import sys


MARKER = "nixos_managed_cron_id"


def reconcile(path):
    from cron import jobs
    from cron.lifecycle_guard import check_gateway_lifecycle

    with open(path, encoding="utf-8") as source:
        declarations = json.load(source)
    if not isinstance(declarations, list):
        raise ValueError("Expected a list")

    # Validate the entire input before changing any stored jobs.
    desired = {}
    for declaration in declarations:
        fields = {"id", "name", "schedule", "deliver", "prompt"}
        if not isinstance(declaration, dict) or set(declaration) != fields:
            raise ValueError("Invalid fields")
        if any(not isinstance(value, str) or not value.strip()
               for value in declaration.values()):
            raise ValueError("Expected nonempty strings")
        key = declaration["id"]
        if key in desired:
            raise ValueError("Duplicate id")
        if not re.fullmatch(r"matrix:![^\s,:]+:[^\s,]+", declaration["deliver"]):
            raise ValueError("Expected an explicit Matrix room ID")
        schedule = jobs.parse_schedule(declaration["schedule"])
        if schedule["kind"] not in {"cron", "interval"}:
            raise ValueError("Only recurring schedules are supported")
        if jobs.compute_next_run(schedule) is None:
            raise ValueError("Schedule has no next run")
        check_gateway_lifecycle(declaration["prompt"], None)
        desired[key] = (declaration, schedule)

    existing = {}
    for job in jobs.list_jobs(include_disabled=True):
        if MARKER in job:
            key = job[MARKER]
            if key in existing:
                raise ValueError("Duplicate managed job")
            existing[key] = job

    for key, (declaration, schedule) in desired.items():
        job = existing.get(key)
        if job is None:
            job = jobs.create_job(**{
                field: declaration[field]
                for field in ("name", "schedule", "deliver", "prompt")
            })
            jobs.update_job(job["id"], {MARKER: key})
            continue
        updates = {
            field: declaration[field]
            for field in ("name", "deliver", "prompt")
            if job.get(field) != declaration[field]
        }
        # Unchanged schedules retain next_run_at, so restarts cannot postpone
        # interval jobs or erase a missed occurrence.
        if job["schedule"] != schedule:
            updates["schedule"] = schedule
        if updates:
            jobs.update_job(job["id"], updates)

    for key, job in existing.items():
        if key not in desired:
            jobs.remove_job(job["id"])


def main():
    # Hermes diagnostics and exception messages can contain private fields.
    # Keep them out of the system journal, including import-time output.
    logging.disable(logging.CRITICAL)
    try:
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            reconcile(sys.argv[1])
    except Exception:
        print("Hermes cron reconciliation failed; check the private job file and Hermes state.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Apply encrypted cron definitions without replacing Hermes's runtime store."""

import hashlib
import json
import re


MARKER = "nixos_managed_cron_id"


def read_declarations(source):
    from cron import jobs
    from cron.job_definition import JOB_DEFINITION_FIELDS
    from cron.lifecycle_guard import check_gateway_lifecycle

    value = json.loads(source.read_bytes())
    legacy = isinstance(value, list)
    declarations = value if legacy else value["jobs"]
    if not isinstance(declarations, list):
        raise ValueError("Expected a cron jobs list")
    desired = {}
    for declaration in declarations:
        fields = JOB_DEFINITION_FIELDS | {"id", "enabled", "repeat"}
        if legacy:
            fields = {"id", "name", "schedule", "deliver", "prompt", "skills", "enabled"}
        key = declaration["id"]
        if (not isinstance(key, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", key)
                or key in desired or declaration.keys() - fields):
            raise ValueError("Invalid or duplicate cron definition")
        if "enabled" in declaration and not isinstance(declaration["enabled"], bool):
            raise ValueError("Expected enabled to be a boolean")
        authored = {name: value for name, value in declaration.items() if name not in {"id", "enabled"}}
        if legacy:
            if any(not isinstance(authored.get(name), str) or not authored[name].strip()
                   for name in ("name", "prompt", "schedule", "deliver")):
                raise ValueError("Invalid legacy cron job")
            if not re.fullmatch(r"matrix:![^\s,:]+:[^\s,]+", authored["deliver"]):
                raise ValueError("Expected an explicit Matrix room")
            authored.setdefault("skills", [])
        schedule = authored["schedule"]
        if isinstance(schedule, str):
            schedule = jobs.parse_schedule(schedule)
        if schedule["kind"] not in {"cron", "interval"}:
            raise ValueError("Only recurring managed jobs are supported")
        authored["schedule"] = schedule
        authored.setdefault("schedule_display", schedule.get("display"))
        authored.setdefault("deliver", "local")
        if "skills" in authored:
            skills = authored["skills"]
            if (not isinstance(skills, list) or any(not isinstance(skill, str) or not skill.strip() for skill in skills)
                    or len(skills) != len(set(skills))):
                raise ValueError("Expected unique skill names")
            authored.setdefault("skill", skills[0] if skills else None)
        check_gateway_lifecycle(authored.get("prompt"), authored.get("script"))
        desired[key] = (authored, declaration.get("enabled"))
    return legacy, desired


def merge_job(local, authored, enabled, legacy):
    from cron import jobs
    from cron.job_definition import JOB_DEFINITION_FIELDS, merge_job_definition
    from hermes_time import now

    if legacy:
        # The old input had no model pins, script settings, or repeat cap. Those
        # fields could be edited interactively and belong to the existing job.
        authored = {key: value for key, value in local.items() if key in JOB_DEFINITION_FIELDS or key == "repeat"} | authored
    previous_schedule = local.get("schedule")
    if isinstance(previous_schedule, dict) and (
        {key: value for key, value in previous_schedule.items() if key != "display"}
        == {key: value for key, value in authored["schedule"].items() if key != "display"}
    ):
        # Display spelling can change across releases without moving any slots.
        authored = {**authored, "schedule": previous_schedule}
    result = merge_job_definition(local, authored)
    jobs.validate_schedule_knobs(result["schedule"], result.get("timezone"), result.get("grace_minutes"))
    jobs._validate_job_mode_invariants(result.get("monitor_script"), result.get("monitor_url"),
                                      result.get("no_agent"), result.get("script"))
    next_run = jobs.compute_next_run(result["schedule"], timezone=result.get("timezone"))
    if next_run is None:
        raise ValueError("Cron schedule has no next run")
    if enabled is False and (result.get("enabled", True) or result.get("state") != "paused"):
        result.update(enabled=False, state="paused", paused_at=now().isoformat(), paused_reason=None)
        result.pop("pending_slot", None)
    elif enabled is True and (not result.get("enabled", True) or result.get("state") == "paused" or result.get("paused_at")):
        due = jobs._parse_aware(result["next_run_at"]) if result.get("next_run_at") else None
        if due is not None and jobs._instant_at_or_before(due, now()):
            next_run = result["next_run_at"]
        result.update(enabled=True, state="scheduled", paused_at=None, paused_reason=None, next_run_at=next_run)
        result.pop("pending_slot", None)
    if result.get("enabled", True) and result.get("state") != "paused" and not result.get("next_run_at"):
        result["next_run_at"] = next_run
    return result


def reconcile(declarations):
    from cron import jobs
    from hermes_time import now

    legacy, pending = declarations
    pending = pending.copy()
    with jobs._jobs_lock():
        existing = jobs.load_jobs()
        used_ids = {job["id"] for job in existing}
        seen_keys = set()
        updated = []
        removed = []
        for job in existing:
            key = job.get(MARKER)
            if key is None:
                updated.append(job)
                continue
            if key in seen_keys:
                raise ValueError("Duplicate managed job")
            seen_keys.add(key)
            if key in pending:
                authored, enabled = pending.pop(key)
                updated.append(merge_job(job, authored, enabled, legacy))
            else:
                removed.append(job["id"])
        for key, (authored, enabled) in pending.items():
            job_id = hashlib.sha256(key.encode()).hexdigest()[:12] if legacy else key
            if job_id in used_ids:
                raise ValueError("Managed job ID already in use")
            used_ids.add(job_id)
            seed = {"id": job_id, MARKER: key, "created_at": now().isoformat(), "enabled": True, "state": "scheduled"}
            updated.append(merge_job(seed, authored, enabled, legacy))
        if updated != existing:
            jobs.save_jobs(updated, removed_ids=removed)

## Issue #7257
**GitLab runner VMs: graceful drain + fleet-aware delete + `--recreate` (drained recreation as the lifecycle path)**

Labels: type/feature, triaged, priority/medium, feature, component/runner

## Summary

Make **drained recreation** the promoted lifecycle path for GitLab runner VMs. Today `delete-*-vm.sh` hard-kills the VM (`oc delete vm --wait=false` / `gcloud compute instances delete`) with no drain, so any job running on that VM is cut off; and recreating requires a two-command dance (`delete-*-vm.sh` then `create-*-vm.sh`) with two *different* credentials. This issue adds a graceful drain, makes delete fleet-aware, and adds `--recreate` to the create scripts so recreation is a single, credential-consistent, job-safe command.

## Background / why

Both runner fleets use the GitLab **Runner Manager** model: a single permanent runner entry (gitlab.com `56125242`, gitlab.cee `68746`, both `fullsend-shared-runner`, tag `fullsend-gitlab-runner`) backed by a pool of VMs sharing one authentication token, distinguished by `system_id`. Recreating a VM is therefore **invisible at the fleet level** (stable runner ID, other VMs keep serving) — *except* that deleting a VM kills whatever job is running on it at that instant. Recreation is the natural compliance/update path (clean disk; for GCP a fresh VM is born SA-less once #7254 lands), so it should be graceful.

Measured on both fleets (runner-01, 2026-09-12): `KillSignal=SIGTERM`, systemd `TimeoutStopUSec=45s` with `TimeoutStopFailureMode=abort` (Fedora `10-timeout-abort.conf` — overrun ⇒ SIGABRT + coredump), unit `Restart=always`/`RestartSec=120`, config `shutdown_timeout = 0` (⇒ runner default ~30s), gitlab-runner 19.2.1. So there is effectively **no usable drain today**: a `systemctl stop` cuts jobs at ~30–45s and can crash the runner. The implementation must not naively rely on `systemctl stop`.

## Scope

### 1. `hack/gitlab-runner-vm/lib.sh`: `drain_runner_vm` helper (+ `lib_test.sh` tests)
- Gracefully stop the runner on a target VM so it **stops accepting new jobs and lets in-flight jobs finish**, bounded by a cap (default **10 min**).
- Policy: **drain-then-proceed** — on cap overrun, warn and continue (do not hang forever).
- Runs from the operator side over the scripts' existing SSH plumbing (`virtctl … ssh` for OpenShift, `gcloud compute ssh --tunnel-through-iap` for GCP); detect idle by watching for per-job `runner-*` containers (`podman ps`) draining, not just process exit.
- Caveats to handle (discovered above): use the graceful signal (SIGQUIT) rather than a bare `systemctl stop` that trips the 45s abort; account for `Restart=always`; `shutdown_timeout=0` means the runner's own wait is only ~30s. (For drain-before-delete the `Restart=always` restart is moot since the VM is torn down next.)

### 2. `delete-gcp-vm.sh` + `delete-openshift-vm.sh`: fleet-aware, and drain before delete
- **Fleet-awareness (both conditions):** skip the runner deregistration step when **either** `RUNNER_TOKEN` is set **or** no runner matching the `proj/vm` description is found; and **only require `GL_TOKEN` when a deregistration will actually occur**. In the fleet model the shared runner (`fullsend-shared-runner`) never matches `proj/vm`, so deregistration is a guaranteed no-op and the PAT should not be required to delete a fleet VM (GitLab prunes the offline `system_id`).
- **Drain before delete:** call `drain_runner_vm` prior to the VM/instance deletion; add a `--no-drain` escape hatch (and honor the cap → proceed).

### 3. `create-gcp-vm.sh` + `create-openshift-vm.sh`: `--recreate` flag
- When the target VM already exists (currently a hard error, e.g. create-gcp-vm.sh:335), `--recreate` performs **drain → delete → create** in one command, reusing the create script's own environment (in fleet/`RUNNER_TOKEN` mode this needs **no extra credential**, because delete no longer requires `GL_TOKEN` — see §2).
- Without `--recreate`, keep the current refuse-on-existing behavior.

### 4. Header/usage comments (this issue's scripts)
- Update the top-of-file usage comments in `create-*-vm.sh` and `delete-*-vm.sh` to describe what each can do and how (fleet vs individual mode, `--recreate`, `--no-drain`, the drain cap, which credentials are required in which mode).

## Acceptance criteria
- [ ] `drain_runner_vm` exists in `lib.sh`, unit-tested in `lib_test.sh`; graceful, bounded (10-min default), drain-then-proceed.
- [ ] Deleting a fleet VM (RUNNER_TOKEN mode or no `proj/vm` match) succeeds **without** `GL_TOKEN`, and does not touch the shared fleet runner.
- [ ] `delete-*-vm.sh` drains the VM before deletion; `--no-drain` skips it.
- [ ] `create-*-vm.sh --recreate` drains, deletes, and recreates an existing VM using only create's env in fleet mode; absent the flag, existing behavior (refuse) is unchanged.
- [ ] Recreating a fleet VM leaves the shared runner ID stable and does not cut a job that finishes within the drain cap.
- [ ] Usage comments in create-*/delete-* describe capabilities, flags, modes, and required credentials.

## Out of scope
- runner-hub README updates (handled separately, in those repos).
- setup.sh idempotency/hygiene (tracked in the companion issue).
- GCP VM service-account removal (#7254).
- Concurrency / per-slot gateways (still out of scope; single job per VM assumed).

Companion issue: setup.sh idempotency + hygiene. Related: #7218 (ephemeral per-job gateway, merged), #7254 (GCP VM SA removal).



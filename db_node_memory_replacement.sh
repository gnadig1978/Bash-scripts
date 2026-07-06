#!/bin/bash
#
# DB Node Memory Replacement
# Version 2.0 (rewritten from Gurudatta N.R's v1.0)
#
# Adds: logging, error handling, CRS/GI shutdown step, timeout on VM
# shutdown wait loop, and pre-flight checks before the final power-off.
#
# Usage: sudo ./db_node_memory_replacement.sh
#
# NOTE: Review and adjust VM_LIST, GI_HOME/GI_OWNER, and timeouts for
# your environment before running against production hardware.

set -uo pipefail   # NOT -e: we want to control failure handling per-step,
                   # since some ipmitool calls may return nonzero on
                   # transient/benign conditions.

### ---------- Configuration ----------
VM_LIST=("dbvm1" "dbvm2")
VM_SHUTDOWN_TIMEOUT=600      # seconds to wait for graceful VM shutdown
VM_POLL_INTERVAL=30          # seconds between checks

GI_OWNER="grid"              # OS user that owns Grid Infrastructure
GI_HOME="/u01/app/19.0.0.0/grid"   # adjust to your GI_HOME

LOG_DIR="/var/log/mem_replace"
LOG_FILE="${LOG_DIR}/mem_replace_$(date +%Y%m%d_%H%M%S).log"

### ---------- Logging setup ----------
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== DB Node Memory Replacement started at $(date) ==="
echo "Logging to: $LOG_FILE"

### ---------- Helper ----------
fail() {
    echo "FATAL: $1"
    echo "=== Aborting procedure at $(date) ==="
    exit 1
}

run_step() {
    local desc="$1"; shift
    echo "----- ${desc} -----"
    "$@"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "WARNING: '${desc}' exited with code ${rc}."
        read -r -p "Continue anyway? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || fail "User aborted after failed step: ${desc}"
    fi
    return 0
}

### ---------- Step 1: Diagnostics via Sun OEM CLI ----------
echo "Step 1: Running diagnostics via Sun OEM CLI..."
run_step "hwdiag mem spd" \
    ipmitool sunoem cli "start /SP/diag/shell y; hwdiag mem spd all"

### ---------- Step 2: Fault management shell ----------
echo "Step 2: Checking fault management shell..."
run_step "fmadm list" \
    ipmitool sunoem cli "start /SP/faultmgmt/shell y; fmadm list"

### ---------- Step 3: Set SYS LOCATE LED to Fast Blink ----------
echo "Step 3: Setting SYS LOCATE LED to Fast_Blink..."
run_step "Set LOCATE LED" \
    ipmitool sunoem cli "set /SYS/LOCATE value=Fast_Blink"
echo "NOTE: Remember to set LOCATE LED back to Off after the physical memory swap is complete."

### ---------- Step 4: Exadata DB KVM health check ----------
echo "Step 4: Running Exadata DB KVM health check..."
if [[ ! -x ./exadata_DB_KVM_health_check.sh ]]; then
    fail "exadata_DB_KVM_health_check.sh not found or not executable in current directory."
fi
./exadata_DB_KVM_health_check.sh
if [[ $? -ne 0 ]]; then
    fail "Exadata DB KVM health check failed. Resolve issues before proceeding with shutdown."
fi
echo "Health check passed."

### ---------- Step 5: Stop Grid Infrastructure / CRS ----------
echo "Step 5: Stopping Grid Infrastructure (CRS) stack..."
if [[ -x "${GI_HOME}/bin/crsctl" ]]; then
    su - "$GI_OWNER" -c "${GI_HOME}/bin/crsctl stop crs"
    rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "WARNING: 'crsctl stop crs' returned ${rc}. Checking cluster status..."
        su - "$GI_OWNER" -c "${GI_HOME}/bin/crsctl check crs" || true
        read -r -p "CRS may not have stopped cleanly. Continue anyway? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || fail "Aborting: CRS did not stop cleanly."
    else
        echo "CRS stopped successfully."
    fi
else
    echo "WARNING: crsctl not found at ${GI_HOME}/bin/crsctl — skipping CRS stop."
    read -r -p "Continue without confirming CRS is stopped? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || fail "Aborting: could not confirm CRS/GI stack state."
fi

### ---------- Step 6: Shut down VMs gracefully ----------
echo "Step 6: Shutting down VMs..."
for vm in "${VM_LIST[@]}"; do
    echo "Sending shutdown to $vm..."
    virsh shutdown "$vm" || echo "WARNING: 'virsh shutdown $vm' returned non-zero; will still monitor state."
done

echo "Waiting for VMs to power off (timeout: ${VM_SHUTDOWN_TIMEOUT}s)..."
elapsed=0
while true; do
    running_vms=$(virsh list --state-running --name 2>/dev/null)
    if [[ -z "$running_vms" ]]; then
        echo "All VMs are powered off."
        break
    fi

    if (( elapsed >= VM_SHUTDOWN_TIMEOUT )); then
        echo "WARNING: Timeout reached. Still running: ${running_vms}"
        read -r -p "Force-stop remaining VMs with 'virsh destroy'? [y/N] " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            for vm in $running_vms; do
                echo "Force-stopping $vm..."
                virsh destroy "$vm"
            done
        else
            fail "Aborting: VMs still running and not force-stopped: ${running_vms}"
        fi
        break
    fi

    echo "Still running: ${running_vms} (elapsed: ${elapsed}s)"
    sleep "$VM_POLL_INTERVAL"
    (( elapsed += VM_POLL_INTERVAL ))
done

### ---------- Step 7: Final confirmation before power-off ----------
echo "Step 7: Pre-shutdown confirmation."
echo "About to power off this DB node for memory replacement."
read -r -p "Proceed with 'shutdown -hP now'? [y/N] " final_confirm
if [[ ! "$final_confirm" =~ ^[Yy]$ ]]; then
    fail "Aborting: user declined final shutdown confirmation."
fi

echo "Step 7: Shutting down DB node..."
shutdown -hP now

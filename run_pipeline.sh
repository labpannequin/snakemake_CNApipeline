#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 1. Configuration and Logs
# -----------------------------------------------------------------------------
RUNSTAMP=$(date +"%Y-%m-%d_%H-%M")
WORKDIR="${PWD}"
LOGDIR="${WORKDIR}/logs/${RUNSTAMP}"
mkdir -p "$LOGDIR"

MASTER_LOG="${LOGDIR}/snakemake_full.log"
SUMMARY_LOG="${LOGDIR}/summary.log"

# Captures all arguments passed to the script (ex: "barcode65 barcode66")
INPUT_ARGS="$@"

# Replaces all spaces with ',' for Snakemake (ex: "barcode65,barcode66")
SAMPLES_LIST=$(echo "$INPUT_ARGS" | tr ' ' ',')

echo "=== Starting Snakemake run at $(date) on $(hostname) ==="
echo "Logs directory: ${LOGDIR}"

# -----------------------------------------------------------------------------
# 2. Colors
# -----------------------------------------------------------------------------
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[1;34m"
BOLD="\033[1m"
RESET="\033[0m"

# -----------------------------------------------------------------------------
# 3. Modules
# -----------------------------------------------------------------------------
# Adjust according to working environment, this is a working example on a cluster
module load bioinfo/Snakemake || {
    echo -e "${RED}ERROR:${RESET} Could not load Snakemake module."
    exit 1
}
module load /tools/modulefiles/containers/Apptainer/1.4.1

# -----------------------------------------------------------------------------
# 4. Profile Detection for Snakemake 
# -----------------------------------------------------------------------------
PROFILE_PATH=$(python3 - <<'EOF'
import os
xdg_home = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
candidate = os.path.join(xdg_home, "snakemake", "profiles", "default")
print(candidate if os.path.exists(candidate) else "")
EOF
)

if [[ -z "$PROFILE_PATH" ]]; then
    echo -e "${RED}ERROR:${RESET} No default Snakemake profile found."
    exit 1
fi
echo -e "${GREEN}Using profile:${RESET} $PROFILE_PATH"

# -----------------------------------------------------------------------------
# 5. Spinner Function
# -----------------------------------------------------------------------------
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c] Snakemake is running..." "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    printf "                               \r"
}

# -----------------------------------------------------------------------------
# 6. Snakemake Execution
# -----------------------------------------------------------------------------

# Uncomment to unlock locked directory :
# snakemake --unlock

# Unlock 
# snakemake --rerun-incomplete

# If you uncomment one of the lines above, make sure to comment the following section:
if [[ -n "$SAMPLES_LIST" ]]; then
    # CASE 1 : Certain samples are specified in command line
    echo -e "${YELLOW}Running pipeline for specific samples: ${BOLD}$SAMPLES_LIST${RESET}"
    snakemake \
        --profile "$PROFILE_PATH" \
        --use-apptainer \
        --jobs 10 \
        -s Snakefile \
        --config target_samples="$SAMPLES_LIST" logdir="$LOGDIR" \
        >"${MASTER_LOG}" 2>&1 &
        
    SNAKEMAKE_PID=$!
else
    # CASE 2 : No arguments -> Run all samples
    echo -e "${BLUE}Running pipeline for ALL samples found in config.yaml${RESET}"
    
    snakemake \
        --profile "$PROFILE_PATH" \
        --use-apptainer \
        --jobs 10 \
        -s Snakefile \
        --config logdir="$LOGDIR" \
        >"${MASTER_LOG}" 2>&1 &
        
    SNAKEMAKE_PID=$!
fi


# Lancement du spinner
spinner $SNAKEMAKE_PID
wait $SNAKEMAKE_PID
EXITCODE=$?

# -----------------------------------------------------------------------------
# 7. End of run Summary
# -----------------------------------------------------------------------------
if [[ $EXITCODE -eq 0 ]]; then
    echo -e "\n${GREEN} Snakemake completed successfully!${RESET}"
else
    echo -e "\n${RED} Snakemake failed (exit code $EXITCODE).${RESET}"
fi

echo -e "\n${BOLD}Summary of jobs:${RESET}"
grep -E "Finished job|Error|complete" "$MASTER_LOG" | tail -n 10 > "$SUMMARY_LOG"
cat "$SUMMARY_LOG"

echo -e "\nFull log available at: ${BLUE}${MASTER_LOG}${RESET}"

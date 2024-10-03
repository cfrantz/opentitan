#!/bin/bash
# A simple shell script to demonstrate ownership transfer.
# Run this script in the root of an OpenTitan git tree.

set -eou pipefail

function usage {
  local -r name=$(basename $0)
  echo "${name}: Demonstrate ownership transfer."
  echo
  echo "Options:"
  echo "    --sku NAME: Use HSM configuration for the named sku."
  echo "    --interface NAME: Use the named opentitantool interface."
  echo "    --config FILENAME: Read the owner configuration from filename."
  echo "    --owner_key NAME: Use the named private key to sign the owner config."
  echo "    --activate_key NAME: Use the named private key to sign the activate command."
  echo "    --unlock_key NAME: Use the named private key to sign the unlock command."
  echo "    --nocleanup: Do not clean up the temporary working directory."
  echo "    -v, --verbose: Enable excessive output from tools."
  echo "    -h, --help: This message"
  echo
  echo "Note:"
  echo "    Make sure you've set up your gcloud credentials to access CloudKMS:"
  echo "    gcloud auth login"
  echo "    gcloud config set project otkms-407107"
  echo "    gcloud auth application-default login"
}

# Some colors to make terminal output nice.
red=$(echo -e "\033[31m")
green=$(echo -e "\033[32m")
yellow=$(echo -e "\033[33m")
blue=$(echo -e "\033[34m")
magenta=$(echo -e "\033[35m")
cyan=$(echo -e "\033[36m")
white=$(echo -e "\033[37m")
reset=$(echo -e "\033[0m")

# Cloud KMS configs for the current possible owners.
declare -A KMS_CONFIGS=(
  [sival]="signing/tokens/earlgrey_z1_sival.yaml"
  [prodc]="signing/tokens/earlgrey_z1_prodc.yaml"
  [proda]="signing/tokens/earlgrey_z1_proda.yaml"
  [fake]=""
)

# Cloud KMS HSM token names for current possible owners.
declare -A TOKENS=(
  [sival]="ot-earlgrey-z0-sival"
  [prodc]="ot-earlgrey-z1-prodc"
  [proda]="ot-earlgrey-z1-proda"
  [fake]=""
)

# Nicknames to paths for the fake test owner keys.
declare -A FAKE=(
  [activate]="sw/device/silicon_creator/lib/ownership/keys/fake/activate_ecdsa_p256.der"
  [owner]="sw/device/silicon_creator/lib/ownership/keys/fake/owner_ecdsa_p256.der"
  [unlock]="sw/device/silicon_creator/lib/ownership/keys/fake/unlock_ecdsa_p256.der"
)

# Some default settings.
CLEANUP=1
INTERFACE=hyper310

# Flags to make bazel and opentitantool be quiet.
BQUIET=(
  --ui_event_filters=-info,-stderr
  --noshow_progress
)
OQUIET=(
  --logging=error
)

######################################################################
# Build a bazel target and emit a path to the build artifact.
######################################################################
function bazel_build {
  bazel build ${BQUIET[@]} $@
  bazel cquery --output=files ${BQUIET[@]} $@ | sort | head -1
}

######################################################################
# Remove temporary files created during the transfer.
######################################################################
function cleanup {
  rm -rf ${WORKDIR}
}

######################################################################
# Query json output from opentitantool.
#
# Since many of the rescue commands print the raw console output
# before printing the json result, we chop off the console data
# so jq doesn't see it.
######################################################################
function json_query {
  awk '/^{/ {p=1} p{print $0}'| jq --raw-output $@
}

######################################################################
# Get the Device Identification Number from the device ID.
#
# Uses the serial rescue protocol to talk to the ROM_EXT.
######################################################################
function get_device_id {
  ${OPENTITANTOOL} ${OQUIET} --interface=${INTERFACE} -f json rescue get-device-id | json_query .din
}

######################################################################
# Get the nonce and ownership_state from the boot_log.
#
# Uses the serial rescue protocol to talk to the ROM_EXT.
######################################################################
function get_boot_log {
  local -r filename=${1:-$WORKDIR/boot_log.json}
  ${OPENTITANTOOL} ${OQUIET} --interface=${INTERFACE} -f json rescue get-boot-log | json_query > ${filename}
  NONCE=$(jq --raw-output .rom_ext_nonce < ${filename})
  OWNERSHIP_STATE=$(jq --raw-output .ownership_state < ${filename})
}

######################################################################
# Performs an ownership unlock via the serial rescue protocol.
#
# Args:
#   key: a file path or an HSM label of a private key.
#   din: The device identification number.
#   nonce: The current ROM_EXT nonce.
#   filename: optional; filename to save the request into.
#
######################################################################
function ownership_unlock {
  local -r key=$1
  local -r din=$2
  local -r nonce=$3
  local -r filename=${4:-$WORKDIR/unlock.bin}
  local -r response=$WORKDIR/unlock.rsp

  echo "${yellow}===== Ownership Unlock =====${reset}"
  echo "${cyan}Request:${reset}"
  if [[ -f ${key} ]]; then
    # If the key is a file on disk, we can generate and sign the command in
    # one operation.
    ${OPENTITANTOOL} ${OQUIET} ownership unlock --mode=Any --din=${din} --nonce=${nonce} \
        --sign=${key} \
        ${filename}
  else
    # If the key is an HSM label, we generate the unsigned command and sign it
    # with hsmtool.  Hsmtool doesn't know anything about the structure of the
    # file it is signing, so we supply byte ranges to the signing command.
    ${OPENTITANTOOL} ${OQUIET} ownership unlock --mode=Any --din=${din} --nonce=${nonce} \
        ${filename}
    ${HSMTOOL} -t ${TOKENS[$SKU]} -u user \
        ecdsa sign --label=${key} --little-endian \
        --format="slice:0..148" --update-in-place="148..212" \
        ${filename}
  fi
  ${OPENTITANTOOL} ${OQUIET} --interface=${INTERFACE} -f json \
     rescue boot-svc ownership-unlock --input=${filename} \
     | json_query . > ${response}

  echo "${cyan}Response:${reset}"
  jq -C . <${response}
  local -r status=$(jq -r .message.OwnershipUnlockResponse.status <${response})
  if [[ ${status} != "Ok" ]]; then
    echo "${red}ERROR${reset}: ${status}" 
    return 1
  fi
  echo "${green}Ok${reset}"
}

######################################################################
# Prepares and sends an owner config from json.
#
# Builds the binary form of the owner configuration and signs it
# with the private key.
#
# Args:
#   key: a file path or an HSM label of the owner private key.
#   config: The filename of the owner config input json.
#   filename: optional; filename to save the request into.
#
######################################################################
function ownership_configuration {
  local -r key=$1
  local -r config=$2
  local -r filename=${3:-$WORKDIR/config.bin}

  echo "${yellow}===== Sending owner config =====${reset}"
  if [[ -f ${key} ]]; then
    ${OPENTITANTOOL} ${OQUIET} ownership config --input ${config} \
        --sign ${key} \
        ${filename}
  else
    # If the key is an HSM label, we generate the unsigned config and sign it
    # with hsmtool.  Hsmtool doesn't know anything about the structure of the
    # file it is signing, so we supply byte ranges to the signing command.
    ${OPENTITANTOOL} ${OQUIET} ownership config --input ${config} \
        ${filename}
    ${HSMTOOL} -t ${TOKENS[$SKU]} -u user \
        ecdsa sign --label=${key} --little-endian \
        --format="slice:0..1952" --update-in-place="1952..2016" \
        ${filename}
  fi

  # Display the signed binary form of the config as json.
  ${OPENTITANTOOL} ${OQUIET} -f json ownership config --input ${filename}

  # Upload the signed configuration to the chip.
  ${OPENTITANTOOL} ${OQUIET} --interface=${INTERFACE} -f json \
     rescue set-owner-config ${filename}
  echo "${green}Ok${reset}"
}

######################################################################
# Performs an ownership activate via the serial rescue protocol.
#
# Args:
#   key: a file path or an HSM label of the activate private key.
#   din: The device identification number.
#   nonce: The current ROM_EXT nonce.
#   filename: optional; filename to save the request into.
#
######################################################################
function ownership_activate {
  local -r key=$1
  local -r din=$2
  local -r nonce=$3
  local -r filename=${4:-$WORKDIR/activate.bin}
  local -r response=$WORKDIR/activate.rsp

  echo "${yellow}===== Ownership Activate =====${reset}"
  echo "${cyan}Request:${reset}"
  if [[ -f ${key} ]]; then
    # If the key is a file on disk, we can generate and sign the command in
    # one operation.
    ${OPENTITANTOOL} ${OQUIET} ownership activate --din=${din} --nonce=${nonce} \
        --sign=${key} \
        ${filename}
  else
    # If the key is an HSM label, we generate the unsigned command and sign it
    # with hsmtool.  Hsmtool doesn't know anything about the structure of the
    # file it is signing, so we supply byte ranges to the signing command.
    ${OPENTITANTOOL} ${OQUIET} ownership activate --din=${din} --nonce=${nonce} \
        ${filename}
    ${HSMTOOL} -t ${TOKENS[$SKU]} -u user \
        ecdsa sign --label=${key} --little-endian \
        --format="slice:0..148" --update-in-place="148..212" \
        ${filename}
  fi
  ${OPENTITANTOOL} ${OQUIET} --interface=${INTERFACE} -f json \
     rescue boot-svc ownership-activate --input=${filename} \
     | json_query . > ${response}

  echo "${cyan}Response:${reset}"
  jq -C . <${response}
  local -r status=$(jq -r .message.OwnershipActivateResponse.status <${response})
  if [[ ${status} != "Ok" ]]; then
    echo "${red}ERROR${reset}: ${status}" 
    return 1
  fi
  echo "${green}Ok${reset}"
}


######################################################################
# Performs the complete ownership transfer flow.
#
######################################################################
function main {
  # Process arguments into environment vars.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sku)
        SKU=$2
        shift 2
        ;;
      --config)
        CONFIG=$2
        shift 2
        ;;
      --interface)
        INTERFACE=$2
        shift 2
        ;;
      -v|--verbose)
        BQUIET=()
        OQUIET=()
        shift
        ;;
      --owner_key)
        OWNER_KEY=$2
        shift 2
        ;;
      --activate_key)
        ACTIVATE_KEY=$2
        shift 2
        ;;
      --unlock_key)
        UNLOCK_KEY=$2
        shift 2
        ;;
      --nocleanup)
        CLEANUP=0
        shift
        ;;
      -\?|-h|--help)
          usage
          exit
          ;;
      *)
        echo "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Get key nicknames for possible SKU names.
  case ${SKU} in
    fake)
      : ${OWNER_KEY:=fake}
      : ${ACTIVATE_KEY:=fake}
      : ${UNLOCK_KEY:=fake}
      ;;
    sival|proda|prodc)
      : ${OWNER_KEY:=ownership_owner_key}
      : ${ACTIVATE_KEY:=ownership_activate_key}
      : ${UNLOCK_KEY:=ownership_unlock_key}
      ;;
  esac

  # Check if anything we need is left undefined.
  : ${SKU:?No SKU specified}
  : ${CONFIG:?No owner configuration specified}
  : ${OWNER_KEY:?No owner_key specified}
  : ${ACTIVATE_KEY:?No activate_key specified}
  : ${UNLOCK_KEY:?No unlock_key specified}

  # Resolve "fake" nickname to actual filenames
  if [[ ${OWNER_KEY} == "fake" ]]; then
    OWNER_KEY=${FAKE[owner]}
  fi
  if [[ ${ACTIVATE_KEY} == "fake" ]]; then
    ACTIVATE_KEY=${FAKE[owner]}
  fi
  if [[ ${UNLOCK_KEY} == "fake" ]]; then
    UNLOCK_KEY=${FAKE[owner]}
  fi

  WORKDIR=$(mktemp -d -t ownership.XXXXXX)
  if [[ ${CLEANUP} == 1 ]]; then
    trap cleanup EXIT
  else
    echo "No cleanup of workdir ${WORKDIR}"
  fi

  # If we're not running under bazel, build the resources we need:
  # This includes, opentitantool, hsmtool and the PKCS#11 module.
  if [[ -z "${RUNNING_UNDER_BAZEL+is_set}" ]]; then
    echo "${yellow}Building tools${reset}"
    OPENTITANTOOL=$(bazel_build //sw/host/opentitantool)
    HSMTOOL=$(bazel_build //sw/host/hsmtool)
    EXEC_ROOT=$(bazel info ${BQUIET[@]} | awk '/execution_root/ {print $2}')
    HSMTOOL_MODULE=$(bazel_build @cloud_kms_hsm//:libkmsp11)
    export HSMTOOL_MODULE="${EXEC_ROOT}/${HSMTOOL_MODULE}"
  fi
  export KMS_PKCS11_CONFIG=${KMS_CONFIGS[$SKU]}

  # Make sure we have tool paths.
  : ${OPENTITANTOOL:?No path to opentitantool specified}
  : ${HSMTOOL:?No path to hsmtool specified}

  # Make sure we have an PKCS#11 module we can use.
  if [[ -z "${HSMTOOL_MODULE+is_set}" ]]; then
    echo "${red}ERROR${reset}: HSMTOOL_MODULE is not set"
    exit 1
  fi

  # Inform the user about the HSM configuration.
  echo "${yellow}Current values:${reset}"
  echo "${magenta}HSMTOOL_MODULE=${green}$HSMTOOL_MODULE${reset}"
  echo "${magenta}KMS_PKCS11_CONFIG=${green}$KMS_PKCS11_CONFIG${reset}"
  echo

  # Get the device info we need to perform the transfer.
  echo "${yellow}Getting the device ID and nonce...${reset}"
  DIN=$(get_device_id)
  echo "DIN=${DIN}"
  get_boot_log
  echo "NONCE=${NONCE}"
  echo "OWNERSHIP_STATE=${OWNERSHIP_STATE}"
  echo "${green}Ok.${reset}"
  echo

  # Unlock ownership (if in the locked state).
  if [[ ${OWNERSHIP_STATE} == "LockedOwner" ]]; then
    ownership_unlock ${UNLOCK_KEY} ${DIN} ${NONCE}
  else
    echo "${green}Skipping Unlock because ownership_state=${OWNERSHIP_STATE}${reset}"
  fi

  # Build the owner configuration from json and send it to the chip.
  ownership_configuration ${OWNER_KEY} ${CONFIG}

  # Since we used the nonce during the unlock, we need to get the new nonce.
  echo "${yellow}Getting the next nonce...${reset}"
  get_boot_log
  echo "NONCE=${NONCE}"
  echo "${green}Ok.${reset}"
  echo

  # Activate ownership of the new configuration.
  ownership_activate ${ACTIVATE_KEY} ${DIN} ${NONCE}
}

main "$@"

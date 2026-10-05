#!/usr/bin/env bash
#
# ec2-volume-report.sh
#
# Generates one CSV row per EBS volume attached to each EC2 instance.
#
# Fixed columns:
#   Instance Name
#   Instance ID
#   Power State
#   Public IP
#   Private IP
#   Availability Zone
#   Volume ID
#   Volume Type
#   Device Name
#   Volume Size (GiB)
#   IOPS
#   Throughput
#   Volume State
#   Attachment Status
#   Attachment Time
#   Delete On Termination
#   Encrypted
#   KMS Key ID
#
# Extra columns:
#   One column automatically created for each unique EBS volume tag:
#   Volume Tag: <TagKey>
#
# Requirements:
#   - AWS CLI v1/v2
#   - jq
#
# Examples:
#
#   All EC2 instances using configured/default region:
#     ./ec2-volume-report.sh
#
#   All EC2 instances in Sydney:
#     ./ec2-volume-report.sh -r ap-southeast-2
#
#   All EC2 instances in Melbourne:
#     ./ec2-volume-report.sh -r ap-southeast-4
#
#   Using named AWS profile:
#     ./ec2-volume-report.sh -p prod -r ap-southeast-2
#
#   Specific EC2 instances:
#     ./ec2-volume-report.sh \
#       -r ap-southeast-2 \
#       -i i-0abc123,i-0def456
#
#   Custom output:
#     ./ec2-volume-report.sh \
#       -r ap-southeast-2 \
#       -o sydney-ebs-report.csv
#

set -euo pipefail


# ============================================================
# UTF-8 configuration
#
# Important for AWS CLI running from Windows / Git Bash.
# Prevents errors such as:
#
#   'charmap' codec can't encode character
#
# ============================================================

export AWS_CLI_FILE_ENCODING=UTF-8
export PYTHONUTF8=1
export PYTHONIOENCODING=UTF-8
export PYTHONLEGACYWINDOWSSTDIO=1

# Help Git Bash / MSYS use UTF-8 where supported
export LANG="${LANG:-en_US.UTF-8}"
export LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}"


# ============================================================
# Default configuration
# ============================================================

REGION=""
PROFILE=""
INSTANCE_IDS=""

OUTPUT_FILE="ec2_volume_report_$(date +%Y%m%d_%H%M%S).csv"


# ============================================================
# Usage
# ============================================================

usage() {
    cat <<EOF

Usage:

  $0 [-r region] [-p profile] [-i id1,id2,...] [-o output.csv]

Options:

  -r  AWS region
      Example:
      ap-southeast-2
      ap-southeast-4

  -p  AWS CLI profile
      Example:
      prod

  -i  Comma-separated EC2 Instance IDs

      Example:
      i-0123456789abcdef0,i-0987654321abcdef0

  -o  CSV output filename

      Default:
      $OUTPUT_FILE

  -h  Show this help

Examples:

  $0 -r ap-southeast-2

  $0 -r ap-southeast-4

  $0 -p prod -r ap-southeast-2

  $0 -r ap-southeast-2 -o sydney-ebs.csv

  $0 -r ap-southeast-2 \
     -i i-0123456789abcdef0,i-0987654321abcdef0

EOF
    exit 1
}


# ============================================================
# Parse arguments
# ============================================================

while getopts "r:p:i:o:h" opt; do

    case "$opt" in

        r)
            REGION="$OPTARG"
            ;;

        p)
            PROFILE="$OPTARG"
            ;;

        i)
            INSTANCE_IDS="$OPTARG"
            ;;

        o)
            OUTPUT_FILE="$OPTARG"
            ;;

        h)
            usage
            ;;

        *)
            usage
            ;;

    esac

done


# ============================================================
# Check commands
# ============================================================

for cmd in aws jq; do

    if ! command -v "$cmd" >/dev/null 2>&1; then

        echo "ERROR: '$cmd' is not installed or is not available in PATH." >&2

        exit 1

    fi

done


# ============================================================
# AWS arguments
# ============================================================

AWS_ARGS=(--output json --no-cli-pager)

if [[ -n "$PROFILE" ]]; then

    AWS_ARGS+=(--profile "$PROFILE")

fi


if [[ -n "$REGION" ]]; then

    AWS_ARGS+=(--region "$REGION")

fi


# ============================================================
# Temporary directory
# ============================================================

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT


# ============================================================
# Display AWS CLI information
# ============================================================

echo >&2
echo "==============================================" >&2
echo " EC2 / EBS Volume Report" >&2
echo "==============================================" >&2

echo "AWS CLI:" >&2
aws --version >&2

if [[ -n "$REGION" ]]; then
    echo "Region   : $REGION" >&2
else
    echo "Region   : CLI/default configured region" >&2
fi

if [[ -n "$PROFILE" ]]; then
    echo "Profile  : $PROFILE" >&2
else
    echo "Profile  : Default/current AWS credentials" >&2
fi

echo "Output   : $OUTPUT_FILE" >&2
echo >&2


# ============================================================
# Validate AWS authentication
# ============================================================

echo "Checking AWS authentication..." >&2

if ! aws sts get-caller-identity \
    "${AWS_ARGS[@]}" \
    > "$TMP_DIR/identity.json"; then

    echo >&2
    echo "ERROR: Unable to authenticate to AWS." >&2
    echo >&2
    echo "Check your AWS credentials / SAML session / profile." >&2

    exit 1

fi


ACCOUNT_ID="$(jq -r '.Account // ""' "$TMP_DIR/identity.json")"
CALLER_ARN="$(jq -r '.Arn // ""' "$TMP_DIR/identity.json")"

echo "AWS Account : $ACCOUNT_ID" >&2
echo "Caller ARN  : $CALLER_ARN" >&2

echo >&2


# ============================================================
# Instance filters
# ============================================================

INSTANCE_FILTER=()

if [[ -n "$INSTANCE_IDS" ]]; then

    IFS=',' read -r -a ID_ARRAY <<< "$INSTANCE_IDS"

    INSTANCE_FILTER=(
        --instance-ids
        "${ID_ARRAY[@]}"
    )

fi


# ============================================================
# Fetch EC2 instances
# ============================================================

echo "Fetching EC2 instances..." >&2

if ! aws ec2 describe-instances \
    "${AWS_ARGS[@]}" \
    "${INSTANCE_FILTER[@]}" \
    --query 'Reservations[].Instances[]' \
    > "$TMP_DIR/instances.json"; then

    echo >&2
    echo "ERROR: Failed to retrieve EC2 instances." >&2
    exit 1

fi


INSTANCE_COUNT="$(jq 'length' "$TMP_DIR/instances.json")"

echo "Found $INSTANCE_COUNT EC2 instance(s)." >&2


# ============================================================
# Fetch EBS volumes
# ============================================================

echo "Fetching EBS volumes..." >&2

if ! aws ec2 describe-volumes \
    "${AWS_ARGS[@]}" \
    --query 'Volumes[]' \
    > "$TMP_DIR/volumes.json"; then

    echo >&2
    echo "ERROR: Failed to retrieve EBS volumes." >&2
    exit 1

fi


VOLUME_COUNT="$(jq 'length' "$TMP_DIR/volumes.json")"

echo "Found $VOLUME_COUNT EBS volume(s)." >&2

echo >&2


# ============================================================
# Generate CSV
# ============================================================

echo "Generating CSV report..." >&2


jq -r \
    --arg account "$ACCOUNT_ID" \
    --arg region "$REGION" \
    --slurpfile vols "$TMP_DIR/volumes.json" '

    # --------------------------------------------------------
    # Helper:
    #
    # null -> ""
    # false -> "false"
    # numbers -> strings
    # --------------------------------------------------------

    def s:
        if . == null
        then ""
        else tostring
        end;


    ($vols[0]) as $V


    # --------------------------------------------------------
    # Build one record per EC2 instance / EBS volume pair
    # --------------------------------------------------------

    |

    [

        .[] as $i

        |

        (
            $i.Tags // []

            |

            map(
                select(.Key == "Name")
                |
                .Value
            )

            |

            .[0] // ""

        ) as $instance_name


        |

        [

            $V[] as $vol

            |

            ($vol.Attachments // [])[]

            |

            select(
                .InstanceId == $i.InstanceId
            )

            |

            {
                vol: $vol,
                att: .
            }

        ] as $pairs


        # ----------------------------------------------------
        # If an EC2 instance has no EBS volume, retain one row.
        # ----------------------------------------------------

        |

        (
            $pairs

            |

            if length == 0
            then [null]
            else .
            end
        )[]


        |

        {
            instance: $i,
            instance_name: $instance_name,
            vol: .vol,
            att: .att
        }

    ] as $R


    # --------------------------------------------------------
    # Determine every unique Volume Tag key.
    # --------------------------------------------------------

    |

    (
        [
            $R[].vol.Tags[]?
            |
            .Key
        ]

        |

        unique

    ) as $tagKeys


    # --------------------------------------------------------
    # CSV Header
    # --------------------------------------------------------

    |

    (

        [

            "AWS Account ID",

            "Region",

            "Instance Name",

            "Instance ID",

            "Power State",

            "Public IP",

            "Private IP",

            "Availability Zone",

            "Volume ID",

            "Volume Type",

            "Device Name",

            "Volume Size (GiB)",

            "IOPS",

            "Throughput",

            "Volume State",

            "Attachment Status",

            "Attachment Time",

            "Delete On Termination",

            "Encrypted",

            "KMS Key ID"

        ]

        +

        (
            $tagKeys

            |

            map(
                "Volume Tag: " + .
            )
        )

    ) as $header


    # --------------------------------------------------------
    # Output Header + Data
    # --------------------------------------------------------

    |

    $header,


    (

        $R[]

        |

        . as $r


        |

        [

            $account,

            $region,

            $r.instance_name,

            $r.instance.InstanceId,

            $r.instance.State.Name,

            (
                $r.instance.PublicIpAddress
                |
                s
            ),

            (
                $r.instance.PrivateIpAddress
                |
                s
            ),

            (
                $r.instance.Placement.AvailabilityZone
                |
                s
            ),

            (
                $r.vol.VolumeId
                |
                s
            ),

            (
                $r.vol.VolumeType
                |
                s
            ),

            (
                $r.att.Device
                |
                s
            ),

            (
                $r.vol.Size
                |
                s
            ),

            (
                $r.vol.Iops
                |
                s
            ),

            (
                $r.vol.Throughput
                |
                s
            ),

            (
                $r.vol.State
                |
                s
            ),

            (
                $r.att.State
                |
                s
            ),

            (
                $r.att.AttachTime
                |
                s
            ),

            (
                $r.att.DeleteOnTermination
                |
                s
            ),

            (
                $r.vol.Encrypted
                |
                s
            ),

            (
                $r.vol.KmsKeyId
                |
                s
                |
                sub("^.*key/"; "")
            )

        ]


        # ----------------------------------------------------
        # Dynamically append all Volume Tags
        # ----------------------------------------------------

        +

        (

            $tagKeys

            |

            map(

                . as $tag_key

                |

                (

                    $r.vol.Tags // []

                    |

                    map(
                        select(.Key == $tag_key)
                        |
                        .Value
                    )

                    |

                    .[0]

                )

                |

                s

            )

        )

    )


    |

    @csv

' "$TMP_DIR/instances.json" > "$OUTPUT_FILE"


# ============================================================
# Report statistics
# ============================================================

TOTAL_LINES="$(wc -l < "$OUTPUT_FILE")"

ROWS=$(( TOTAL_LINES - 1 ))

echo >&2
echo "==============================================" >&2
echo " Report Complete" >&2
echo "==============================================" >&2

echo "AWS Account : $ACCOUNT_ID" >&2

if [[ -n "$REGION" ]]; then
    echo "Region      : $REGION" >&2
fi

echo "Instances   : $INSTANCE_COUNT" >&2
echo "EBS Volumes : $VOLUME_COUNT" >&2
echo "Report Rows : $ROWS" >&2
echo "CSV File    : $OUTPUT_FILE" >&2

echo >&2


# ============================================================
# Terminal preview
# ============================================================

if command -v column >/dev/null 2>&1; then

    echo "Preview:" >&2
    echo >&2

    head -n 10 "$OUTPUT_FILE" \
        | sed 's/","/"|"/g; s/"//g' \
        | column -s '|' -t \
        >&2

    if [[ "$ROWS" -gt 9 ]]; then

        echo >&2
        echo "(Preview limited to first 9 records.)" >&2

    fi

fi


echo >&2
echo "Done." >&2
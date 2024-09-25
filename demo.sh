#!/usr/bin/env bash
dfx stop
set -e
trap 'dfx stop' EXIT

echo "===========SETUP========="
dfx start --background --clean
dfx identity remove minter
dfx identity new minter --storage-mode plaintext
dfx identity use minter
export MINTER_ACCOUNT_ID=$(dfx ledger account-id)
dfx identity use default
export DEFAULT_ACCOUNT_ID=$(dfx ledger account-id)
dfx deploy --specified-id ryjl3-tyaaa-aaaaa-aaaba-cai icp_ledger_canister --argument "
  (variant {
    Init = record {
      minting_account = \"$MINTER_ACCOUNT_ID\";
      initial_values = vec {
        record {
          \"$DEFAULT_ACCOUNT_ID\";
          record {
            e8s = 10_000_000_000 : nat64;
          };
        };
      };
      send_whitelist = vec {};
      transfer_fee = opt record {
        e8s = 10_000 : nat64;
      };
      token_symbol = opt \"LICP\";
      token_name = opt \"Local ICP\";
    }
  })
"
dfx canister call icp_ledger_canister account_balance '(record { account = '$(python3 -c 'print("vec{" + ";".join([str(b) for b in bytes.fromhex("'$DEFAULT_ACCOUNT_ID'")]) + "}")')'})'
echo "===========SETUP DONE========="

dfx deploy icp_transfer_backend

TOKENS_TRANSFER_ACCOUNT_ID="$(dfx ledger account-id --of-canister icp_transfer_backend)"
TOKENS_TRANSFER_ACCOUNT_ID_BYTES="$(python3 -c 'print("vec{" + ";".join([str(b) for b in bytes.fromhex("'$TOKENS_TRANSFER_ACCOUNT_ID'")]) + "}")')"
TIME_NOW=$(date +%s%N)

echo "$TIME_NOW"
dfx canister call icp_ledger_canister transfer "(record { to=${TOKENS_TRANSFER_ACCOUNT_ID_BYTES}; amount=record { e8s=100_000 }; fee=record { e8s=10_000 }; memo=0:nat64; time =$TIME_NOW : nat64 }, )"

TIME_NOW_SECOND=$(date +%s%N)
echo "$TIME_NOW_SECOND"

# Define 30 seconds in nanoseconds (30 * 1 billion)
THIRTY_SECONDS_NS=$((30 * 1000000000))
# Add 30 seconds to the current time
TIME_IN_30S=$(($TIME_NOW_SECOND + $THIRTY_SECONDS_NS))
dfx canister call icp_transfer_backend transfer "(record { amount=record { e8s=5 }; to_principal=principal \"$(dfx identity get-principal)\"; time =$TIME_IN_30S : nat64 },)"

echo "DONE"
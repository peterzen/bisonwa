#!/usr/bin/env bash
# This script does the following:
#
# 1. Updates contract.go to reflect updated solidity code.
# 2. Generates the runtime bytecoode. This is used to compare against the runtime
#    bytecode on chain in order to verify that the expected contract is deployed.
# 3. Updates the bytecode for ERC20Swap and the test token contract in the harness test.

if [ "$#" -ne 1 ]
then
  echo "Usage: $0 version" >&2
  exit 1
fi

VERSION=$1
PKG_NAME=v${VERSION}
CONTRACT_NAME=ERC20Swap
SOLIDITY_FILE=./${CONTRACT_NAME}V${VERSION}.sol
TEST_TOKEN=./TestToken.sol
if [ ! -f ${SOLIDITY_FILE} ]
then
    echo "${SOLIDITY_FILE} does not exist" >&2
    exit 1
fi
if [ ! -f ${TEST_TOKEN} ]
then
    echo "${TEST_TOKEN} does not exist" >&2
    exit 1
fi
if [ ! -f ${TEST_USDC} ]
then
    echo "${TEST_USDC} does not exist" >&2
    exit 1
fi

mkdir temp

solc --abi --bin --bin-runtime --overwrite --optimize ${SOLIDITY_FILE} -o ./temp/

CONTRACT_FILE=./${PKG_NAME}/contract.go 
abigen --abi ./temp/${CONTRACT_NAME}.abi --bin ./temp/${CONTRACT_NAME}.bin \
 --pkg ${PKG_NAME} --type ${CONTRACT_NAME} --out ./${PKG_NAME}/contract.go

BYTECODE=$(<./temp/${CONTRACT_NAME}.bin)

solc --bin --optimize ${TEST_TOKEN} -o ./temp
TEST_TOKEN_BYTECODE=$(<./temp/TestToken.bin)

echo "${BYTECODE}" | xxd -r -p > "v${VERSION}/swap_contract.bin"
echo "${TEST_TOKEN_BYTECODE}" | xxd -r -p > "v${VERSION}/token_contract.bin"

rm -fr temp

if [ "$VERSION" -eq "0" ]; then
  # Replace a few generated types with the ETH contract versions for interface compatibility.
  perl -0pi -e 's/go-ethereum\/event"/go-ethereum\/event"\n\tethv0 "decred.org\/dcrdex\/dex\/networks\/eth\/contracts\/v0"/' $CONTRACT_FILE

  perl -0pi -e 's/\/\/ ERC20SwapInitiation[^}]*}\n\n//' $CONTRACT_FILE
  perl -0pi -e 's/ERC20SwapInitiation/ethv0.ETHSwapInitiation/g' $CONTRACT_FILE

  perl -0pi -e 's/\/\/ ERC20SwapRedemption[^}]*}\n\n//' $CONTRACT_FILE
  perl -0pi -e 's/ERC20SwapRedemption/ethv0.ETHSwapRedemption/g' $CONTRACT_FILE

  perl -0pi -e 's/\/\/ ERC20SwapSwap[^}]*}\n\n//' $CONTRACT_FILE
  perl -0pi -e 's/ERC20SwapSwap/ethv0.ETHSwapSwap/g' $CONTRACT_FILE

  # Reorder the imports since we rewrote go-ethereum/event to a dcrdex package.
  gofmt -s -w "$CONTRACT_FILE"
fi

if [ "$VERSION" -eq "1" ]; then
  perl -0pi -e 's/go-ethereum\/event"/go-ethereum\/event"\n\tethv1 "decred.org\/dcrdex\/dex\/networks\/eth\/contracts\/v1"/' $CONTRACT_FILE

  perl -0pi -e 's/\/\/ ERC20SwapVector[^}]*}\n\n//' $CONTRACT_FILE
  perl -0pi -e 's/ERC20SwapVector/ethv1.ETHSwapVector/g' $CONTRACT_FILE

  perl -0pi -e 's/\/\/ ERC20SwapRedemption[^}]*}\n\n//' $CONTRACT_FILE
  perl -0pi -e 's/ERC20SwapRedemption/ethv1.ETHSwapRedemption/g' $CONTRACT_FILE

  perl -0pi -e 's/\/\/ ERC20SwapStatus[^}]*}\n\n//' $CONTRACT_FILE
  perl -0pi -e 's/ERC20SwapStatus/ethv1.ETHSwapStatus/g' $CONTRACT_FILE
fi

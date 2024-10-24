#! /bin/bash
 
# replace it with the network your contract lives on
NETWORK=CUSTOM
# replace it with your contract address
CONTRACT_ADDRESS=0xcb0b18dccd7f440db613822412678a363046a49042b265258c780d93448df886

 
# save the ABI to a TypeScript file
ABI = `curl https://aptos.testnet.suzuka.movementlabs.xyz/v1/accounts/$CONTRACT_ADDRESS | sed -n 's/.*"abi":\({.*}\).*}$/\1/p`
echo "export const ABI = $ABI as const" > abi.ts
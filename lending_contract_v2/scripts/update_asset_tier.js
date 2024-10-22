import { SuiClient } from "@mysten/sui.js/client";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import {
  RPC_URL,
  VERSION,
  OPERATOR_PRIVATE_KEY,
  UPGRADED_PACKAGE,
  LEND_COIN_TYPE,
  OPERATOR_CAP,
  CONFIGURATION,
  STATE,
} from "./environment.js";
import { getSignerByPrivateKey } from "./common.js";

const names = [
  "asset_tier_sui_100",
  "asset_tier_sui_200",
  "asset_tier_sui_500",
  "asset_tier_sui_1000",
  "asset_tier_sui_2000",
  "asset_tier_sui_5000",
  "asset_tier_sui_10000",
];
const amounts = [
  100000000, // 100
  200000000, // 200
  500000000, // 500
  1000000000, // 1000
  2000000000, // 2000
  5000000000, // 5000
  10000000000, // 10000
];
const duration = 1209600;

const initAssetTier = async () => {
  const suiClient = new SuiClient({ url: RPC_URL });
  const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

  const tx = new TransactionBlock();
  for (let i = 0; i < names.length; i++) {
    tx.moveCall({
      target: `${UPGRADED_PACKAGE}::operator::update_asset_tier`,
      typeArguments: [LEND_COIN_TYPE],
      arguments: [
        tx.object(OPERATOR_CAP),
        tx.object(VERSION),
        tx.object(STATE),
        tx.pure.string(names[i]),
        tx.pure.u64(amounts[i]),
        tx.pure.u64(duration),
      ],
    });
  }
  const res = await suiClient.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    signer,
  });

  console.log({ response: res }, "Update asset tier");
};

initAssetTier();

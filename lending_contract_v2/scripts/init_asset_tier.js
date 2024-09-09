import { SuiClient } from "@mysten/sui.js/client";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import {
  RPC_URL,
  VERSION,
  OPERATOR_PRIVATE_KEY,
  UPGRADED_PACKAGE,
  LEND_COIN_TYPE,
  OPERATOR_CAP,
  STATE,
} from "./environment.js";
import { getSignerByPrivateKey } from "./common.js";

const names = [
  "asset_tier_sui_1",
  "asset_tier_sui_2",
  "asset_tier_sui_5",
  "asset_tier_sui_10",
  "asset_tier_sui_20",
  "asset_tier_sui_50",
  "asset_tier_sui_100",
];
const amounts = [
  1000000, 2000000, 5000000, 10000000, 20000000, 50000000, 100000000,
];

const duration = 1209600;

const initAssetTier = async () => {
  const suiClient = new SuiClient({ url: RPC_URL });
  const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

  const tx = new TransactionBlock();
  for (let i = 0; i < names.length; i++) {
    tx.moveCall({
      target: `${UPGRADED_PACKAGE}::operator::init_asset_tier`,
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

  console.log({ response: res }, "Init asset tier");
};

initAssetTier();

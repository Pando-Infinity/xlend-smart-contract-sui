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
  USDC_PRICE_FEED_ID,
  SUI_PRICE_FEED_ID,
  SUI_COLLATERAL_COIN_TYPE,
} from "./environment.js";
import { getSignerByPrivateKey } from "./common.js";

const addConfigurationToken = async (
  coinSymbol,
  isLendToken,
  priceFeedId,
  coinType
) => {
  const suiClient = new SuiClient({ url: RPC_URL });
  const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

  const tx = new TransactionBlock();
  tx.moveCall({
    target: `${UPGRADED_PACKAGE}::operator::add_configuration_token`,
    typeArguments: [coinType],
    arguments: [
      tx.object(OPERATOR_CAP),
      tx.object(VERSION),
      tx.object(CONFIGURATION),
      tx.pure.string(coinSymbol),
      tx.pure.string(priceFeedId),
      tx.pure.bool(isLendToken),
    ],
  });

  const res = await suiClient.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    signer,
  });

  console.log({ response: res }, "Add price feed id");
};

const main = async () => {
  await addConfigurationToken("USDC", true, USDC_PRICE_FEED_ID, LEND_COIN_TYPE);
  await addConfigurationToken(
    "SUI",
    false,
    SUI_PRICE_FEED_ID,
    SUI_COLLATERAL_COIN_TYPE
  );
};

main();

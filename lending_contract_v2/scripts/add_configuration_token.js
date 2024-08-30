import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { RPC_URL, VERSION, OPERATOR_PRIVATE_KEY, UPGRADED_PACKAGE, LEND_COIN_TYPE, OPERATOR_CAP, CONFIGURATION, SUI_COLLATERAL_COIN_TYPE } from './environment.js';
import { getSignerByPrivateKey } from './common.js';

const COIN_SYMBOL = "USDC";
const COIN_PRICE_FEED_ID = "0x41f3625971ca2ed2263e78573fe5ce23e13d2558ed3f2e47ab0f84fb9e7ae722";
const IS_LEND_TOKEN = true;

const addPriceFeedId = async () => {
    const suiClient = new SuiClient({ url: RPC_URL });
    const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

    const tx = new TransactionBlock();
    tx.moveCall({
        target: `${UPGRADED_PACKAGE}::operator::add_configuration_token`,
        typeArguments: [LEND_COIN_TYPE],
        arguments: [
            tx.object(OPERATOR_CAP),
            tx.object(VERSION),
            tx.object(CONFIGURATION),
            tx.pure.string(COIN_SYMBOL),
            tx.pure.string(COIN_PRICE_FEED_ID),
            tx.pure.bool(IS_LEND_TOKEN),
        ]
    });

    const res = await suiClient.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer,
    });

    console.log({ response: res }, 'Add price feed id');
}

addPriceFeedId()
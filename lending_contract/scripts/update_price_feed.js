import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { RPC_URL, VERSION, OPERATOR_PRIVATE_KEY, UPGRADED_PACKAGE, LEND_COIN_TYPE, OPERATOR_CAP, CONFIGURATION, SUI_COLLATERAL_COIN_TYPE } from './environment.js';
import { getSignerByPrivateKey } from './common.js';

const COIN_SYMBOL = 'SUI';
const COIN_PRICE_FEED_ID = '0x50c67b3fd225db8912a424dd4baed60ffdde625ed2feaaf283724f9608fea266';

export const updatePriceFeed = async () => {
    const suiClient = new SuiClient({ url: RPC_URL });
    const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

    const tx = new TransactionBlock();
    tx.moveCall({
        target: `${UPGRADED_PACKAGE}::operator::update_price_feed_id`,
        arguments: [
            tx.object(OPERATOR_CAP),
            tx.object(VERSION),
            tx.object(CONFIGURATION),
            tx.pure.string(COIN_SYMBOL),
            tx.pure.string(COIN_PRICE_FEED_ID),
        ]
    })

    const res = await suiClient.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer,
    });

    console.log({ response: res }, 'Add price feed id');
}

updatePriceFeed()
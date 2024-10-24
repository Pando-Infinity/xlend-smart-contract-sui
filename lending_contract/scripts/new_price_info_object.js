import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { RPC_URL, VERSION, OPERATOR_PRIVATE_KEY, UPGRADED_PACKAGE, LEND_COIN_TYPE, OPERATOR_CAP, WBTC_COLLATERAL_COIN_TYPE, WETH_COLLATERAL_COIN_TYPE } from './environment.js';
import { getSignerByPrivateKey } from './common.js';
import { getCoinPrice, priceFeedIds } from './get_coin_price.js';

const coinTypes = [LEND_COIN_TYPE, WBTC_COLLATERAL_COIN_TYPE, WETH_COLLATERAL_COIN_TYPE];

const newPriceInfoObject = async () => {
    const suiClient = new SuiClient({ url: RPC_URL });
    const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);
    const priceData = await getCoinPrice();
    const functionTarget = `${UPGRADED_PACKAGE}::operator::new_price_info_object`
    const tx = new TransactionBlock();
    for (const priceFeed of priceFeedIds) {
        const coinType = coinTypes[priceFeedIds.indexOf(priceFeed)];
        const coinPriceInfo = priceData[priceFeedIds.indexOf(priceFeed)];
        const price = coinPriceInfo.price.price;
        const expo = Math.abs(coinPriceInfo.price.expo);
        const isNegative = coinPriceInfo.price.expo < 0;
        tx.moveCall({
            target: functionTarget,
            typeArguments: [coinType],
            arguments: [
                tx.object(OPERATOR_CAP),
                tx.object(VERSION),
                tx.pure.u64(price),
                tx.pure.u64(expo),
                tx.pure.bool(isNegative),
            ]
        })
    };
    const res = await suiClient.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer,
        options: {
            showObjectChanges: true,
            showEvents: true,
        }
    });
    console.log({ response: res }, 'Created new price info object');
}

newPriceInfoObject();
import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { RPC_URL, OPERATOR_PRIVATE_KEY } from './environment.js';
import { getSignerByPrivateKey } from './common.js';

const privateKey = 'suiprivkey1qrwrzjlnrpwrv3a9utmfhjwmnv386zexh9a6pu3cfwx0qcx3p756c7q949l';
const walletAddress = '0x7f174a18b3082ddff6c5bbf15a9d60b54858e686ca101f6e49814774dd0f9e0a';
const coinType = '0x8ac626e474c33520a815175649fefcbb272678c8c37a7b024e7171fa45d47711::usdc::USDC';

const burnCoin = async () => {
    const suiClient = new SuiClient({ url: RPC_URL });
    const signer = getSignerByPrivateKey(privateKey);

    //Burn Zero Coin
    while(true) {
        try {
        const tx = new TransactionBlock();
        const paginatedCoins = await suiClient.getAllCoins({
            owner: walletAddress,
            cursor,
        });
        cursor = paginatedCoins.nextCursor
        const coinsFiltered = paginatedCoins.data.filter(
            (coin) => coin.coinType === coinType && Number(coin.balance) == 0,
        );
        if (coinsFiltered.length == 0) {
            console.log('Empty Zero Coin');
            break;
        }
        for (const coin of coinsFiltered) {
            console.log('destroy coin', coin.coinObjectId);
            tx.moveCall({
                target: `0x0000000000000000000000000000000000000000000000000000000000000002::coin::burn`,
                typeArguments: [coinType],
                arguments: [
                    tx.object('0x6bad1a88caef6f9ea56680cd31315b2cfeb6018b105471320407559042e6d067'),
                    tx.object(coin.coinObjectId),
                ]
            });
        }

        const res = await suiClient.signAndExecuteTransactionBlock({
            transactionBlock: tx,
            signer,
        });
    
        console.log({ response: res }, 'Burn zero coin');

        await new Promise((resolve) => setTimeout(resolve, 2000));

        if (!paginatedCoins.hasNextPage) break;
        } catch (err) {
            console.log(err);
            continue;
        }
    }

    //Merge coin
    while(true) {
        try {
        const tx = new TransactionBlock();
        const paginatedCoins = await suiClient.getAllCoins({
            owner: walletAddress,
        });
        const coinsFiltered = paginatedCoins.data.filter(
            (coin) => coin.coinType === coinType
        );
        const coins = coinsFiltered.map((coin) => coin.coinObjectId);
        const [destinationCoin, ...restCoin] = coins;
        tx.mergeCoins(destinationCoin, restCoin);

        const res = await suiClient.signAndExecuteTransactionBlock({
            transactionBlock: tx,
            signer,
        });
    
        console.log({ response: res }, 'Merge Coins');

        await new Promise((resolve) => setTimeout(resolve, 2000));

        if (!paginatedCoins.hasNextPage) break;
        } catch (err) {
            console.log(err);
            continue;
        }
    }
}

burnCoin();
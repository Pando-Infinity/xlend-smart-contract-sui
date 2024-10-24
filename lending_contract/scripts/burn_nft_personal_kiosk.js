import { getSignerByPrivateKey } from './common.js';
import { SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { KioskClient, Network, KioskTransaction } from '@mysten/kiosk';
import { RPC_URL } from './environment.js';

export const takeNftFromPersonal = async () => {
  const suiClient = new SuiClient({ url: 'https://fullnode.mainnet.sui.io:443' });
  const signer = getSignerByPrivateKey('suiprivkey1qzvekl58v9k90ltwkq5p3vy0f2yl00ulm3lp58sc74pp90gmevxgszd4rfr');
  const kioskClient = new KioskClient({
    client: suiClient,
    network: Network.MAINNET,
  });
  const kiosks = await kioskClient.getOwnedKiosks({
    address: '0xdc879cb21e7775cfb09100112632d6cab436e706631ee7c6c3dc6dc458101b93',
  });
  for (const kiosk of kiosks.kioskOwnerCaps) {
    if (kiosk.kioskId == '0x0366a0dbe37f1313485e90675d3e607b4e0058bbd9d0c6ce14e3cb613cc93248') {
      console.log(kiosk);
    }
  }
  // const kioskData = await kioskClient.getKiosk({
  //   id: kiosks.kioskIds[0],
  //   options: {
  //     withObjects: true,
  //   }
  // });

  // const tx = new Transaction();
  // const [ownerCap, borrow] = tx.moveCall({
  //   target: '0x0717a13f43deaf5345682153e3633f76cdcf695405959697fcd63f63f289320b::personal_kiosk::borrow_val',
  //   arguments: [
  //     tx.object('0x13cb5a819ef67cdaac6028d295e12bf4eeb7200f23958765892651caaec2ff99'),
  //   ]
  // });
  // const item = tx.moveCall({
  //   target: '0x2::kiosk::take',
  //   typeArguments: ['0x7e2e7bbcd82cdf3591779519cf8b59a63c2bcdbc2812e6be21296f27accf23a9::early_contributor_pass::EarlyContributorPass'],
  //   arguments: [
  //     tx.object(kiosks.kioskOwnerCaps[0].kioskId),
  //     ownerCap,
  //     tx.pure.id(kioskData.itemIds[0]),
  //   ]
  // })
  // tx.moveCall({
  //   target: `0x2::transfer::public_transfer`,
  //   typeArguments: ['0x7e2e7bbcd82cdf3591779519cf8b59a63c2bcdbc2812e6be21296f27accf23a9::early_contributor_pass::EarlyContributorPass'],
  //   arguments: [
  //     item,
  //     tx.pure.address('0x9e316458169b0fa9138e94aff9be698ad4306c20d0fae32236de58f67ee69c37')
  //   ],
  // });
  // tx.moveCall({
  //   target: '0x0717a13f43deaf5345682153e3633f76cdcf695405959697fcd63f63f289320b::personal_kiosk::return_val',
  //   arguments: [
  //     tx.object('0x13cb5a819ef67cdaac6028d295e12bf4eeb7200f23958765892651caaec2ff99'),
  //     ownerCap,
  //     borrow,
  //   ]
  // })
  // const res = await suiClient.signAndExecuteTransaction({
  //   transaction: tx,
  //   signer,
  // });
  // console.log(res);
}

takeNftFromPersonal();
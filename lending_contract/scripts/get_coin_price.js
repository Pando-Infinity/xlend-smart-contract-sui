const USDC_PRICE_FEED_ID = '0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a'
const WBTC_PRICE_FEED_ID = '0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33';
const WETH_PRICE_FEED_ID = '0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6';
export const priceFeedIds = [USDC_PRICE_FEED_ID, WBTC_PRICE_FEED_ID, WETH_PRICE_FEED_ID];

export const getCoinPrice = async () => {
    let queryString = "?";
    for (let i = 0; i < priceFeedIds.length; i++) {
      if (Boolean(priceFeedIds[i])) {
        queryString += `ids[]=${priceFeedIds[i]}&`;
      }
    }
  
    const url = 'https://hermes.pyth.network/api/latest_price_feeds' + queryString;
  
    const response = await fetch(url);
  
    if (!response.ok) {
        throw new Error('Fetch price error');
    };

    const data = await response.json();
    return data;
}

getCoinPrice();
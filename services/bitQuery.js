require('dotenv').config();
const axios = require("axios");

const API_KEY = process.env.BITQUERY_API_KEY;

const fetchData = async (query) => {
    const response = await axios.post("https://graphql.bitquery.io/", { query }, {
        headers: { "X-API-KEY": API_KEY }
    });
    return response.data;
};

async function getPoolData(tokenAddress, exchange) {
    const query = `
    {
      ethereum {
        dexTrades(
          exchangeName: "${exchange}"
          baseCurrency: {is: "${tokenAddress}"}
        ) {
          tradeAmount(in: USD)
          price
          pool {
            address
            reserve1
            reserve2
          }
        }
      }
    }`;

    const response = await fetchData(query);
    
    const trade = response?.data?.ethereum?.dexTrades?.[0];
    return {
        price: trade?.price || 0,
        poolAddress: trade?.pool?.address || "N/A",
        reserve1: trade?.pool?.reserve1 || 0,
        reserve2: trade?.pool?.reserve2 || 0
    };
}

module.exports = { fetchData, getPoolData };

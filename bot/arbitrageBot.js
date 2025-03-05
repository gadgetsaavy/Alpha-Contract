const { getPoolData } = require("../services/bitquery");

async function checkForArbitrage(token) {
    const uniswap = await getPoolData(token, "Uniswap");
    const pancakeswap = await getPoolData(token, "PancakeSwap");

    console.log(`Uniswap Price: ${uniswap.price}, PancakeSwap Price: ${pancakeswap.price}`);

    if (uniswap.price > pancakeswap.price) {
        console.log(`🔥 Arbitrage Opportunity! Buy on PancakeSwap, Sell on Uniswap`);
        // Call smart contract execution here
    }
}

checkForArbitrage("0x...TOKEN_ADDRESS...");

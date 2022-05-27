// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

contract SushiSwapLDOAdapter {
    address public constant SushiSwapRouterAddress = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    uint256 public constant slippage = 500;

    function getOtherCoin(address coin) public pure returns (address) {
        if (coin == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) return 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32; // if weth, return ldo
        if (coin == 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32) return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // if ldo, return weth
        return address(0);
    }

    function executeSwap(
        address pool,
        address fromToken,
        address toToken,
        uint256 amount
    ) external payable  returns (uint256) {
        // Swaps fromTokens to toTokens. Then sends to msg.sender.
        address[] memory _path = new address[](2);
        _path[0] = fromToken;
        _path[1] = toToken;
        uint256[] memory _estimatedAmounts = IUniswapV2Router01(SushiSwapRouterAddress).getAmountsOut(amount, _path);
        // Returns amount of toTokens we receive after the swap.
        return (IUniswapV2Router01(SushiSwapRouterAddress).swapExactTokensForTokens(amount, _estimatedAmounts[_estimatedAmounts.length-1] * (10000-slippage)/10000, _path, msg.sender, block.timestamp+600))[1];
    }

    function enterPool(
        address pool,
        address fromToken,
        uint256 amount
    ) external payable returns (uint256) {
        // Inputs only "fromTokens" into the pool and receives LP tokens
        // Returns total LP tokens received

        address _token1 = fromToken;
        address _token2 = getOtherCoin(_token1);
        // Adds liquidity in an asymmetric manner (amount for fromToken, 0 for the other token)
        (,, uint256 _lpTokenAmount) = IUniswapV2Router01(SushiSwapRouterAddress).addLiquidity(_token1, _token2, amount, 0, 0, 0, msg.sender, block.timestamp+600);
        return _lpTokenAmount;
    }
    // amount in lp tokens?
    function exitPool(
        address pool,
        address toToken,
        uint256 amount
    ) external payable returns (uint256) {
        // Burns LP tokens and receives both weth and ldo.  
        // Then, swaps the "other" token to the toToken using the pool again
        // Returns total amount received in "toToken"
        address _token1 = toToken;
        address _token2 = getOtherCoin(toToken);
        (uint256 receivedAmount1, uint256 receivedAmount2) = IUniswapV2Router01(SushiSwapRouterAddress).removeLiquidity(_token1, _token2, amount , 0,0, msg.sender , block.timestamp+600);
        // Perform a swap to the toToken
        address[] memory _path = new address[](2);
        _path[0] = _token2;
        _path[1] = _token1;
        uint256[] memory _estimatedAmounts = IUniswapV2Router01(SushiSwapRouterAddress).getAmountsOut(receivedAmount2, _path);
        uint256 secondReceivedAmount1 = IUniswapV2Router01(SushiSwapRouterAddress).swapExactTokensForTokens(receivedAmount2, _estimatedAmounts[_estimatedAmounts.length-1] * (10000-slippage)/10000, _path, msg.sender, block.timestamp+600)[1];
        return receivedAmount1 + secondReceivedAmount1;
    }
}
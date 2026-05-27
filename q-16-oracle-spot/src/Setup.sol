// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Minimal mintable ERC-20-like token. Trimmed for tutorial brevity —
///         no events typed, no safe math (compiler already overflow-checks).
contract Q16MockToken {
    string public constant name = "OracleToken";
    string public constant symbol = "OTK";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (msg.sender != from) allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

/// @notice Constant-product (x*y=k) ETH/TKN pool with no fees. Per-user
///         instance — manipulation does not affect other users.
contract Q16SimplePool {
    Q16MockToken public immutable token;

    constructor(Q16MockToken t) payable {
        token = t;
    }

    function swapEthForToken() external payable returns (uint256 tokenOut) {
        require(msg.value > 0, "no eth");
        uint256 ethBefore = address(this).balance - msg.value;
        uint256 tokenBefore = token.balanceOf(address(this));
        // k preserved
        tokenOut = tokenBefore - (ethBefore * tokenBefore) / (ethBefore + msg.value);
        require(tokenOut > 0, "no out");
        token.transfer(msg.sender, tokenOut);
    }

    function swapTokenForEth(uint256 amountIn) external returns (uint256 ethOut) {
        require(amountIn > 0, "no tokens");
        token.transferFrom(msg.sender, address(this), amountIn);
        uint256 ethBefore = address(this).balance;
        uint256 tokenAfter = token.balanceOf(address(this));
        uint256 tokenBefore = tokenAfter - amountIn;
        // k preserved
        ethOut = ethBefore - (ethBefore * tokenBefore) / tokenAfter;
        require(ethOut > 0, "no out");
        (bool ok,) = msg.sender.call{value: ethOut}("");
        require(ok, "send failed");
    }

    /// @notice Spot price = ETH per 1e18 TKN. Manipulable inside a single tx.
    function spotPriceEthPerToken() external view returns (uint256) {
        uint256 tokenReserve = token.balanceOf(address(this));
        if (tokenReserve == 0) return 0;
        return (address(this).balance * 1e18) / tokenReserve;
    }

    receive() external payable {}
}

/// @notice Buggy lender that prices collateral with a single-pool spot
///         oracle. Inflate the pool's price → borrow far more ETH than
///         the collateral is worth → drain the lender.
contract Q16SpotLender {
    Q16SimplePool public immutable pool;
    Q16MockToken public immutable token;

    mapping(address => uint256) public collateralOf;

    constructor(Q16SimplePool p) payable {
        pool = p;
        token = p.token();
    }

    /// @notice Deposit `collateral` TKN, receive ETH worth `collateral * spot`.
    ///         The loan is capped at the lender's current liquidity.
    function borrow(uint256 collateral) external returns (uint256 loan) {
        require(collateral > 0, "no collateral");
        token.transferFrom(msg.sender, address(this), collateral);
        collateralOf[msg.sender] += collateral;

        // BUG: uses spot price at this very moment. Trivially manipulable.
        uint256 price = pool.spotPriceEthPerToken();
        loan = (collateral * price) / 1e18;

        uint256 liquidity = address(this).balance;
        if (loan > liquidity) loan = liquidity;
        require(loan > 0, "zero loan");

        (bool ok,) = msg.sender.call{value: loan}("");
        require(ok, "send failed");
    }

    receive() external payable {}
}

/// @notice Multi-tenant oracle lab. `createInstance()` deploys a personal
///         (token, pool, lender) triple per user and faucets the user
///         some TKN for the manipulation.
contract Q16OracleLab is SolvableBase {
    /// Pool seed: small reserves so a few ETH of swap moves spot a lot.
    uint256 public constant POOL_ETH_SEED = 1 ether;
    uint256 public constant POOL_TKN_SEED = 100e18;
    uint256 public constant LENDER_SEED = 5 ether;
    uint256 public constant USER_TKN_FAUCET = 100e18;

    struct Instance {
        Q16MockToken token;
        Q16SimplePool pool;
        Q16SpotLender lender;
    }

    mapping(address => Instance) private _instances;

    event InstanceCreated(address indexed user, address token, address pool, address lender);

    receive() external payable {}

    function createInstance() external returns (address tokenAddr, address poolAddr, address lenderAddr) {
        require(address(_instances[msg.sender].token) == address(0), "already created");
        require(address(this).balance >= POOL_ETH_SEED + LENDER_SEED, "lab underfunded");

        Q16MockToken t = new Q16MockToken();
        // Pool: seeded with ETH + TKN
        t.mint(address(this), POOL_TKN_SEED);
        Q16SimplePool p = new Q16SimplePool{value: POOL_ETH_SEED}(t);
        t.transfer(address(p), POOL_TKN_SEED);

        // Lender: seeded with ETH only
        Q16SpotLender l = new Q16SpotLender{value: LENDER_SEED}(p);

        // User faucet
        t.mint(msg.sender, USER_TKN_FAUCET);

        _instances[msg.sender] = Instance(t, p, l);
        emit InstanceCreated(msg.sender, address(t), address(p), address(l));
        return (address(t), address(p), address(l));
    }

    function tokenOf(address user) external view returns (Q16MockToken) {
        return _instances[user].token;
    }

    function poolOf(address user) external view returns (Q16SimplePool) {
        return _instances[user].pool;
    }

    function lenderOf(address user) external view returns (Q16SpotLender) {
        return _instances[user].lender;
    }

    function isSolved(address user) public view override returns (bool) {
        Instance memory inst = _instances[user];
        if (address(inst.lender) == address(0)) return false;
        return address(inst.lender).balance == 0;
    }
}

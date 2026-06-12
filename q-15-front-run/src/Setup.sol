// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Public-mint mock ERC-20 — the lab mints the prize balance into
///         each challenge. No faucet rate limit; tutorial only.
contract Q15MockToken is ERC20 {
    constructor() ERC20("PrizeToken", "TKN") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice A "guess the secret to win the prize" game whose designer
///         thought `bytes32 private` was enough to hide sensitive data.
///         The exercise focuses on Solidity visibility versus on-chain
///         observability.
contract Q15FrontRunChallenge {
    // Storage layout is load-bearing: `_secret` must stay at slot 1 so that
    // `secretSlot()` and the storage-inspection exercise remain valid.
    // `token` is immutable, so it lives in code — not in a storage slot.
    address public owner; // slot 0
    bytes32 private _secret; // slot 1
    address public winner; // slot 2

    Q15MockToken public immutable token;

    event Claimed(address indexed winner);

    constructor(address o, bytes32 s, Q15MockToken t) {
        owner = o;
        _secret = s;
        token = t;
    }

    function claim(bytes32 guess) external {
        require(winner == address(0), "already claimed");
        require(guess == _secret, "wrong");
        winner = msg.sender;
        // Forward the entire prize to whoever guessed correctly.
        token.transfer(msg.sender, token.balanceOf(address(this)));
        emit Claimed(msg.sender);
    }

    /// @notice Exposes layout metadata for off-chain inspection exercises.
    function secretSlot() external pure returns (uint256) {
        return 1;
    }
}

/// @notice Multi-tenant lab. `createInstance()` deploys a per-user
///         `Q15FrontRunChallenge` funded with `PRIZE` mock tokens and a fresh
///         secret derived from caller + tx context.
///
///         Deploying costs only gas — the lab MINTS the prize tokens, it does
///         not need to hold any ETH.
contract Q15FrontRunLab is SolvableBase {
    uint256 public constant PRIZE = 1e18; // 1 TKN (18 decimals)

    mapping(address => Q15FrontRunChallenge) private _challenges;
    uint256 private _nonce;

    event InstanceCreated(address indexed user, address challenge, address token);

    function createInstance() external returns (address challenge) {
        require(address(_challenges[msg.sender]) == address(0), "already created");

        _nonce += 1;
        bytes32 secret = keccak256(abi.encode(msg.sender, block.timestamp, block.prevrandao, _nonce));
        Q15MockToken t = new Q15MockToken();
        Q15FrontRunChallenge c = new Q15FrontRunChallenge(msg.sender, secret, t);
        t.mint(address(c), PRIZE);

        _challenges[msg.sender] = c;
        emit InstanceCreated(msg.sender, address(c), address(t));
        return address(c);
    }

    function challengeOf(address user) external view returns (Q15FrontRunChallenge) {
        return _challenges[user];
    }

    function tokenOf(address user) external view returns (Q15MockToken) {
        Q15FrontRunChallenge c = _challenges[user];
        if (address(c) == address(0)) return Q15MockToken(address(0));
        return c.token();
    }

    function isSolved(address user) public view override returns (bool) {
        Q15FrontRunChallenge c = _challenges[user];
        if (address(c) == address(0)) return false;
        return c.winner() == user;
    }
}

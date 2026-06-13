// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// Single-broadcast fast path for the whole tutorial monorepo.
//
// scripts/deploy.sh runs each package's script/Deploy.s.sol as a SEPARATE
// `forge script --broadcast` invocation, so every package pays its own
// on-chain confirmation wait (~1 block). With ~45 packages that is 8-10
// minutes of mostly waiting.
//
// DeployAll reproduces every package's deploy logic inside ONE
// vm.startBroadcast()/stopBroadcast() pair. forge then sends all of the
// transactions back-to-back with sequential nonces and waits for receipts
// ONCE, collapsing the wall-clock cost to a block or two.
//
// Each package is reproduced faithfully (constructor args, post-deploy setup,
// value transfers) and emits the SAME ADDR:<key>: lines the per-package
// scripts emit, plus a PKG:<package-name> marker so scripts/deploy-all.sh can
// group the addresses back into the per-package JSON schema.
//
// Compile/run with FOUNDRY_PROFILE=deployall (it enables via_ir, required by
// the smart-account package, and the optimizer).

import {Script, console2} from "forge-std/Script.sol";

// ---- default-erc-20 (shared token — deployed first) ----
import {MyERC20} from "../default-erc-20/src/MyERC20.sol";

// ---- access-control ----
import {OwnableVault} from "../access-control/src/OwnableVault.sol";
import {RoleManagedVault} from "../access-control/src/RoleManagedVault.sol";

// ---- beacon-proxy ----
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BoxV1} from "../beacon-proxy/src/BoxV1.sol";

// ---- counter ----
import {Counter} from "../counter/src/Counter.sol";
import {EventsAndErrors} from "../counter/src/EventsAndErrors.sol";
import {SimpleStorage} from "../counter/src/SimpleStorage.sol";

// ---- default-erc-721 ----
import {MyERC721} from "../default-erc-721/src/MyERC721.sol";

// ---- eip-712-voucher (only Voucher is deployed; its MyERC20 is not) ----
import {Voucher} from "../eip-712-voucher/src/Voucher.sol";

// ---- erc1155-multi-token ----
import {GameItems} from "../erc1155-multi-token/src/GameItems.sol";

// ---- erc20-allowance ----
import {AllowanceToken} from "../erc20-allowance/src/AllowanceToken.sol";
import {TokenBank} from "../erc20-allowance/src/TokenBank.sol";

// ---- erc20-extended ----
import {ExtendedERC20} from "../erc20-extended/src/ExtendedERC20.sol";

// ---- erc2771-meta-tx ----
import {MyForwarder} from "../erc2771-meta-tx/src/MyForwarder.sol";
import {MetaCounter} from "../erc2771-meta-tx/src/MetaCounter.sol";

// ---- eth-sign ----
import {SignatureVerifier} from "../eth-sign/src/SignatureVerifier.sol";

// ---- minimal-proxy ----
import {Implementation} from "../minimal-proxy/src/Implementation.sol";
import {Factory} from "../minimal-proxy/src/Factory.sol";

// ---- q-01 .. q-26 (all isolate their contracts under Q## names) ----
import {Q01Counter} from "../q-01-counter/src/Setup.sol";
import {Q02EventsAndErrors} from "../q-02-events-errors/src/Setup.sol";
import {Q03EthMailbox} from "../q-03-eth-mailbox/src/Setup.sol";
import {Q04DelegatecallLab} from "../q-04-delegatecall/src/Setup.sol";
import {Q05SimpleWallet, Q05MockERC20} from "../q-05-simple-wallet/src/Setup.sol";
import {Q06PermitToken, Q06PermitChallenge} from "../q-06-erc20-permit/src/Setup.sol";
import {Q07EthSignChallenge} from "../q-07-eth-sign/src/Setup.sol";
import {Q08VoucherChallenge} from "../q-08-eip712-voucher/src/Setup.sol";
import {Q09ReentrancyLab} from "../q-09-reentrancy/src/Setup.sol";
import {Q10ReplayLab} from "../q-10-signature-replay/src/Setup.sol";
import {Q11VulnerableRegistry} from "../q-11-access-control/src/Setup.sol";
import {Q12TxOriginLab} from "../q-12-tx-origin/src/Setup.sol";
import {Q13UnsafePayout} from "../q-13-unchecked-call/src/Setup.sol";
import {Q14DosLab} from "../q-14-dos-revert/src/Setup.sol";
import {Q15FrontRunLab} from "../q-15-front-run/src/Setup.sol";
import {Q16OracleLab} from "../q-16-oracle-spot/src/Setup.sol";
import {Q17InflateLab} from "../q-17-reentrancy-inflate/src/Setup.sol";
import {Q18ReadOnlyLab} from "../q-18-read-only-reentrancy/src/Setup.sol";
import {Q19ReentrancyBasicLab} from "../q-19-reentrancy-basic/src/Setup.sol";
import {Q20Erc20BasicLab} from "../q-20-erc20-basic/src/Setup.sol";
import {Q21EcrecoverBasicLab} from "../q-21-ecrecover-basic/src/Setup.sol";
import {Q22SpotPriceBasicLab} from "../q-22-spot-price-basic/src/Setup.sol";
import {Q23Vault} from "../q-23-storage-slots/src/Setup.sol";
import {Q24NftLab} from "../q-24-nft-ownership/src/Setup.sol";
import {Q25UupsLab} from "../q-25-uups-upgrade/src/Setup.sol";
import {Q26MyForwarder, Q26MetaCounter} from "../q-26-meta-tx/src/Setup.sol";

// ---- simple-transparent ----
import {Box} from "../simple-transparent/src/Box.sol";
import {
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// ---- simple-uups ----
import {CounterV1} from "../simple-uups/src/CounterV1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// ---- simple-wallet ----
import {SimpleWallet} from "../simple-wallet/src/SimpleWallet.sol";

// ---- smart-account ----
import {SmartAccount} from "../smart-account/src/SmartAccount.sol";

// ---- thirty-one-game ----
import {ThirtyOneGame} from "../thirty-one-game/src/ThirtyOneGame.sol";

// ---- tx-basics ----
import {DelegateCaller, DelegateLogic} from "../tx-basics/src/DelegatecallDemo.sol";
import {EthSender} from "../tx-basics/src/EthSender.sol";
import {EthMailbox} from "../tx-basics/src/EthMailbox.sol";
import {EthSink} from "../tx-basics/src/EthSink.sol";

// ---- vulnerabilities ----
import {VulnerableVault} from "../vulnerabilities/src/reentrancy/VulnerableVault.sol";
import {SafeVault} from "../vulnerabilities/src/reentrancy/SafeVault.sol";
import {MockPool} from "../vulnerabilities/src/oracle-manipulation/MockPool.sol";
import {VulnerableLending} from "../vulnerabilities/src/oracle-manipulation/VulnerableLending.sol";
import {SafeLending} from "../vulnerabilities/src/oracle-manipulation/SafeLending.sol";
import {VulnerableSigClaim} from "../vulnerabilities/src/signature-replay/VulnerableSigClaim.sol";
import {SafeSigClaim} from "../vulnerabilities/src/signature-replay/SafeSigClaim.sol";
import {VulnerableWallet} from "../vulnerabilities/src/tx-origin/VulnerableWallet.sol";
import {SafeWallet} from "../vulnerabilities/src/tx-origin/SafeWallet.sol";

/// @notice One-shot deployer for every tutorial package.
///         Run with FOUNDRY_PROFILE=deployall. Emits PKG:<pkg> followed by the
///         package's ADDR:<key>: <0x...> lines; scripts/deploy-all.sh parses
///         these into deployments/<network>.json and docker/shared/<network>.json.
contract DeployAll is Script {
    function run() external {
        // The shared default-erc-20 token must be deployed before any package
        // that would otherwise read SHARED_ERC20 / mint a local mock. Its
        // address is captured and passed directly to those packages below.
        vm.startBroadcast();

        // ---- default-erc-20 (shared token) ----
        MyERC20 sharedToken = new MyERC20("MyERC20", "ME2", 100_000_000 ether);
        address shared = address(sharedToken);

        // ---- access-control ----
        {
            OwnableVault ownableVault = new OwnableVault(msg.sender);
            RoleManagedVault roleManagedVault = new RoleManagedVault(msg.sender);
            console2.log("PKG:access-control");
            console2.log("ADDR:ownableVault:", address(ownableVault));
            console2.log("ADDR:roleManagedVault:", address(roleManagedVault));
        }

        // ---- beacon-proxy ----
        {
            BoxV1 impl = new BoxV1();
            UpgradeableBeacon beacon = new UpgradeableBeacon(address(impl), msg.sender);
            BeaconProxy proxy = new BeaconProxy(address(beacon), abi.encodeCall(BoxV1.initialize, (42)));
            console2.log("PKG:beacon-proxy");
            console2.log("ADDR:implementation:", address(impl));
            console2.log("ADDR:beacon:", address(beacon));
            console2.log("ADDR:proxy:", address(proxy));
        }

        // ---- counter ----
        {
            Counter counter = new Counter();
            EventsAndErrors eventsAndErrors = new EventsAndErrors();
            SimpleStorage simpleStorage = new SimpleStorage();
            console2.log("PKG:counter");
            console2.log("ADDR:counter:", address(counter));
            console2.log("ADDR:eventsAndErrors:", address(eventsAndErrors));
            console2.log("ADDR:simpleStorage:", address(simpleStorage));
        }

        // ---- default-erc-20 (already deployed above as the shared token) ----
        {
            console2.log("PKG:default-erc-20");
            console2.log("ADDR:token:", shared);
        }

        // ---- default-erc-721 ----
        {
            MyERC721 nft = new MyERC721("MyERC721", "ME7");
            console2.log("PKG:default-erc-721");
            console2.log("ADDR:nft:", address(nft));
        }

        // ---- eip-712-voucher ----
        {
            Voucher voucher = new Voucher();
            console2.log("PKG:eip-712-voucher");
            console2.log("ADDR:voucher:", address(voucher));
        }

        // ---- erc1155-multi-token ----
        {
            GameItems gameItems = new GameItems(msg.sender);
            console2.log("PKG:erc1155-multi-token");
            console2.log("ADDR:gameItems:", address(gameItems));
        }

        // ---- erc20-allowance ----
        {
            AllowanceToken token = new AllowanceToken("AllowanceToken", "ATK", 100_000_000 ether);
            TokenBank bank = new TokenBank(token);
            console2.log("PKG:erc20-allowance");
            console2.log("ADDR:token:", address(token));
            console2.log("ADDR:bank:", address(bank));
        }

        // ---- erc20-extended ----
        {
            ExtendedERC20 token = new ExtendedERC20(msg.sender, 100_000_000 ether);
            console2.log("PKG:erc20-extended");
            console2.log("ADDR:token:", address(token));
        }

        // ---- erc2771-meta-tx ----
        {
            MyForwarder forwarder = new MyForwarder();
            MetaCounter counter = new MetaCounter(address(forwarder));
            console2.log("PKG:erc2771-meta-tx");
            console2.log("ADDR:forwarder:", address(forwarder));
            console2.log("ADDR:counter:", address(counter));
        }

        // ---- eth-sign ----
        {
            SignatureVerifier verifier = new SignatureVerifier();
            console2.log("PKG:eth-sign");
            console2.log("ADDR:verifier:", address(verifier));
        }

        // ---- minimal-proxy ----
        {
            Implementation implementation = new Implementation();
            Factory factory = new Factory(address(implementation));
            console2.log("PKG:minimal-proxy");
            console2.log("ADDR:implementation:", address(implementation));
            console2.log("ADDR:factory:", address(factory));
        }

        // ---- q-01-counter ----
        {
            Q01Counter counter = new Q01Counter();
            console2.log("PKG:q-01-counter");
            console2.log("ADDR:counter:", address(counter));
        }

        // ---- q-02-events-errors ----
        {
            Q02EventsAndErrors instance = new Q02EventsAndErrors();
            console2.log("PKG:q-02-events-errors");
            console2.log("ADDR:eventsAndErrors:", address(instance));
        }

        // ---- q-03-eth-mailbox ----
        {
            Q03EthMailbox instance = new Q03EthMailbox();
            console2.log("PKG:q-03-eth-mailbox");
            console2.log("ADDR:mailbox:", address(instance));
        }

        // ---- q-04-delegatecall ----
        {
            Q04DelegatecallLab lab = new Q04DelegatecallLab();
            console2.log("PKG:q-04-delegatecall");
            console2.log("ADDR:lab:", address(lab));
        }

        // ---- q-05-simple-wallet (uses the shared token instead of a local mock) ----
        {
            Q05SimpleWallet wallet = new Q05SimpleWallet();
            // Original: address token = vm.envOr("SHARED_ERC20", address(0));
            // then deploys Q05MockERC20 only when unset. Here SHARED_ERC20 is
            // always set to the default-erc-20 token, so reuse it directly.
            address token = shared;
            console2.log("PKG:q-05-simple-wallet");
            console2.log("ADDR:wallet:", address(wallet));
            console2.log("ADDR:token:", token);
        }

        // ---- q-06-erc20-permit ----
        {
            Q06PermitToken token = new Q06PermitToken();
            Q06PermitChallenge challenge = new Q06PermitChallenge(token);
            console2.log("PKG:q-06-erc20-permit");
            console2.log("ADDR:token:", address(token));
            console2.log("ADDR:challenge:", address(challenge));
        }

        // ---- q-07-eth-sign ----
        {
            Q07EthSignChallenge challenge = new Q07EthSignChallenge();
            console2.log("PKG:q-07-eth-sign");
            console2.log("ADDR:challenge:", address(challenge));
        }

        // ---- q-08-eip712-voucher (constructor internally deploys the token) ----
        {
            Q08VoucherChallenge challenge = new Q08VoucherChallenge();
            console2.log("PKG:q-08-eip712-voucher");
            console2.log("ADDR:challenge:", address(challenge));
            console2.log("ADDR:token:", address(challenge.token()));
        }

        // ---- q-09-reentrancy (lab is seeded with 0.1 ether) ----
        {
            Q09ReentrancyLab lab = new Q09ReentrancyLab();
            (bool ok,) = address(lab).call{value: 0.1 ether}("");
            require(ok, "q-09 lab funding failed");
            console2.log("PKG:q-09-reentrancy");
            console2.log("ADDR:lab:", address(lab));
        }

        // ---- q-10-signature-replay ----
        {
            Q10ReplayLab lab = new Q10ReplayLab();
            console2.log("PKG:q-10-signature-replay");
            console2.log("ADDR:lab:", address(lab));
        }

        // ---- q-11-access-control ----
        {
            Q11VulnerableRegistry registry = new Q11VulnerableRegistry();
            console2.log("PKG:q-11-access-control");
            console2.log("ADDR:registry:", address(registry));
        }

        // ---- q-12-tx-origin ----
        {
            Q12TxOriginLab lab = new Q12TxOriginLab();
            console2.log("PKG:q-12-tx-origin");
            console2.log("ADDR:lab:", address(lab));
        }

        // ---- q-13-unchecked-call (constructor internally deploys the trap) ----
        {
            Q13UnsafePayout payout = new Q13UnsafePayout();
            console2.log("PKG:q-13-unchecked-call");
            console2.log("ADDR:payout:", address(payout));
            console2.log("ADDR:trap:", address(payout.trap()));
        }

        // ---- q-14-dos-revert ----
        {
            Q14DosLab lab = new Q14DosLab();
            console2.log("PKG:q-14-dos-revert");
            console2.log("ADDR:lab:", address(lab));
        }

        // ---- q-15-front-run ----
        {
            Q15FrontRunLab lab = new Q15FrontRunLab();
            console2.log("PKG:q-15-front-run");
            console2.log("ADDR:lab:", address(lab));
        }

        // ---- q-16-oracle-spot (lab is seeded with 1 ether) ----
        {
            Q16OracleLab lab = new Q16OracleLab();
            (bool ok,) = address(lab).call{value: 1 ether}("");
            require(ok, "q-16 lab funding failed");
            console2.log("PKG:q-16-oracle-spot");
            console2.log("ADDR:lab:", address(lab));
        }

        // ---- q-17-reentrancy-inflate (lab is seeded with 0.05 ether) ----
        {
            Q17InflateLab lab = new Q17InflateLab();
            (bool ok,) = address(lab).call{value: 0.05 ether}("");
            require(ok, "q-17 lab funding failed");
            console2.log("PKG:q-17-reentrancy-inflate");
            console2.log("ADDR:lab:", address(lab));
        }

        // ---- q-18-read-only-reentrancy (lab is seeded with 0.1 ether) ----
        {
            Q18ReadOnlyLab lab = new Q18ReadOnlyLab();
            (bool ok,) = address(lab).call{value: 0.1 ether}("");
            require(ok, "q-18 lab funding failed");
            console2.log("PKG:q-18-read-only-reentrancy");
            console2.log("ADDR:lab:", address(lab));
        }

        // ---- q-19-reentrancy-basic (lab is seeded with 0.1 ether) ----
        {
            Q19ReentrancyBasicLab lab = new Q19ReentrancyBasicLab();
            (bool ok,) = address(lab).call{value: 0.1 ether}("");
            require(ok, "q-19 lab funding failed");
            console2.log("PKG:q-19-reentrancy-basic");
            console2.log("ADDR:lab:", address(lab));
        }

        // ---- q-20-erc20-basic ----
        {
            Q20Erc20BasicLab lab = new Q20Erc20BasicLab();
            console2.log("PKG:q-20-erc20-basic");
            console2.log("ADDR:lab:", address(lab));
            console2.log("ADDR:faucet:", address(lab.faucet()));
            console2.log("ADDR:vault:", address(lab.vault()));
        }

        // ---- q-21-ecrecover-basic (three signed candidates; one trusted) ----
        {
            uint256 trustedPk = vm.envOr(
                "TRUSTED_SIGNER_PK", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
            );
            uint256 impostorAPk = vm.envOr(
                "IMPOSTOR_A_PK", uint256(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d)
            );
            uint256 impostorBPk = vm.envOr(
                "IMPOSTOR_B_PK", uint256(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a)
            );

            address trustedSigner = vm.addr(trustedPk);

            Q21EcrecoverBasicLab.Candidate[] memory cands = new Q21EcrecoverBasicLab.Candidate[](3);
            cands[0] = _q21Sign(impostorAPk, keccak256("hello from imposter A"));
            cands[1] = _q21Sign(trustedPk, keccak256("trusted signer authorized this message"));
            cands[2] = _q21Sign(impostorBPk, keccak256("hello from imposter B"));

            Q21EcrecoverBasicLab lab = new Q21EcrecoverBasicLab(trustedSigner, cands);
            console2.log("PKG:q-21-ecrecover-basic");
            console2.log("ADDR:lab:", address(lab));
        }

        // ---- q-22-spot-price-basic ----
        {
            Q22SpotPriceBasicLab lab = new Q22SpotPriceBasicLab();
            console2.log("PKG:q-22-spot-price-basic");
            console2.log("ADDR:lab:", address(lab));
        }

        // ---- q-23-storage-slots (secrets seeded from block context) ----
        {
            bytes32 a = keccak256(abi.encodePacked("q23.A", block.timestamp, blockhash(block.number - 1)));
            bytes32 b = keccak256(abi.encodePacked("q23.B", block.timestamp, blockhash(block.number - 1)));
            Q23Vault vault = new Q23Vault(a, b);
            console2.log("PKG:q-23-storage-slots");
            console2.log("ADDR:vault:", address(vault));
        }

        // ---- q-24-nft-ownership ----
        {
            Q24NftLab lab = new Q24NftLab();
            console2.log("PKG:q-24-nft-ownership");
            console2.log("ADDR:lab:", address(lab));
            console2.log("ADDR:nft:", address(lab.nft()));
        }

        // ---- q-25-uups-upgrade ----
        {
            Q25UupsLab lab = new Q25UupsLab();
            console2.log("PKG:q-25-uups-upgrade");
            console2.log("ADDR:lab:", address(lab));
            console2.log("ADDR:v1Impl:", address(lab.v1Impl()));
            console2.log("ADDR:v2Impl:", address(lab.v2Impl()));
        }

        // ---- q-26-meta-tx ----
        {
            Q26MyForwarder forwarder = new Q26MyForwarder();
            Q26MetaCounter counter = new Q26MetaCounter(address(forwarder));
            console2.log("PKG:q-26-meta-tx");
            console2.log("ADDR:forwarder:", address(forwarder));
            console2.log("ADDR:counter:", address(counter));
        }

        // ---- simple-transparent ----
        {
            Box implementation = new Box();
            bytes memory initData = abi.encodeCall(Box.initialize, (42));
            TransparentUpgradeableProxy proxy =
                new TransparentUpgradeableProxy(address(implementation), msg.sender, initData);
            console2.log("PKG:simple-transparent");
            console2.log("ADDR:implementation:", address(implementation));
            console2.log("ADDR:proxy:", address(proxy));
        }

        // ---- simple-uups ----
        {
            CounterV1 implementation = new CounterV1();
            bytes memory initData = abi.encodeCall(CounterV1.initialize, (msg.sender));
            ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
            console2.log("PKG:simple-uups");
            console2.log("ADDR:implementation:", address(implementation));
            console2.log("ADDR:proxy:", address(proxy));
        }

        // ---- simple-wallet ----
        {
            SimpleWallet wallet = new SimpleWallet();
            console2.log("PKG:simple-wallet");
            console2.log("ADDR:wallet:", address(wallet));
        }

        // ---- smart-account ----
        {
            SmartAccount smartAccount = new SmartAccount();
            console2.log("PKG:smart-account");
            console2.log("ADDR:smartAccount:", address(smartAccount));
        }

        // ---- thirty-one-game (uses the shared token instead of a local mock) ----
        {
            uint256 winnerPercentage = vm.envOr("THIRTYONE_WINNER_PERCENTAGE", uint256(80));
            // Original: address token = vm.envOr("SHARED_ERC20", address(0));
            // then deploys MockToken only when unset. SHARED_ERC20 is always set
            // here, so reuse the default-erc-20 token directly.
            address token = shared;
            ThirtyOneGame game = new ThirtyOneGame(token, winnerPercentage);
            console2.log("PKG:thirty-one-game");
            console2.log("ADDR:token:", token);
            console2.log("ADDR:game:", address(game));
        }

        // ---- tx-basics ----
        {
            EthSender sender = new EthSender();
            EthMailbox mailbox = new EthMailbox();
            EthSink sink = new EthSink();
            DelegateLogic delegateLogic = new DelegateLogic();
            DelegateCaller delegateCaller = new DelegateCaller();
            console2.log("PKG:tx-basics");
            console2.log("ADDR:ethSender:", address(sender));
            console2.log("ADDR:ethMailbox:", address(mailbox));
            console2.log("ADDR:ethSink:", address(sink));
            console2.log("ADDR:delegateLogic:", address(delegateLogic));
            console2.log("ADDR:delegateCaller:", address(delegateCaller));
        }

        // ---- vulnerabilities ----
        {
            VulnerableVault vulnerableVault = new VulnerableVault();
            SafeVault safeVault = new SafeVault();
            MockPool mockPool = new MockPool(1000 ether, 1000 ether);
            VulnerableLending vulnerableLending = new VulnerableLending(address(mockPool));
            SafeLending safeLending = new SafeLending(msg.sender, 1 ether);
            VulnerableSigClaim vulnerableSigClaim = new VulnerableSigClaim(msg.sender);
            SafeSigClaim safeSigClaim = new SafeSigClaim(msg.sender);
            VulnerableWallet vulnerableWallet = new VulnerableWallet();
            SafeWallet safeWallet = new SafeWallet();
            console2.log("PKG:vulnerabilities");
            console2.log("ADDR:vulnerableVault:", address(vulnerableVault));
            console2.log("ADDR:safeVault:", address(safeVault));
            console2.log("ADDR:mockPool:", address(mockPool));
            console2.log("ADDR:vulnerableLending:", address(vulnerableLending));
            console2.log("ADDR:safeLending:", address(safeLending));
            console2.log("ADDR:vulnerableSigClaim:", address(vulnerableSigClaim));
            console2.log("ADDR:safeSigClaim:", address(safeSigClaim));
            console2.log("ADDR:vulnerableWallet:", address(vulnerableWallet));
            console2.log("ADDR:safeWallet:", address(safeWallet));
        }

        vm.stopBroadcast();
    }

    /// @dev Reproduces q-21-ecrecover-basic's _sign helper: signs `hash` with
    ///      `pk` and packs the result into a lab Candidate.
    function _q21Sign(uint256 pk, bytes32 hash)
        internal
        pure
        returns (Q21EcrecoverBasicLab.Candidate memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        return Q21EcrecoverBasicLab.Candidate({messageHash: hash, v: v, r: r, s: s});
    }
}

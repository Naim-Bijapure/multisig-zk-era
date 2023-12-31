// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IContractDeployer.sol";

import "./MultiSigWallet.sol";

//custom errors
error CALLER_NOT_REGISTERED();

contract MultiSigFactory {
  MultiSigWallet[] public multiSigs;
  mapping(address => bool) existsMultiSig;

  event Create2Event(
    uint256 indexed contractId,
    string name,
    address indexed contractAddress,
    address creator,
    address[] owners,
    uint256 signaturesRequired
  );

  event Owners(address indexed contractAddress, address[] owners, uint256 indexed signaturesRequired);

  modifier onlyRegistered() {
    if (!existsMultiSig[msg.sender]) {
      revert CALLER_NOT_REGISTERED();
    }
    _;
  }

  function emitOwners(
    address _contractAddress,
    address[] calldata _owners,
    uint256 _signaturesRequired
  ) external onlyRegistered {
    emit Owners(_contractAddress, _owners, _signaturesRequired);
  }

  function numberOfMultiSigs() public view returns (uint256) {
    return multiSigs.length;
  }

  function getMultiSig(
    uint256 _index
  ) public view returns (address multiSigAddress, uint256 signaturesRequired, uint256 balance) {
    MultiSigWallet multiSig = multiSigs[_index];
    return (address(multiSig), multiSig.signaturesRequired(), address(multiSig).balance);
  }

  function create2(address[] calldata _owners, uint256 _signaturesRequired, string calldata _name) public payable {
    uint256 id = numberOfMultiSigs();

    bytes32 _salt = keccak256(abi.encodePacked(abi.encode(_name, address(msg.sender))));

    /**----------------------
     * create2 implementation
     * ---------------------*/
    address multiSig_address = payable(
      Create2.deploy(
        msg.value,
        _salt,
        abi.encodePacked(type(MultiSigWallet).creationCode, abi.encode(_name, address(this)))
      )
    );

    MultiSigWallet multiSig = MultiSigWallet(payable(multiSig_address));

    /**----------------------
     * init remaining values
     * ---------------------*/
    multiSig.init(_owners, _signaturesRequired);

    multiSigs.push(multiSig);
    existsMultiSig[address(multiSig_address)] = true;

    emit Create2Event(id, _name, address(multiSig), msg.sender, _owners, _signaturesRequired);
    emit Owners(address(multiSig), _owners, _signaturesRequired);
  }

  /**----------------------
   * get a pre-computed address
   * ---------------------*/
  function computedAddress(
    string calldata _name,
    address CONTRACT_DEPLOYER_ADDRESS,
    bytes32 bytecodeHash
  ) public view returns (address) {
    bytes32 _salt = keccak256(abi.encodePacked(abi.encode(_name, address(msg.sender))));

    bytes memory input = abi.encodePacked(abi.encode(_name, address(this)));

    address computed_address = IContractDeployer(CONTRACT_DEPLOYER_ADDRESS).getNewAddressCreate2(
      address(this),
      bytecodeHash,
      _salt,
      input
    );

    return computed_address;
  }

  /**----------------------
   * return wallets for an address
   * ---------------------*/

  // function getWallets(address userAddress) public view returns (address[] memory) {
  //     address[] memory wallets = new address[](multiSigs.length);

  //     for (uint256 i = 0; i < multiSigs.length; i++) {
  //         MultiSigWallet multiSig = multiSigs[i];
  //         if (multiSig.isOwner(userAddress)) {
  //             wallets[i] = address(multiSig);
  //         }
  //     }

  //     return (wallets);
  // }
}

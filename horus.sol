pragma solidity 0.8.11;

// SPDX-License-Identifier: UNLICENSED
/*


  _    _                        _____           _                  _ 
 | |  | |                      |  __ \         | |                | |
 | |__| | ___  _ __ _   _ ___  | |__) | __ ___ | |_ ___   ___ ___ | |
 |  __  |/ _ \| '__| | | / __| |  ___/ '__/ _ \| __/ _ \ / __/ _ \| |
 | |  | | (_) | |  | |_| \__ \ | |   | | | (_) | || (_) | (_| (_) | |
 |_|  |_|\___/|_|   \__,_|___/ |_|   |_|  \___/ \__\___/ \___\___/|_|
                                                                     


*/
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

// Staking contract
contract HorusStaking {

    address[] public stakers;
    uint InitialLiquidity;
    uint public deposit;
    uint public MaxValue = 500*10**18;

    struct user {
        uint userDeposit;
        uint poolShare;
        bool staker;
        uint viewReward;
        uint ClaimDisplay;
    }

    address Burn = 0x0000000000000000000000000000000000000000;
    address payable LiquidityProvider;
    address payable PoolAddress;
    address owner;
    mapping( address => bool ) public approvedStakers;

    function GetBalance() public view returns(uint) {
        return address(this).balance;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    mapping(uint => uint) contractBalance;
    mapping(address => user) User;

    uint public TotalLiquidity;

    /* setting genesis liquidity provider */
    function modifyLiquidityProvider(address payable _addr) public {
        require(msg.sender == owner);
        LiquidityProvider = _addr;
    }

    /* providing the initial liquidity */
    function ProvideInitialLiquidity() public payable {
        require(msg.sender == LiquidityProvider);
        InitialLiquidity += msg.value;
        payable(PoolAddress).call{value: msg.value}("");
        TotalLiquidity = InitialLiquidity + deposit;
    }

    /* withdrawing only genesis liquidity */
    function WithdrawInitialLiquidity(uint _amount) public payable {
        require(msg.sender == LiquidityProvider && InitialLiquidity - msg.value >= 0);
        HorusProtocol LP = HorusProtocol(PoolAddress);
        LP.WithdrawStake(_amount);
        InitialLiquidity -= _amount;
        payable(LiquidityProvider).call{value: _amount}("");
        TotalLiquidity = InitialLiquidity + deposit;
    }

    /* approving stakers into whitelist */
    function _approveStaker(address newStaker_) internal returns (bool) {
        require(msg.sender == owner);
        return approvedStakers[newStaker_] = true;
    }

    function approveStaker(address newStaker_) external returns (bool) {
        require(msg.sender == owner);
        return _approveStaker(newStaker_);
    }

    function approveStakers(address[] calldata newStakers_) external returns (uint256) {
        require(msg.sender == owner);
        for(uint256 iteration_ = 0; newStakers_.length > iteration_; iteration_++ ) {
            _approveStaker(newStakers_[iteration_]);
        }
        return newStakers_.length;
    }

    /* deapproving stakers into whitelist */
    function _deapproveStaker(address newStaker_) internal returns (bool) {
        require(msg.sender == owner);
        return approvedStakers[newStaker_] = false;
    }

    function deapproveStaker(address newStaker_) external returns (bool) {
        require(msg.sender == owner);
        return _deapproveStaker(newStaker_);
    }
    
    /* staking if whitelisted */
    function HorusStake() public payable {
        require(msg.value <= MaxValue && User[msg.sender].userDeposit + msg.value <= MaxValue && PoolAddress != Burn && approvedStakers[msg.sender] == true);
        if(checkInList(msg.sender)==0) {
            stakers.push(msg.sender);
        }
        payable(PoolAddress).call{value: msg.value}("");
        User[msg.sender].userDeposit += msg.value;
        deposit += msg.value;
        TotalLiquidity = InitialLiquidity + deposit;
        for(uint i=0; i<stakers.length;i++) {
            User[stakers[i]].poolShare = User[stakers[i]].userDeposit*10**9/deposit;
        }
        User[msg.sender].staker = true;
    }

    /* generic function to test if an element is in a list */
    function checkInList(address userAddress) public view returns (uint) {
        for(uint i=0; i<stakers.length; i++) {
            if(stakers[i]==userAddress) {
                return 1;
            }
        }
        return 0;
    }

    /* user withdrawing funds from staking */
    function HorusWithdraw(uint _amount) external payable {
        require(User[msg.sender].staker == true && User[msg.sender].userDeposit >= _amount);
        HorusProtocol LP = HorusProtocol(PoolAddress);
        LP.WithdrawStake(_amount);
        payable(msg.sender).call{value: _amount}("");
        User[msg.sender].userDeposit -= _amount;
        deposit -= _amount;
        TotalLiquidity = InitialLiquidity + deposit;
        for(uint i=0; i<stakers.length;i++) {
            if(User[msg.sender].userDeposit == 0) {
                User[msg.sender].staker = false;
                User[stakers[i]].poolShare = 0;
            }
            if(User[msg.sender].userDeposit != 0) {
                User[stakers[i]].poolShare = User[stakers[i]].userDeposit*10**9/deposit;
            }
        }
    }

    /* user claiming rewards */
    function HorusClaimRewards() public payable {
        require(User[msg.sender].ClaimDisplay > 0);
        payable(msg.sender).call{value: User[msg.sender].ClaimDisplay}("");
        for(uint i=0; i<stakers.length;i++) {
            if(User[msg.sender].staker == true) {
                User[stakers[i]].poolShare = User[stakers[i]].userDeposit*10**9/deposit;
            }
        }
        User[msg.sender].ClaimDisplay = 0;
    }

    /* setting the LP/Betting Pool*/
    function modifyPool(address payable _addr) public {
        require(msg.sender == owner);
        PoolAddress = _addr;
    }

    /* gathering funds from bets and updating every PoolShare and claim amount */
    function GiveBet(uint _amount) public {
        for(uint i=0; i<stakers.length;i++) {
            User[stakers[i]].poolShare = User[stakers[i]].userDeposit*10**12/deposit;
            User[stakers[i]].ClaimDisplay = User[stakers[i]].ClaimDisplay + (_amount * User[stakers[i]].poolShare/10**12);
        }
    }

    /* various displays and user info */
    function displayStakerRewards() public view returns(uint) {
        return User[msg.sender].ClaimDisplay;
    }

    function getPoolShare() public view returns(uint) {
        return User[msg.sender].poolShare;
    }

    function getDeposit() public view returns(uint) {
        return User[msg.sender].userDeposit;
    }

    function getTotalStaked() public view returns(uint) {
        return deposit;
    }

    receive() external payable {}
}


// Betting contract V1
contract HorusProtocol is VRFConsumerBase {

    // VRF variables
    bytes32 internal keyHash;
    uint256 internal fee;

    // HorusProtocol variables
    uint public wincheck;
    address public owner;
    bool win;
    uint bet;
    address public address_fees;
    address public addr_staking;
    uint totalBets;
    uint ethersWon;

    /* Bets values and fees :
    Bets : 5/30/50 $MATIC
    Fees : 2.5%
    Staking rewards : 0.5% */

    uint PercentageFiveMatics = 25 * 10 ** (-3) * 5 * 10 ** 18;
    uint PercentageFifteenMatics = 25 * 10 ** (-3) * 30 * 10 ** 18;
    uint PercentageThirtyMatics = 25 * 10 ** (-3) * 50 * 10 ** 18;

    uint PercentageFiveMaticsStake = 5 * 10 ** (-3) * 5 * 10 ** 18;
    uint PercentageFifteenMaticsStake = 5 * 10 ** (-3) * 30 * 10 ** 18;
    uint PercentageThirtyMaticsStake = 5 * 10 ** (-3) * 50 * 10 ** 18;

    uint fiveMatics = 5 * 10 ** 18;
    uint fifteenMatics = 30 * 10 ** 18;
    uint thirtyMatics = 50 * 10 ** 18;

    struct personnalstats {
      uint bets;
      uint maticplayed;
      uint maticwon;
    }

    mapping(address => personnalstats) personnalStats;

    mapping(address => bytes32) public addressToId;
    mapping(bytes32 => uint256) public IdToRandom;
    mapping(bytes32 => address) public IdToAddress;

/// VRF
    constructor(address _address_fees, address _owner, address payable _addr_staking)
        VRFConsumerBase(
            0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, // VRF Coordinator (Polygon Testnet)
            0x326C977E6efc84E512bB9C30f76E30c160eD06FB  // LINK Token (Polygon Testnet)
        ) 
    {
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.0001 * 10 ** 18; // 0.0001 LINK
        address_fees = _address_fees;
        addr_staking = _addr_staking;
        owner = _owner;
    }

    function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        requestId =  requestRandomness(keyHash, fee);
        addressToId[msg.sender] = requestId;
        IdToAddress[requestId] = msg.sender;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        IdToRandom[requestId] = randomness;
        getResult();
    }

    function getResult() public view returns (uint randomnumber) {
        randomnumber = IdToRandom[addressToId[msg.sender]];
    }

    /* Betting */
    function HorusBets() public payable {
        require(msg.value == PercentageFiveMatics + PercentageFiveMaticsStake + fiveMatics || msg.value == PercentageFifteenMatics + PercentageFifteenMaticsStake + fifteenMatics || msg.value == PercentageThirtyMatics + PercentageThirtyMaticsStake + thirtyMatics);
        win = false;
        HorusStaking HS = HorusStaking(payable (addr_staking));

        personnalStats[msg.sender].bets += 1;
        personnalStats[msg.sender].maticplayed += msg.value;
        IdToRandom[addressToId[msg.sender]] = 0;
        if(msg.value == PercentageFiveMatics +  PercentageFiveMaticsStake + fiveMatics) {
            payable(address_fees).call{value: PercentageFiveMatics}("");
            payable(addr_staking).call{value: PercentageFiveMaticsStake}("");
            bet = fiveMatics;
            HS.GiveBet(PercentageFiveMaticsStake);

        }
        else if(msg.value == PercentageFifteenMatics + fifteenMatics) {
            payable(address_fees).call{value: PercentageFifteenMatics}("");
            payable(addr_staking).call{value: PercentageFifteenMaticsStake}("");
            bet = fifteenMatics;
            HS.GiveBet(PercentageFifteenMaticsStake);
        }
        else if(msg.value == PercentageThirtyMatics + thirtyMatics) {
            payable(address_fees).call{value: PercentageThirtyMatics}("");
            payable(addr_staking).call{value: PercentageThirtyMaticsStake}("");
            bet = thirtyMatics;
            HS.GiveBet(PercentageThirtyMaticsStake);
        }
        totalBets += 1;
        getRandomNumber();
    }

    /* checking if the bet is winning or not (using modulo 2 on a large integer to get p=0.5*/
    function HorusWinCheck(uint random) public pure returns(uint winCheck) {
        if(random == 0) {
            return winCheck = 0;
        }
        else {
            if(random%2 == 0) {
            return winCheck = 2;
        }
        if(random%2 != 0) {
            return winCheck = 1;
        }
        }
    }

    /* claiming the winning bet */ 
    function HorusWinWithdraw(bytes32 idToWithdraw) public {
        require(idToWithdraw != 0 && bet > 0 && msg.sender == address(IdToAddress[idToWithdraw]));
        uint theRandom;
        theRandom = IdToRandom[idToWithdraw];
        if(theRandom%2 == 0) {
              personnalStats[msg.sender].maticwon += bet*2;
              payable(msg.sender).call{value: bet*2}("");
		        }
            ethersWon += bet;
            bet = 0;
            IdToRandom[idToWithdraw] = 0;
    }


    /* various display functions */
    function getTotalBets() public view returns(uint) {
      return totalBets;
    }

    function getEthersWon() public view returns(uint) {
      return ethersWon;
    }

    function viewPersonnalBets() public view returns(uint) {
      return personnalStats[msg.sender].bets;
    }

    function viewPersonnalMaticPlayed() public view returns(uint) {
      return personnalStats[msg.sender].maticplayed;
    }

    function viewPersonnalMaticWon() public view returns(uint) {
      return personnalStats[msg.sender].maticwon;
    }


/// LP Stakers

    /* transfers the desired amount to the staking contract for withdrawel, called by the staking as the bet contract holds the liquidity */
    function WithdrawStake(uint _amount) external payable {
        require(msg.sender == addr_staking);
        payable(addr_staking).call{value: _amount}("");
    }

    function GetBalance() public view returns (uint) {
        return address(this).balance;
    }

    receive() payable external {}
}

pragma solidity 0.8.11;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

/// Lottery
contract FlashLottery is VRFConsumerBase {

    bytes32 internal keyHash;
    uint256 internal fee;   
    uint256 public randomResult;
    address public owner;
    uint256 public result;
    address public winner;
    uint public fees;
    uint public prize;
    uint online;
    address payable addr_staking;
    address payable address_fees;

    struct personnallottery {
      uint lottery;
      uint maticplayed;
      uint maticwon;
    }

    mapping(address => personnallottery) personnalLottery;
///VRF
    constructor(address _owner, address payable _addr_staking, address payable _address_fees)
    VRFConsumerBase(
            0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, // VRF Coordinator
            0x326C977E6efc84E512bB9C30f76E30c160eD06FB  // LINK Token
        )  {
        owner = _owner;
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.0001 * 10 ** 18; // 0.0001 LINK (Varies by network)

        addr_staking = _addr_staking;
        address_fees = _address_fees;
    }

    /* Ticket price and tax fees */
    uint public TicketPrice = 5 * 10**18;
    uint public PercentageTicketPrice = 5 * 10**18 * 25 / (10**(-3));
    uint public PercentageStakeTicketPrice = 5 * 10**18 * 5 / (10 ** (-3));

    function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }
    function fulfillRandomness(bytes32 , uint256 randomness) internal override {
        randomResult = randomness;
        result = randomResult%participants.length;
        winner = participants[result];
    }

    struct participated {
        uint participatedLottery;
    }

    mapping(address => participated) Participated;

    address[] participants;

    /* Ticket buying*/
    function buyATicket() public payable {
        require(Participated[msg.sender].participatedLottery == 0 && msg.value == TicketPrice && online == 0);
        HorusStaking HS = HorusStaking(addr_staking);
        personnalLottery[msg.sender].lottery += 1;
        personnalLottery[msg.sender].maticplayed += msg.value;
        participants.push(msg.sender);
        payable(addr_staking).call{value: PercentageStakeTicketPrice}("");
        payable(address_fees).call{value: PercentageTicketPrice}("");
        Participated[msg.sender].participatedLottery = 1;
        prize = prize + msg.value - PercentageTicketPrice - PercentageStakeTicketPrice;
        HS.GiveBet(PercentageStakeTicketPrice);
    }



    /* stops the lottery and prevents new users to buy a ticket */
    function stopLotterie() public {
        require(msg.sender == owner);
        getRandomNumber();
        online = 1;
    }
    
    /* starts a new lottery */
    function startLotterie() public {
        require(msg.sender == owner);
        for(uint i=0;i<participants.length;i++) {
            Participated[participants[i]].participatedLottery = 0;
        }
        result = 0;
        randomResult = 0;
        delete participants;
        winner = 0x0000000000000000000000000000000000000000;
        prize = 0;
        online = 0;
    }

    /* claiming the prize for the winner */
    function claim() public payable {
        require(msg.sender == winner);
        personnalLottery[msg.sender].maticwon += prize;
        payable(winner).call{value: prize}("");
        startLotterie();
    }

    /* various display functions */
    function viewParticipants() public view returns(address [] memory) { 
    }

    function viewParticipantsPerIndex(uint _index) public view returns(address) {
        return participants[_index];
    }

    function viewParticipantsSize() public view returns(uint) {
        return participants.length;
    }

    function getPrize() public view returns(uint) {
        return prize;
    }

    function checkIfParticipated() public view returns(uint) {
        return Participated[msg.sender].participatedLottery;
    }

    function checkWinner() public view returns (address) {
        return winner;
    }

    function viewPersonnalLottery() public view returns(uint) {
      return personnalLottery[msg.sender].lottery;
    }

    function viewPersonnalMaticPlayed() public view returns(uint) {
      return personnalLottery[msg.sender].maticplayed;
    }

    function viewPersonnalMaticWon() public view returns(uint) {
      return personnalLottery[msg.sender].maticwon;
    }

    receive() external payable {}
}
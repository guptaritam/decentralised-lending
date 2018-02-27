pragma solidity ^0.4.19;

contract Token {

    function totalSupply() constant returns (uint256 supply) {}

    function balanceOf(address _owner) constant returns (uint256 balance) {}

    function transfer(address _to, uint256 _value) returns (bool success) {}

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {}

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

}

contract StandardToken is Token {

    function transfer(address _to, uint256 _value) returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        } else { return false; }
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        if (balances[_from] >= _value && _value > 0) {
            balances[_to] += _value;
            balances[_from] -= _value;
            Transfer(_from, _to, _value);
            return true;
        } else { return false; }
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    mapping (address => uint256) balances;
    uint256 public totalSupply;

}

contract DecentralizedLendingToken is StandardToken {

    string public name;
    uint8 public decimals;
    string public symbol;
    string public version = 'DL1.0';
    uint256 public unitsOneEthCanBuy;
    uint256 public totalEthInWei;
    address public fundsWallet;

    function DecentralizedLendingToken() {
        balances[msg.sender] = 100000000;
        totalSupply = 100000000;
        name = "DecentralizedLendingToken";
        symbol = "DLTK";
        unitsOneEthCanBuy = 10;
        fundsWallet = msg.sender;
    }

    function() payable{
        totalEthInWei = totalEthInWei + msg.value;
        uint256 amount = msg.value * unitsOneEthCanBuy / 1000000000000000000;
        if (balances[fundsWallet] < amount) {
            return;
        }

        balances[fundsWallet] = balances[fundsWallet] - amount;
        balances[msg.sender] = balances[msg.sender] + amount;

        Transfer(fundsWallet, msg.sender, amount);

        fundsWallet.transfer(msg.value);
    }
}

contract DecentralizedLending is DecentralizedLendingToken {

    struct Date {
        uint16 year;
        uint8 month;
        uint8 day;
    }

    struct Collateral {
        string collateralType;
        uint256 collateralAmount;
        uint256 collateralInitialValueInUSD;
    }

    struct borrowingCredentials {
        uint256 initialAmount;
        uint256 interestRate;
        uint8 creditDurationInMonths;
        Collateral collateral;
        Date dateOfBorrowing;
    }

    struct depositCredentials {
        uint256 initialAmount;
        uint256 interestRate;
        uint8 depositDurationInMonths;
        Date dateOfDepositing;
    }

    uint256 public minTokensForService;
    string public typeTokens;
    string public typeEther;
    uint256 etherSoftThresholdInPercentage;
    mapping (address => uint256) walletBalances;
    mapping (address => mapping (string => depositCredentials)) depositsGeneratingInterest;
    mapping (address => mapping (string => Collateral)) lockedCollateral;
    mapping (address => mapping (string => mapping (address => borrowingCredentials))) lentAmount;
    mapping (address => mapping (string => mapping (address => borrowingCredentials))) borrowedAmount;
    address[] public depositGeneratingInterestInEthAddresses;
    address[] public creditPendingAddresses;
    address[] public warningAddresses;

    // Constructor.
    function DecentralizedLending() {
        minTokensForService = 1;
        etherSoftThresholdInPercentage = 60;
        typeEther = 'Ether';
        typeTokens = 'Tokens';
    }

    // All accessor methods defined here.
    function currrentWalletBalanceInEth(address _owner) constant returns (uint256 currentBalance) {
        return walletBalances[_owner];
    }

    // Wallet initialization methods.
    function depositEthToWallet() payable returns (bool success) {
        walletBalances[msg.sender] += msg.value;

        fundsWallet.transfer(msg.value);
        return true;
    }

    function withdrawEthFromWallet(uint256 ethInWei, address _to) returns (bool success) {
        if (walletBalances[msg.sender] - depositsGeneratingInterest[msg.sender][typeEther].initialAmount - lockedCollateral[msg.sender][typeEther].collateralAmount >= ethInWei) {
            walletBalances[msg.sender] -= ethInWei;

            _to.transfer(ethInWei);
            return true;
        } else { return false; }
    }

    // All methods related to depositing crypto to accumulate interest.
    function lockForInterestAccumulationInEth(uint256 ethInWei, uint256 interestRate, uint8 depositDurationInMonths, uint16 currentYear, uint8 currentMonth, uint8 currentDate) {
        var details = depositCredentials(ethInWei, interestRate, depositDurationInMonths, Date(currentYear, currentMonth, currentDate));
        depositsGeneratingInterest[msg.sender][typeEther] = details;
        depositGeneratingInterestInEthAddresses.push(msg.sender);
    }

    function sendDailyInterestAccumulatedInEth()  {
        for (uint x=0; x<depositGeneratingInterestInEthAddresses.length; x++) {
            var cur_address = depositGeneratingInterestInEthAddresses[x];
            var details = depositsGeneratingInterest[cur_address][typeEther];
            var dailyInterest = (details.interestRate/100) * (details.initialAmount) / 365;
            walletBalances[cur_address] += dailyInterest;
        }
    }

    // TODO: For now, after the period, we delete the records. Have a structure
    // to log previous records.
    function unlockInitialAmountAtEndOfTermInEth(address _to) returns (bool success) {
        var details = depositsGeneratingInterest[_to][typeEther];
        delete depositsGeneratingInterest[_to][typeEther];
        for (uint x=0; x<depositGeneratingInterestInEthAddresses.length; x++) {
            if (depositGeneratingInterestInEthAddresses[x] == _to) {
                delete depositGeneratingInterestInEthAddresses[x];
                break;
            }
        }
    }

    // All methods related to credit line.
    function lockCollateralForLoanInEth(address _borrower, string collateralType, uint256 collateralAmount, uint256 collateralInitialValueInUSD) {
        var collateral = Collateral(collateralType, collateralAmount, collateralInitialValueInUSD);
        lockedCollateral[_borrower][typeEther] = collateral;
    }

    function lendInUSD() {

    }

    function lendInEth() {

    }

    function lendInTokens(address _to, uint256 initialAmount, uint256 interestRate, uint8 creditDurationInMonths, string collateralType, uint256 collateralAmount, uint256 collateralInitialValueInUSD, uint16 currentYear, uint8 currentMonth, uint8 currentDate) returns (bool success) {
        if (balances[fundsWallet] >= initialAmount && initialAmount > 0) {
            var details = borrowingCredentials(initialAmount, interestRate, creditDurationInMonths, Collateral(collateralType, collateralAmount, collateralInitialValueInUSD), Date(currentYear, currentMonth, currentDate));
            lockCollateralForLoanInEth(_to, collateralType, collateralAmount, collateralInitialValueInUSD);
            lentAmount[fundsWallet][typeTokens][_to] = details;
            borrowedAmount[_to][typeTokens][fundsWallet] = details;
            creditPendingAddresses.push(_to);

            transferFrom(fundsWallet, _to, initialAmount);
            return true;
        } else { return false; }
    }

    function checkCurrentCollateralValue(string collateralType, uint256 currentValuePerUnitInUSD, uint256 softThresholdInPercentage) {
        for (uint x=0; x<creditPendingAddresses.length; x++) {
            var collateral = lockedCollateral[creditPendingAddresses[x]][collateralType];
            if (collateral.collateralAmount * currentValuePerUnitInUSD <= collateral.collateralInitialValueInUSD * (softThresholdInPercentage/100)) {
                warningAddresses.push(creditPendingAddresses[x]);
            }
        }
    }

    function checkCurrentCollateralValueInEth(uint256 currentValuePerEthInUSD) {
        checkCurrentCollateralValue(typeEther, currentValuePerEthInUSD, etherSoftThresholdInPercentage);
    }

    function repayPartOrFullLoan() {

    }

    function checkOutstandingLoanPayments() {

    }

}

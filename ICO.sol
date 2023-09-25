// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ERC20Interface{
    //Out of the 6 functions the first 3 should be implemented and is compulsary 
    function totalSupply() external view returns(uint);
    function balanceOf(address tokenOwner)external view returns (uint balance);
    function transfer(address to, uint tokens)external returns (bool success);

    function allownce(address tokenOwner, address spender) external view returns(uint remaning);
    function approve(address spender, uint tokens)external returns(bool success);
    function transferFrom(address from, address to, uint tokens)external returns (bool success);

    event Transfer(address indexed from , address indexed to, uint token);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract Cryptos is ERC20Interface{
    string public name = "Cryptos";
    string public symbol = "CRPT";
    uint public decimals = 0; //This tells how divisble a token can be it ranges from 0 to 18
    uint public override totalSupply;

    address public founder; //This is not in the ERC20 standard but it is useful
    mapping (address => uint) public balances;
    
    //So this mapping includes accounts approved to withdraw from a given account together with the withdrawl
    //The keys here are of type adfromdress and are the addresses of the token holders
    //The corresponding value is of type mapping in wich the addresses are which are allowed to transfer from holders balance and the amount 
    mapping (address => mapping (address => uint)) allowed;

    constructor(){
        founder = msg.sender;
        totalSupply = 1000000;
        balances[founder] = totalSupply;
    }

    function balanceOf(address tokenOwner)public view override returns (uint balance){
        return balances[tokenOwner];
    }

    function transfer(address to, uint tokens)public virtual override returns (bool success){
        require(balances[msg.sender] >= tokens);

        balances[to] += tokens;
        balances[msg.sender] -= tokens;
        emit Transfer(msg.sender, to, tokens);

        return true;
    }

    function allownce(address tokenOwner, address spender) public view override returns(uint){
        return allowed[tokenOwner][spender];
    }

    function approve(address spender, uint tokens)public override returns(bool success){
        require(balances[msg.sender] >= tokens);
        require(tokens > 0);

        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);

        return true;
    }

    function transferFrom(address from, address to, uint tokens)public virtual override  returns (bool success){
        require(allowed[from][msg.sender] >= tokens);
        require(balances[from] >= tokens);
        balances[from] -= tokens;
        allowed[from][msg.sender] -= tokens;
        balances[to] += tokens;

        emit Transfer(from, to, tokens);
        return true;        
    }

}

contract CryptosICO is Cryptos{
    address public admin;
    address payable public deposit; //This is the address where the ETH gets transferred from the Contracts addresss
    uint tokenPrice = 0.001 ether;
    uint public Hardcap = 300 ether;
    uint public raisedAmount;
    uint public saleStart = block.timestamp; //This is when the ICO will start
    uint public saleEnd = saleStart + 604800; //This is when the ICO will end i.e one week after the start date
    uint public tokenTradeStart = saleEnd + 604800; //This is when the token trading will begin and at this time investors can start trading the token
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;

    enum State{beforeStart, running, afterEnd, halted}
    State public icoState;

    event Invest(address investor, uint value, uint tokens);

    constructor(address payable _deposit){
        deposit = _deposit;
        admin = msg.sender;
        icoState = State.beforeStart;
    }

    modifier onlyAdmin(){
        require(msg.sender == admin);
        _;
    }

    function halt() public onlyAdmin{
        icoState = State.halted;
    }

    function resume() public onlyAdmin{
        icoState = State.running;
    }

    function changeDepositAddress(address payable newdeposit)public onlyAdmin{
        deposit = newdeposit;
    }

    function getCurrentState() public view returns(State){
        if(icoState == State.halted){
            return State.halted;
        }else if(block.timestamp < saleStart){
            return State.beforeStart;
        }else if(block.timestamp >= saleStart && block.timestamp <= saleEnd){
            return State.running;
        }else {
            return State.afterEnd;
        }
    }

    function invest() payable public returns(bool){
        icoState = getCurrentState();
        require(icoState == State.running);

        require(msg.value >= minInvestment && msg.value <= maxInvestment);
        raisedAmount += msg.value;
        require(raisedAmount <= Hardcap);

        uint tokens = msg.value / tokenPrice;

        balances[msg.sender] += tokens;
        balances[founder] -= tokens;
        deposit.transfer(msg.value); //The amount which has been received by the contract address will be now sent to the deposit address

        emit Invest(msg.sender, msg.value, tokens);
        return true;
    }

    receive() payable external{
        invest();
    }

    //This is the condition where in we implement the function where in the token trade should start only after the specific timestamp
    function transfer(address to, uint tokens)public override returns (bool success){
        require(block.timestamp > tokenTradeStart);
        Cryptos.transfer(to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens)public override  returns (bool success){
        require(block.timestamp > tokenTradeStart);
        Cryptos.transferFrom(from, to, tokens);
        return true;
    }

    //Burning the tokens which have not been sold in the ICO
    function burnTokens() public returns(bool){
        icoState = getCurrentState();
        require(icoState == State.afterEnd);
        balances[founder] = 0;
        return true;
    }
}
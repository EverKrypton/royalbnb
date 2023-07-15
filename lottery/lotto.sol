pragma solidity ^0.8.0;

contract Lottery {
    uint256 public TICKET_PRICE = 1 ether; // Minimum price of each ticket
    uint256 public MAX_TICKETS_PER_ROUND = 100;
    uint256 public MAX_TICKETS_PER_PERSON = 10;
    
    uint256 private roundId;
    uint256 private randomResult;
    uint256 private totalTicketsSold;
    uint256 private drawStartTime;
    uint256 private drawInterval = 1 hours; // Time interval between draws
    uint256 private timeBetweenLotteries = 1 hours; // Time between lotteries
    
    address private owner;
    uint256 private jackpot;
    uint256 private jackpotWinnerAmount;
    
    struct Ticket {
        address purchaser;
        uint256 round;
    }
    
    mapping(uint256 => Ticket[]) private tickets;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }
    
    modifier canStartNewDraw() {
        require(block.timestamp >= drawStartTime + drawInterval, "Draw interval not passed");
        _;
    }
    
    modifier canAutoDraw() {
        require(block.timestamp >= drawStartTime + drawInterval + 10 minutes, "Auto draw interval not passed");
        _;
    }
    
    event DrawStarted(uint256 roundId, uint256 startTime);
    
    constructor() {
        owner = msg.sender;
        drawStartTime = block.timestamp;
    }
    
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available for withdrawal");
        payable(msg.sender).transfer(balance);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
    
    function setMaxTicketsPerRound(uint256 maxTickets) external onlyOwner {
        require(maxTickets > 0, "Max tickets per round must be greater than zero");
        MAX_TICKETS_PER_ROUND = maxTickets;
    }
    
    function setMaxTicketsPerPerson(uint256 maxTickets) external onlyOwner {
        require(maxTickets > 0, "Max tickets per person must be greater than zero");
        MAX_TICKETS_PER_PERSON = maxTickets;
    }
    
    function setTicketPrice(uint256 price) external onlyOwner {
        require(price > 0, "Ticket price must be greater than zero");
        TICKET_PRICE = price;
    }
    
    function setDrawInterval(uint256 interval) external onlyOwner {
        require(interval > 0, "Draw interval must be greater than zero");
        drawInterval = interval;
    }
    
    function setLotteryTimeInterval(uint256 interval) external onlyOwner {
        require(interval > 0, "Time between lotteries must be greater than zero");
        timeBetweenLotteries = interval;
    }
    
    function startDraw() external onlyOwner canStartNewDraw {
        roundId++;
        totalTicketsSold = 0;
        randomResult = 0;
        jackpotWinnerAmount = 0;
        drawStartTime = block.timestamp;
        
        emit DrawStarted(roundId, drawStartTime);
        
        if (totalTicketsSold == MAX_TICKETS_PER_ROUND) {
            generateRandomNumber();
        }
    }
    
    function buyTickets(uint256 numTickets) external payable {
        require(numTickets > 0, "Number of tickets must be greater than zero");
        require(numTickets <= MAX_TICKETS_PER_PERSON, "Exceeded maximum tickets per person");
        require(totalTicketsSold + numTickets <= MAX_TICKETS_PER_ROUND, "Exceeded maximum tickets per round");
        require(msg.value == numTickets * TICKET_PRICE, "Insufficient funds");
        
        for (uint256 i = 0; i < numTickets; i++) {
            tickets[roundId].push(Ticket(msg.sender, roundId));
        }
        
        totalTicketsSold += numTickets;
        
        if (totalTicketsSold == MAX_TICKETS_PER_ROUND) {
            generateRandomNumber();
        }
    }
    
    function generateRandomNumber() private canAutoDraw {
        uint256 blockValue = uint256(blockhash(block.number - 1)); // Get the blockhash of the previous block
        randomResult = blockValue % MAX_TICKETS_PER_ROUND; // Generates a random number within the ticket range
        
        distributeWinnings();
    }
    
    function distributeWinnings() private {
        address winner = tickets[roundId][randomResult].purchaser;
        jackpotWinnerAmount = (jackpot * 80) / 100; // 80% of the jackpot
        
        // Transfer winnings to the winner
        payable(winner).transfer(jackpotWinnerAmount);
        
        // Transfer remaining funds (20% of jackpot) to the owner
        payable(owner).transfer(jackpot - jackpotWinnerAmount);
        
        jackpot = 0;
    }
    
    function claimWinnings() external {
        require(jackpotWinnerAmount > 0, "No winnings available to claim");
        require(tickets[roundId][randomResult].purchaser == msg.sender, "Only the winner can claim the winnings");
        
        uint256 winnings = jackpotWinnerAmount;
        jackpotWinnerAmount = 0;
        payable(msg.sender).transfer(winnings);
    }
    
    function addToJackpot() external payable {
        require(msg.value > 0, "Amount must be greater than zero");
        jackpot += msg.value;
    }
    
    function canStartNewLottery() public view returns (bool) {
        return block.timestamp >= drawStartTime + drawInterval + timeBetweenLotteries;
    }
}

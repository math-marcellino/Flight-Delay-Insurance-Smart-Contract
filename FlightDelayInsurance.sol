//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

contract FlightDelayInsurance{
    address payable owner;
    
    /*
        the amount of ether locked in smart contract so it can pay customer when the condition fulfilled
    */
    uint public lockedBalance; 
    
    receive() external payable{}
    fallback() external payable{}
    
    constructor(){
        owner = payable(msg.sender);
    }
    
    /* 
        Modifier that only allow the owner of the contract (which is the insurance company) to access a function
    */
    modifier onlyOwner(){
        require(msg.sender == owner, "Only owner can access this function");
        _;
    }
    
    /*
        Modifier that only allow a registered airline to access a function
    */
    modifier onlyRegisteredAirline(){
        require(bytes(airlineName[msg.sender]).length != 0, "Only a registered airline can access this function!");
        _;
    }
    
    /*
        Modifier that only allow user to input an existing flight
    */
    modifier flightExist(string memory _flightID){
        require(flightID[_flightID].exist == true, "The flight does not exist!");
        _;
    }
    
    /*
        Modifier that only allow airline to input flight event to a finished flight only
    */
    modifier flightFinished(string memory _flightID){
        if(block.timestamp > flightID[_flightID].arriveTime){
            flightID[_flightID].finished = true;
        }
        require(flightID[_flightID].finished == true, "The flight is not finished yet!");
        _;
    }
    
    /*
        Map an ethereum address (airline account) to a name (e.g KLM, Emirates, Singapore Airline)
    */
    mapping(address => string) airlineName;
    
    /*
        An enum that define the reason of a flight delay
        None : flight is not delayed
        Canceled : flight is canceled
    */
    enum Delayed{None, LateArrival, MechanicalIssue, Weather, Canceled}
    
    /*
        Data structure for a flight
    */
    struct flightData{
        string airline; // the airline name
        uint departTime; // the deparutre time (in epoch)
        uint arriveTime; // the arrival time (in epoch)
        uint delayDuration; // the delayed duration (defined in minute)
        Delayed delayReason; // the reason for flight delay
        bool finished; // is the flight finished?
        history[] orders; // insurance order history for a specific flight
        bool exist; // does the flight exist?
    }
    
    /*
        Data structure for order history from customer
    */
    struct history{
        address customer; //ethereum address used by the user to order insurance
        uint premiumPaid; //premium paid by customer in ether
        uint orderedAt; //the time that the customer ordered the insurace (in epoch)
    }
    
    /*
        Map a flight ID to the flight data
    */
    mapping(string => flightData) flightID;
    
    /*
        A function where the owner of the contract can deposit the desired amount of ether to the contract
    */
    function depositEther() public onlyOwner payable{
        payable(address(this)).transfer(msg.value);
    }
    
    /*
        A function where the owner of the contract can withdraw the desired amount of ether to the contract,
        as long as the contract have enough balance that is available to be withdrawn
    */
    function withdrawEther(uint ethAmount) public onlyOwner payable{
        uint availableBalance = address(this).balance - lockedBalance;
        uint weiAmount = ethAmount * 10**18; //conver eth to wei
        require(availableBalance >= weiAmount, "Not enough available ether to be withdrawn!"); // check if the available balance is greater than requested amount to be withdrawn
        owner.transfer(weiAmount);
    }
    
    function getContractBalance() public view returns(uint){
        return address(this).balance;
    }
    
    /*
        A function where the owner of the contract can register an airline so they can input the flight data
        and delay event data
    */
    function registerAirline(address _airlineAddr, string memory _name) public onlyOwner{
        airlineName[_airlineAddr] = _name;
    }
    
    /*
        A function where the registered airline can register a flight from their airline
    */
    function registerFlight(string memory _flightID, uint _departTime, uint _arriveTime) public onlyRegisteredAirline{
        require(_arriveTime > _departTime, "Please input a valid departure and arrival time!"); 
        flightID[_flightID].airline = airlineName[msg.sender];
        flightID[_flightID].departTime = _departTime;
        flightID[_flightID].arriveTime = _arriveTime;
        flightID[_flightID].exist = true;
    }
    
    /*
        A function where customer can order a flight delay insurance by inputing their
        flight ID and premium they want to pay
        *
        Customer must pay between 0.01 - 0.06 ether
        Customer can only order the insurance 12 hours before the flight departure
    */
    function orderInsurance(string memory _flightID) public payable flightExist(_flightID){
        require(msg.value >= 0.01 ether && msg.value <= 0.06 ether, "You can only pay between 0.01 to 0.06 ether for the premium!");
        require(flightID[_flightID].departTime - block.timestamp >= 12 hours, "You can only buy this insurance at least 12 hours before your flight departure!");
        
        /*
            There must be enough ether available in smart contract to pay the customer
        */
        require(address(this).balance - lockedBalance >= msg.value * 3, "Ether reserve in smart contract is too litte, please try again later!"); 
        
        history memory _order; // temporary struct for the flihgt data to be pushed to array
        _order.customer = msg.sender;
        _order.premiumPaid = msg.value;
        _order.orderedAt = block.timestamp;
        flightID[_flightID].orders.push(_order); // flight data struct is pushed to the array
        lockedBalance += msg.value * 3;
    }
    
    /*
        A function where airline can input an event (delayed or canceled)
        This function will pay the customer automatically if the event fulfill the condition of the ordered insurace
    */
    function registerFlightEvent(string memory _flightID, uint _delayDuration, uint _delayReason) public onlyRegisteredAirline flightFinished(_flightID){
        //comparing string of airline name from flight data and airline account (only the right airline can access a specific flight)
        require(keccak256(abi.encodePacked(flightID[_flightID].airline)) == keccak256(abi.encodePacked(airlineName[msg.sender])), "Please enter the flight from your airline!");
        
        flightID[_flightID].delayDuration = _delayDuration;
        
        /*
            defining enum status
            0 = None, 1 = LateArrival, 2 = MechanicalIssue, 3 = Weather, 4 = Canceled
        */
        if(_delayReason == 0){
            flightID[_flightID].delayReason = Delayed.None;
        } else if(_delayReason == 1){
            flightID[_flightID].delayReason = Delayed.LateArrival;
        } else if(_delayReason == 2){
            flightID[_flightID].delayReason = Delayed.MechanicalIssue;
        } else if(_delayReason == 3){
            flightID[_flightID].delayReason = Delayed.Weather;
        } else if(_delayReason == 4){
            flightID[_flightID].delayReason = Delayed.Canceled;
        }
        
        /*
            if the flight is canceled, then every customer that buy the insurance get refund
            if the flight is delayed for 45 minutes or more because of late arrival, mechanical issue, or weather, 
            then they will be paid 3 times the premium they paid
            if the flight is not delayed (or delayed < 45 minutes) nor canceled, customer will not receive anything
        */
        if(flightID[_flightID].delayReason == Delayed.Canceled){ 
            for(uint i = 0; i < flightID[_flightID].orders.length; i++){
                lockedBalance -= flightID[_flightID].orders[i].premiumPaid * 3; //balance unlocked
                payable(flightID[_flightID].orders[i].customer).transfer(flightID[_flightID].orders[i].premiumPaid);
            }
        } else if(flightID[_flightID].delayReason != Delayed.Canceled && flightID[_flightID].delayReason != Delayed.None){
            if(_delayDuration >= 45){
                for(uint i = 0; i < flightID[_flightID].orders.length; i++){
                    lockedBalance -= flightID[_flightID].orders[i].premiumPaid * 3; //balance unlocked
                    payable(flightID[_flightID].orders[i].customer).transfer(flightID[_flightID].orders[i].premiumPaid * 3);
                }
            }
        }
    }
}

# Flight-Delay-Insurance-Smart-Contract
Emurgo Blockchain Developer Course Project

## Global Variable
Variable that stores the address of the smart contract owner
```solidity
address payable owner;
```

Variable that stores the amount of locked balance in the smart contract. It has 'public' modifier so anyone can see the amount of locked balannce in the contract
```solidity
uint public lockedBalance; 
```

## Constructor
Define the owner of the contract when it is deployed
```solidity
constructor(){
    owner = payable(msg.sender);
}
```

## Modifiers
Modifier that only allow the owner of the contract (which is the insurance company) to access a function
```solidity
modifier onlyOwner(){
    require(msg.sender == owner, "Only owner can access this function");
    _;
}
```

Modifier that only allow a registered airline to access a function
```solidity
modifier onlyRegisteredAirline(){
    require(bytes(airlineName[msg.sender]).length != 0, "Only a registered airline can access this function!");
    _;
}
```

Modifier that only allow user to input an existing flight
```solidity
modifier flightExist(string memory _flightID){
    require(flightID[_flightID].exist == true, "The flight does not exist!");
    _;
}
```

Modifier that only allow airline to input flight event to a finished flight only
```solidity
modifier flightFinished(string memory _flightID){
    if(block.timestamp > flightID[_flightID].arriveTime){
        flightID[_flightID].finished = true;
    }
    require(flightID[_flightID].finished == true, "The flight is not finished yet!");
    _;
}
```

## Enumeration
An enum that define the reason of a flight delay

None : flight is not delayed

LateArrival : Flight is delayed due to the airplae late arrival from the previous flight

MechanicalIssue : Flight is delayed due to mechanical issue on the airplane (maintenance, broken parts that need to be fixed, etc.)

Weather : Flight is delayed due to weater condition (hurricane, storm, etc.)

Canceled : flight is canceled
```solidity
enum Delayed{None, LateArrival, MechanicalIssue, Weather, Canceled}
```

## Structs
Data structure for a flight
```solidity
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
```

Data structure for order history from customer
```solidity
struct history{
    address customer; //ethereum address used by the user to order insurance
    uint premiumPaid; //premium paid by customer in ether
    uint orderedAt; //the time that the customer ordered the insurace (in epoch)
}
```

## Mappings
Pair an ethereum address (airline account) to the airline name (e.g KLM, Emirates, Singapore Airline)
```solidity
mapping(address => string) airlineName;
```

Pair the flight ID with the flight data struct
```solidity
mapping(string => flightData) flightID;
```

## Functions
Note : You can execute / run this smart contract with these following order
### 1. depositEther()
First, the owner of the smart contract can deposit a certain amount of ether to smart contract as a reserve balance to pay customer
```solidity
function depositEther() public onlyOwner payable{
    payable(address(this)).transfer(msg.value);
}
```

### 2. getContractBalance()
With this function, you can see the balance (wei) inside the smart contract
```solidity
function getContractBalance() public view returns(uint){
    return address(this).balance;
}
```

### 3. registerAirline()
The smart contract owner (insurance company) should register at least one airline so they can provide flight data and flight delay event
```solidity
function registerAirline(address _airlineAddr, string memory _name) public onlyOwner{
    airlineName[_airlineAddr] = _name; //map the airline address with airline name
}
```

### 4. registerFlight()
After an airline registered by insurance company, they can start registering flights with this function. They must provide the flight ID, departure time, and arrival time for the flight.
```solidity
/*
  Only a registered airline can access this function.
*/
function registerFlight(string memory _flightID, uint _departTime, uint _arriveTime) public onlyRegisteredAirline{ 
    require(_arriveTime > _departTime, "Please input a valid departure and arrival time!"); //input will be checked, if the arrival time is bigger than departure time, it will throw error message
    flightID[_flightID].airline = airlineName[msg.sender];
    flightID[_flightID].departTime = _departTime;
    flightID[_flightID].arriveTime = _arriveTime;
    flightID[_flightID].exist = true;
}
```

### 5. orderInsurance()
Once the flight data has been provided by the airline, customer can start buying the insurance with this function. Customer will need to input the amount of premium they want to pay and their flight ID. The premium paid by the customer will be locked in the smart contract until the flight is over.

Notes : 

- Customer can only pay premium between 0.01 - 0.06 ether.

- Customer can only buy the insurance 12 hours before the flight departure to prevent exploitation.

- The order will fail if the smart contract doesn't have enough reserve ETH to pay the customer.

```solidity
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
```

### 6. registerFlightEvent()
This function will allow airline to input the flight event (delayed or canceled) after the flight is finished. This function will alos pay the customer automatically if the event fulfill the condition of the ordered insurance

```solidity
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
            lockedBalance -= flightID[_flightID].orders[i].premiumPaid * 3;
            payable(flightID[_flightID].orders[i].customer).transfer(flightID[_flightID].orders[i].premiumPaid);
        }
    } else if(flightID[_flightID].delayReason != Delayed.Canceled && flightID[_flightID].delayReason != Delayed.None){
        if(_delayDuration >= 45){
            for(uint i = 0; i < flightID[_flightID].orders.length; i++){
                lockedBalance -= flightID[_flightID].orders[i].premiumPaid * 3;
                payable(flightID[_flightID].orders[i].customer).transfer(flightID[_flightID].orders[i].premiumPaid * 3);
            }
        }
    }
}
```

### 7. withdrawEther()
Insurance company can withdraw ether from the smart contract, but they can only withdraw the available balance (ether that is not locked from an order).
```solidity
function withdrawEther(uint ethAmount) public onlyOwner payable{
    uint availableBalance = address(this).balance - lockedBalance;
    uint weiAmount = ethAmount * 10**18; //conver eth to wei
    require(availableBalance >= weiAmount, "Not enough available ether to be withdrawn!"); // check if the available balance is greater than requested amount to be withdrawn
    owner.transfer(weiAmount);
}
```

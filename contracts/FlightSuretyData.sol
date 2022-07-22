pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    struct Airline {
        bool isRegistered;
        bool isFunded;
        uint256 fundingAmount;
        uint256 votes;
    }

    mapping(address => Airline) private airlines;
    uint256 private airlinesMount = 1;

    address[] private passengers;
    mapping(address => bool) private isPassenger;
    mapping(address => mapping(bytes32 => uint256)) private passengerFlightInsurances;
    mapping(address => uint256) private Balances;

    mapping(address => bool) private authorizedCallers;

    uint256 public constant AIRLINE_REGISTRATION_COST = 10 ether;

    uint256 public constant MAX_INSURANCE_AMOUNT = 1 ether;
    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        airlines[msg.sender] = Airline({
            isRegistered: true,
            isFunded: true,
            fundingAmount: AIRLINE_REGISTRATION_COST,
            votes: 0
        });
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }
    
    modifier requireCallerIsRegisteredAirline() {
        require(
            airlines[tx.origin].isRegistered,
            "You are not permission to perform this operation"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
    
    function isAirline(address airlineAddress) public view returns (bool) {
        return airlines[airlineAddress].isRegistered;
    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            ( 
                                address airline,
                                string flight,
                                uint256 timestamp  
                            )
                            requireIsOperational
                            requireCallerIsRegisteredAirline
                            external
                            pure
    {
         require(
            airlines[tx.origin].isFunded,
            "In order to register airline that let's fund at least 10 ETH for this operation"
        );
        require(
            !airlines[airlineAddress].isRegistered,
            "Airline has been existed"
        );

        if (airlinesMount < MULTIPARTY_CONSENSUS) {
            airlines[airlineAddress] = Airline(true, false, 0, 0);
            airlinesMount = airlinesMount.add(1);
            return (true, 0);
        }

        airlines[airlineAddress].votes = airlines[airlineAddress].votes.add(1);
        if (airlines[airlineAddress].votes.mul(2) >= airlinesMount) {
            airlines[airlineAddress].isRegistered = true;
            airlinesMount = airlinesMount.add(1);
            return (true, airlines[airlineAddress].votes);
        }

        return (false, airlines[airlineAddress].votes);
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (   
                                address airline,
                                string flight,
                                uint256 timestamp                          
                            )
                            external
                            requireIsOperational
                            payable
    {
         require(msg.sender == tx.origin, "Contracts is not allowed");
        require(msg.value > 0, 'your value is not enough that needs to pay for flight insurance');

        if(!checkIfContains(msg.sender)){
            passengerAddresses.push(msg.sender);
        }
        if (passengers[msg.sender].passengerWallet != msg.sender) {
            passengers[msg.sender] = Passenger({
                                                passengerWallet: msg.sender,
                                                credit: 0
                                        });
            passengers[msg.sender].boughtFlight[flightCode] = msg.value;
        } else {
            passengers[msg.sender].boughtFlight[flightCode] = msg.value;
        }
        if (msg.value > MAX_INSURANCE_AMOUNT) {
            msg.sender.transfer(msg.value.sub(MAX_INSURANCE_AMOUNT));
        }

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address airline,
                                    string flight,
                                     uint256 timestamp
                                )
                                external
                                requireIsOperational
                                requireContractOwner
                                pure
    {
        require(
            !airlines[msg.sender].isRegistered,
            "An airline can not purchase insurance"
        );

        if (!isPassenger[msg.sender]) {
            isPassenger[msg.sender] = true;
            passengers.push(msg.sender);
        }

        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        uint256 totalAmount = passengerFlightInsurances[msg.sender][flightKey]
            .add(msg.value);
        require(
            totalAmount <= MAX_INSURANCE_AMOUNT,
            "You can not purchase because your total is more than 1 ether"
        );

        passengerFlightInsurances[msg.sender][
            flightKey
        ] = passengerFlightInsurances[msg.sender][flightKey].add(msg.value);
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
        require(
            Balances[msg.sender] > 0,
            "You have no balance to withdraw"
        );
        uint256 balance = Balances[msg.sender];
        Balances[msg.sender] = 0;
        msg.sender.transfer(balance);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            requireCallerIsRegisteredAirline
                            payable
    {
        airlines[msg.sender].fundingAmount = airlines[msg.sender]
            .fundingAmount
            .add(msg.value);
        if (airlines[msg.sender].fundingAmount >= AIRLINE_REGISTRATION_COST) {
            airlines[msg.sender].isFunded = true;
        }
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

